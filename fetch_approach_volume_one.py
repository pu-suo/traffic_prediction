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

logging.basicConfig(filename='fetch_approach_volume.log',
                    level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

url_main = "https://traffic.dot.ga.gov/ATSPM/"
url_post = "https://traffic.dot.ga.gov/ATSPM/DefaultCharts/GetApproachVolumeMetric"

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

    try:
        with open(csv_file, 'r') as file:
            reader = csv.reader(file)
            signal_ids = [row[0] for row in reader if row]
            logging.info(f"Loaded {len(signal_ids)} signal IDs from {csv_file}.")
    except Exception as e:
        logging.error(f"Error reading the CSV file: {e}")
        return

    try:
        total_start_datetime = datetime.strptime(start_time_str, '%m/%d/%Y %I:%M:%S %p')
        total_end_datetime = datetime.strptime(end_time_str, '%m/%d/%Y %I:%M:%S %p')
        logging.info(f"Parsed start and end times: {total_start_datetime} to {total_end_datetime}.")
    except Exception as e:
        logging.error(f"Error parsing start or end time: {e}")
        return

    date_intervals = create_time_intervals(total_start_datetime, total_end_datetime, interval_minutes)

    tasks = []
    for signal_id in signal_ids:
        for start_datetime_str, end_datetime_str in date_intervals:
            tasks.append((signal_id, start_datetime_str, end_datetime_str))

    fieldnames = ['SignalID', 'StartDate', 'EndDate', 'WestboundVolume',
                  'EastboundVolume', 'NorthboundVolume', 'SouthboundVolume']

    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

    semaphore = asyncio.Semaphore(10)

    connector = aiohttp.TCPConnector(limit_per_host=5)
    timeout = aiohttp.ClientTimeout(total=30)

    lock = asyncio.Lock()

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

        batch_size = 50
        for task_batch in chunked(tasks, batch_size):
            await asyncio.gather(
                *[fetch_data_for_interval(session, semaphore, lock, fieldnames, output_file, task[0], task[1], task[2]) for task in task_batch],
                return_exceptions=True
            )
            await asyncio.sleep(5)


async def fetch_data_for_interval(session, semaphore, lock, fieldnames, output_file, signal_id, start_datetime_str, end_datetime_str):
    async with semaphore:
        await asyncio.sleep(0.1)

        logging.info(f"Fetching data for SignalID {signal_id} from {start_datetime_str} to {end_datetime_str}")
        print(f"Fetching data for SignalID {signal_id} from {start_datetime_str} to {end_datetime_str}")

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

        try:
            async with session.post(url_post, data=payload, headers=headers) as response:
                if response.status == 200:
                    logging.info(f"Successfully fetched data for SignalID {signal_id}.")
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
                else:
                    logging.error(f"Error fetching data for SignalID {signal_id}. Status code: {response.status}")
        except Exception as e:
            logging.error(f"An error occurred for SignalID {signal_id}: {e}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch approach volume data.')
    parser.add_argument('csv_file', help='CSV file containing signal IDs')
    parser.add_argument('start_time', help='Start time in format "MM/DD/YYYY hh:mm:ss AM/PM"')
    parser.add_argument('end_time', help='End time in format "MM/DD/YYYY hh:mm:ss AM/PM"')
    parser.add_argument('--interval', type=int, default=15, help='Interval in minutes (default: 15)')

    args = parser.parse_args()

    asyncio.run(fetch_approach_volume_data(args.csv_file, args.start_time, args.end_time, args.interval))