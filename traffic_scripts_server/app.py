from flask import Flask, jsonify, request
import asyncio
import aiohttp
from aiohttp import ClientSession
import ssl
import os
from functools import wraps
import traceback
import logging
from datetime import datetime

app = Flask(__name__)

def handle_errors(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            error_message = {
                'error': str(e),
                'traceback': traceback.format_exc()
            }
            return jsonify(error_message), 500
    return wrapper

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route("/fetch-volume", methods=['POST'])
@handle_errors
def run_fetch_volume():
    """
    Endpoint to run the fetch approach volume analysis
    Expects JSON body with:
    {
        "start_time": "MM/DD HH:MM AM/PM",
        "end_time": "MM/DD HH:MM AM/PM",
        "interval_minutes": 15  # optional, defaults to 15
    }
    Returns JSON response with results or error message
    """
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'No JSON data provided'}), 400
    
    required_fields = ['start_time', 'end_time']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'Missing required field: {field}'}), 400
    
    try:
        # Convert the simplified date format to full timestamp
        def parse_time(time_str):
            # Parse the input format "MM/DD HH:MM AM/PM"
            dt = datetime.strptime(time_str, "%m/%d %I:%M %p")
            # Set year to 2024 and seconds to 00
            dt = dt.replace(year=2024, second=0)
            # Return in the format expected by the fetch function
            return dt.strftime("%m/%d/%Y %I:%M:%S %p")

        start_time = parse_time(data['start_time'])
        end_time = parse_time(data['end_time'])
        interval_minutes = data.get('interval_minutes', 15)
        
    except ValueError as e:
        return jsonify({'error': 'Invalid date format. Use MM/DD HH:MM AM/PM'}), 400
    
    import sys
    import os
    import ssl
    import asyncio
    import aiohttp
    from aiohttp import ClientSession
    from fetch_approach_volume_one import fetch_approach_volume_data, url_main, url_post
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    csv_file = os.path.join(base_dir, "mercedes_30.csv")
    
    logging.info(f"Using CSV file at: {csv_file}")
    logging.info(f"Processing data from {start_time} to {end_time}")
    
    async def modified_fetch_data():
        connector = aiohttp.TCPConnector(ssl=False)
        timeout = aiohttp.ClientTimeout(total=30)
        
        async with ClientSession(connector=connector, timeout=timeout) as session:
            try:
                async with session.get(url_main) as resp:
                    if resp.status == 200:
                        logging.info("Successfully accessed the main URL.")
                    else:
                        logging.error(f"Failed to access main URL. Status code: {resp.status}")
                        return
            except Exception as e:
                logging.error(f"Error accessing the main URL: {e}")
                return

            await fetch_approach_volume_data(
                csv_file=csv_file,
                start_time_str=start_time,
                end_time_str=end_time,
                interval_minutes=interval_minutes,
                session=session
            )
    
    asyncio.run(modified_fetch_data())
    
    return jsonify({
        'status': 'success',
        'message': 'Data processing completed',
        'parameters': {
            'start_time': data['start_time'],  # Return the original input format
            'end_time': data['end_time'],      # Return the original input format
            'interval_minutes': interval_minutes
        }
    })

if __name__ == "__main__":
    print("Starting Flask server...")
    port = 6000
    print(f"Server will be available at http://localhost:{port}/")
    print(f"To access from other machines, use http://0.0.0.0:{port}/")
    app.run(host='0.0.0.0', port=port, debug=True, use_reloader=True)