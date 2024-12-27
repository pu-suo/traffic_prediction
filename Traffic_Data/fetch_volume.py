import asyncio
import aiohttp
from aiohttp import ClientSession
from bs4 import BeautifulSoup
import csv
from datetime import datetime, timedelta
import logging
import argparse
from more_itertools import chunked
import os

# --- LOGGING CONFIGURATION ---
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)  # Master logger level

# File handler for ALL logs
file_handler = logging.FileHandler('fetch_approach_volume.log')
file_handler.setLevel(logging.DEBUG)  # Capture ALL logs to file

# Console handler (if desired)
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)  # Show ALL on console

# Uniform formatter
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add handlers to logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)
# --------------------------------

url_main = "https://traffic.dot.ga.gov/ATSPM/"
url_post = "https://traffic.dot.ga.gov/ATSPM/DefaultCharts/GetApproachVolumeMetric"

async def robust_post(
    session: ClientSession,
    url: str,
    data: dict,
    headers: dict,
    max_retries: int = 3,
    backoff_factor: float = 1.5
):
    """
    Attempt to post data with exponential backoff on certain recoverable errors.
    Returns the response object if successful, otherwise None.
    """
    attempt = 1
    while attempt <= max_retries:
        try:
            response = await session.post(url, data=data, headers=headers)
            if response.status == 200:
                return response
            elif response.status in [429, 500, 502, 503, 504]:
                # recoverable server-side or rate-limit errors
                logger.warning(
                    f"Server returned status {response.status} (attempt {attempt}/{max_retries}). "
                    f"Will retry after backoff."
                )
            else:
                # Other status codes won't be resolved by retrying
                logger.error(f"Received status {response.status}, not retrying further.")
                return None
        except asyncio.TimeoutError:
            logger.warning(
                f"Timeout occurred while posting (attempt {attempt}/{max_retries}). "
                f"Will retry after backoff."
            )
        except Exception as e:
            # Other unknown exceptions
            logger.error(
                f"Unknown error on attempt {attempt}/{max_retries}: {e}. "
                f"Will retry after backoff if attempts remain."
            )

        attempt += 1
        if attempt <= max_retries:
            sleep_time = backoff_factor ** (attempt - 1)
            await asyncio.sleep(sleep_time)

    logger.error("Max retries exceeded. Returning None.")
    return None


async def fetch_approach_volume_data(csv_file, start_time_str, end_time_str, interval_minutes=15):
    def create_time_intervals(total_start_datetime, total_end_datetime, interval_minutes):
        intervals = []
        current_start = total_start_datetime
        while current_start < total_end_datetime:
            current_end = current_start + timedelta(minutes=interval_minutes)
            if current_end > total_end_datetime:
                current_end = total_end_datetime
            intervals.append((
                current_start.strftime('%m/%d/%Y %I:%M:%S %p'),
                current_end.strftime('%m/%d/%Y %I:%M:%S %p')
            ))
            current_start = current_end
        return intervals

    base_name = os.path.splitext(os.path.basename(csv_file))[0]
    output_file = f'{base_name}_data.csv'

    # Load signal IDs
    try:
        with open(csv_file, 'r') as file:
            reader = csv.reader(file)
            signal_ids = [row[0] for row in reader if row]
            logger.info(f"Loaded {len(signal_ids)} signal IDs from {csv_file}.")
    except Exception as e:
        logger.error(f"Error reading the CSV file {csv_file}: {e}")
        return

    # Parse the start and end times
    try:
        total_start_datetime = datetime.strptime(start_time_str, '%m/%d/%Y %I:%M:%S %p')
        total_end_datetime = datetime.strptime(end_time_str, '%m/%d/%Y %I:%M:%S %p')
        logger.info(f"Parsed start and end times: {total_start_datetime} to {total_end_datetime}.")
    except Exception as e:
        logger.error(f"Error parsing start or end time: {e}")
        return

    date_intervals = create_time_intervals(total_start_datetime, total_end_datetime, interval_minutes)

    # Prepare tasks
    tasks = []
    for signal_id in signal_ids:
        for start_dt_str, end_dt_str in date_intervals:
            tasks.append((signal_id, start_dt_str, end_dt_str))

    fieldnames = [
        'SignalID', 'StartDate', 'EndDate',
        'WestboundVolume', 'EastboundVolume',
        'NorthboundVolume', 'SouthboundVolume'
    ]

    # Write header to output file
    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

    # Adjust concurrency as needed
    concurrency_limit = 10
    semaphore = asyncio.Semaphore(concurrency_limit)

    # Limit the TCP connector concurrency
    connector = aiohttp.TCPConnector(limit_per_host=5)

    # Increase timeouts if needed
    timeout = aiohttp.ClientTimeout(total=60)

    lock = asyncio.Lock()

    async with ClientSession(connector=connector, timeout=timeout) as session:
        try:
            async with session.get(url_main) as resp:
                if resp.status == 200:
                    logger.info("Successfully accessed the main URL.")
                else:
                    logger.error(f"Failed to access main URL. Status code: {resp.status}")
                    return
        except Exception as e:
            logger.error(f"Error accessing the main URL: {e}")
            return

        # Adjust batch_size to better pace the requests
        batch_size = 20
        for task_batch in chunked(tasks, batch_size):
            results = await asyncio.gather(
                *[
                    fetch_data_for_interval(session, semaphore, lock, fieldnames, output_file, t[0], t[1], t[2])
                    for t in task_batch
                ],
                return_exceptions=True
            )

            # Log any exceptions
            for res in results:
                if isinstance(res, Exception):
                    logger.error(f"Task raised an exception: {res}")

            # Sleep between batches to reduce the chance of hitting rate limits
            await asyncio.sleep(3)


async def fetch_data_for_interval(session, semaphore, lock, fieldnames, output_file,
                                  signal_id, start_datetime_str, end_datetime_str):
    async with semaphore:
        await asyncio.sleep(0.1)

        logger.debug(
            f"Starting request for SignalID={signal_id}, "
            f"Start={start_datetime_str}, End={end_datetime_str}"
        )

        payload = {
            "SignalID": signal_id,
            "StartDate": start_datetime_str,
            "EndDate": end_datetime_str,
            "MetricTypeID": "7",
            "SelectedBinSize": "15",
            "ShowTotalVolume": 'true',
            "ShowNbEbVolume": 'true',
            "ShowSbWbVolume": 'true',
            "ShowTMCDetection": 'true',
            "ShowAdvanceDetection": 'true',
            "ShowDirectionalSplits": 'true'
        }

        headers = {
            'Accept': 'text/html, */*; q=0.01',
            'Origin': 'https://traffic.dot.ga.gov',
            'Referer': 'https://traffic.dot.ga.gov/ATSPM/',
            'X-Requested-With': 'XMLHttpRequest',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        }

        response = await robust_post(session, url_post, payload, headers, max_retries=4, backoff_factor=1.5)
        if response is None:
            logger.error(
                f"Failed to retrieve data after retries for SignalID={signal_id}, "
                f"Start={start_datetime_str}, End={end_datetime_str}"
            )
            return

        text = await response.text()
        soup = BeautifulSoup(text, 'lxml')

        wb_total_volume = None
        eb_total_volume = None
        nb_total_volume = None
        sb_total_volume = None

        tables = soup.find_all('table', {'class': 'table table-condensed table-bordered'})
        for table in tables:
            tds = table.find_all('td')
            for i in range(0, len(tds), 2):
                cols = tds[i:i+2]
                if len(cols) == 2:
                    metric = cols[0].get_text(strip=True).lower()
                    value = cols[1].get_text(strip=True)

                    if 'westbound total volume' in metric and wb_total_volume is None:
                        wb_total_volume = value
                    elif 'eastbound total volume' in metric and eb_total_volume is None:
                        eb_total_volume = value
                    elif 'northbound total volume' in metric and nb_total_volume is None:
                        nb_total_volume = value
                    elif 'southbound total volume' in metric and sb_total_volume is None:
                        sb_total_volume = value

        def parse_volume(volume):
            if volume is not None and volume.replace(',', '').isdigit():
                return int(volume.replace(',', ''))
            else:
                return ''

        wb_total_volume = parse_volume(wb_total_volume)
        eb_total_volume = parse_volume(eb_total_volume)
        nb_total_volume = parse_volume(nb_total_volume)
        sb_total_volume = parse_volume(sb_total_volume)

        data_row = {
            'SignalID': signal_id,
            'StartDate': start_datetime_str,
            'EndDate': end_datetime_str,
            'WestboundVolume': wb_total_volume,
            'EastboundVolume': eb_total_volume,
            'NorthboundVolume': nb_total_volume,
            'SouthboundVolume': sb_total_volume
        }

        async with lock:
            with open(output_file, 'a', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writerow(data_row)

        logger.info(
            f"Successfully wrote data for SignalID={signal_id}, "
            f"Start={start_datetime_str}, End={end_datetime_str}"
        )


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch approach volume data.')
    parser.add_argument('csv_file', help='CSV file containing signal IDs')
    parser.add_argument('start_time', help='Start time in format "MM/DD/YYYY hh:mm:ss AM/PM"')
    parser.add_argument('end_time', help='End time in format "MM/DD/YYYY hh:mm:ss AM/PM"')
    parser.add_argument('--interval', type=int, default=15, help='Interval in minutes (default: 15)')

    args = parser.parse_args()

    asyncio.run(fetch_approach_volume_data(args.csv_file, args.start_time, args.end_time, args.interval))
