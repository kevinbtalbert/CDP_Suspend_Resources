## Run the below commands within virtual environment before executing
## pip install scheduler
## pip install pytz

import subprocess
import schedule
import time
from datetime import datetime
import pytz

def run_script(script_name):
    """Run a shell script."""
    print(f"Executing {script_name} at {datetime.now(pytz.timezone('US/Eastern'))}")
    subprocess.run(["bash", script_name])

def start_datahubs():
    """Function to start DataHubs."""
    run_script("./start-datahubs.sh solr-search,go-01-datahub")

def stop_datahubs():
    """Function to stop DataHubs."""
    run_script("./stop-datahubs.sh solr-search,go-01-datahub")

# Schedule the startup of DataHubs at 8am EST on Monday
schedule.every().monday.at("08:00").do(start_datahubs)

# Schedule the shutdown of DataHubs at 6pm EST on Friday
schedule.every().friday.at("18:00").do(stop_datahubs)

# Timezone information for logging
eastern = pytz.timezone('US/Eastern')

if __name__ == "__main__":
    print(f"Scheduler started at {datetime.now(eastern)}")
    while True:
        schedule.run_pending()
        time.sleep(1)
