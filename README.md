# CDP Suspend Resources

This repo contains a set of shell/python utilities to start, stop, and check the status of CDP environments, datahubs, and ML workspaces. It enables automation use cases in starting and stopping resources to save resource consumption costs.

## Quick Start - Master Scripts

The **master-shutdown.sh** and **master-startup.sh** scripts provide automated orchestration of CDP resource lifecycle management with configurable timing between phases.

### Master Shutdown Script

Orchestrates shutdown in the proper order: ML Workspaces → DataHubs → Environment

### Master Startup Script

Orchestrates startup in the proper order: Environment → DataHubs → ML Workspaces

### Features
- **Bidirectional Control** - Complete shutdown and startup automation
- Configurable delays between phases (default: 1 hour)
- All configuration via environment variables in the script
- Comprehensive logging and monitoring
- Ready for cron/scheduler integration
- Flexible scheduling for different resource types

### Quick Setup

```bash
# Step 1: Setup virtual environment
bash setup-venv.sh

# Step 2: Test your configuration
bash test-master-config.sh

# Step 3: Edit master-shutdown.sh and master-startup.sh with your settings
# - Set CDP credentials
# - Set environment name (optional)
# - Set DataHub names (optional)
# - Set ML Workspace CRNs (optional)
# - Set delay between phases

# Step 4: Run the master scripts
bash master-shutdown.sh   # Shutdown resources
bash master-startup.sh    # Startup resources
```

**Documentation**:
- [MASTER_SCRIPT_README.md](MASTER_SCRIPT_README.md) - Shutdown script detailed documentation
- [STARTUP_GUIDE.md](STARTUP_GUIDE.md) - Startup script detailed documentation (NEW!)
- [PHASE_SKIPPING_GUIDE.md](PHASE_SKIPPING_GUIDE.md) - Phase skipping feature guide
- [QUICK_START.md](QUICK_START.md) - Quick reference guide

## Prerequisite scripts

### setup-venv.sh (STEP 1)
This script should be run first. It instantiates a virtual environment on the system for running the cdp cli. If this is being run on a utility node with the cdp cli installed as part of its core, this step can be skipped.


### setup-credentials.sh (STEP 2)
This step configures the cli to leverage the CDP credential with access to the environment. It is necessary for the utility scripts to  touch the necessary resources to perform the remaining scripts in the archive. (e.g. start/stop services) For most public cloud usage, [default] and [https://console.us-west-1.cdp.cloudera.com] should be used.

![](/misc/setup-credentials.png)

## Script Library

**Note:** If you are running this inside a virtual environment (e.g. you did step 1), you will need to run the following command before running any of the scripts in the script library: `source cdpclienv/bin/activate`

### check-status-datahubs.sh
This script returns the status the datahubs the credential being used has access to.

Sample output: `bash ./check-status-datahubs.sh`
```bash
Index | DataHub Name         | Status
-------------------------------------
1     | worldwidebank        | AVAILABLE
2     | cdp-dc-profilers-b6509a1f | PERMISSION_DENIED
3     | go01-edge-flow       | STOPPED
4     | cod-xe0pmk42t0ds-edge | AVAILABLE
5     | go01-rtdm-aws        | STOPPED
6     | impact-datmart       | PERMISSION_DENIED
7     | go01-kudu-azure      | PERMISSION_DENIED
8     | go01-flink-azure     | PERMISSION_DENIED
9     | go01-default-azure   | PERMISSION_DENIED
10    | go01-aws-nifi        | AVAILABLE
11    | cdp-dc-profilers-443a42c2 | AVAILABLE
12    | solr-search          | UPDATE_IN_PROGRESS
13    | cod-xe0pmk42t0ds     | AVAILABLE
14    | cdf-aw-kafka-demo    | AVAILABLE
15    | go01-nifi-azure      | PERMISSION_DENIED
16    | go01-demo-aws        | AVAILABLE
17    | go01-kafka-azure     | PERMISSION_DENIED
18    | go01-flink-ssb       | AVAILABLE
19    | go01-datamart        | AVAILABLE
20    | cdf-aw-nifi-demo     | AVAILABLE
21    | cod-19jkxa55pxvb9    | PERMISSION_DENIED
```


### start-datahubs.sh
This script allows users to START datahubs the credential being used has access to. It constantly polls for START status completion of the selected datahubs. The below example shows shutting down 1 datahub however more can be done as well using comma separated values in the command line.

#### Usage Pattern 1 (Interactive)
`bash ./start-datahubs.sh`

#### Usage Pattern 2 (Non-interactive)
`bash ./start-datahubs.sh solr-search,go-01-solr,etc`


Sample output: `bash ./start-datahubs.sh`
```bash
Index | DataHub Name         | Status
-------------------------------------
1     | go01-edge-flow       | STOPPED
2     | go01-demo-aws        | AVAILABLE
3     | cod-xe0pmk42t0ds-edge | AVAILABLE
4     | worldwidebank        | AVAILABLE
5     | impact-datmart       | PERMISSION_DENIED
6     | cdp-dc-profilers-443a42c2 | AVAILABLE
7     | solr-search          | AVAILABLE
8     | go01-flink-ssb       | AVAILABLE
9     | go01-datamart        | AVAILABLE
10    | cod-19jkxa55pxvb9    | PERMISSION_DENIED
11    | go01-kafka-azure     | PERMISSION_DENIED
12    | go01-nifi-azure      | PERMISSION_DENIED
13    | go01-rtdm-aws        | STOPPED
14    | cdf-aw-nifi-demo     | AVAILABLE
15    | go01-default-azure   | PERMISSION_DENIED
16    | cod-xe0pmk42t0ds     | AVAILABLE
17    | go01-flink-azure     | PERMISSION_DENIED
18    | cdf-aw-kafka-demo    | AVAILABLE
19    | go01-kudu-azure      | PERMISSION_DENIED
20    | go01-aws-nifi        | AVAILABLE
21    | cdp-dc-profilers-b6509a1f | PERMISSION_DENIED
Do you want to proceed with starting specific DataHubs? (Y/N): y 
Enter the indexes of the DataHubs to start (e.g., 1,3,5): 1
Initiating start for go01-edge-flow...
Monitoring the start process for the selected DataHubs...
2024-03-15 15:13:30 - Checking status of selected DataHubs
go01-edge-flow: EXTERNAL_DATABASE_START_IN_PROGRESS
2024-03-15 15:13:46 - Checking status of selected DataHubs
go01-edge-flow: UPDATE_IN_PROGRESS
2024-03-15 15:14:03 - Checking status of selected DataHubs
go01-edge-flow: START_IN_PROGRESS
...
2024-03-15 15:17:32 - Checking status of selected DataHubs
go01-edge-flow: AVAILABLE
All selected DataHubs have been successfully started.
```


### suspend-ml-workspaces.sh
This script allows users to SUSPEND ML Workspaces the credential being used has access to. It constantly polls for suspension status completion of the selected workspaces.

#### Usage Pattern 1 (Interactive)
`bash ./suspend-ml-workspaces.sh`

#### Usage Pattern 2 (Non-interactive)
`bash ./suspend-ml-workspaces.sh crn:cdp:ml:...,crn:cdp:ml:...`

### start-ml-workspaces.sh
This script allows users to RESUME (start) ML Workspaces the credential being used has access to. It constantly polls for resume status completion of the selected workspaces.

#### Usage Pattern 1 (Interactive)
`bash ./start-ml-workspaces.sh`

#### Usage Pattern 2 (Non-interactive)
`bash ./start-ml-workspaces.sh crn:cdp:ml:...,crn:cdp:ml:...`

### stop-datahubs.sh
This script allows users to STOP datahubs the credential being used has access to. It constantly polls for START status completion of the selected datahubs. The below example shows shutting down 2 datahubs however more or less can be done as well using comma separated values in the command line.

#### Usage Pattern 1 (Interactive)
`bash ./stop-datahubs.sh`

#### Usage Pattern 2 (Non-interactive)
`bash ./stop-datahubs.sh solr-search,go-01-solr,etc`


Sample output: `bash ./stop-datahubs.sh`
```bash
Index | DataHub Name         | Status
-------------------------------------
1     | impact-datmart       | PERMISSION_DENIED
2     | cod-19jkxa55pxvb9    | PERMISSION_DENIED
3     | go01-default-azure   | PERMISSION_DENIED
4     | go01-rtdm-aws        | STOPPED
5     | cod-xe0pmk42t0ds-edge | AVAILABLE
6     | go01-aws-nifi        | AVAILABLE
7     | go01-demo-aws        | AVAILABLE
8     | go01-nifi-azure      | PERMISSION_DENIED
9     | go01-flink-ssb       | AVAILABLE
10    | cdf-aw-kafka-demo    | AVAILABLE
11    | go01-flink-azure     | PERMISSION_DENIED
12    | go01-kudu-azure      | PERMISSION_DENIED
13    | cdf-aw-nifi-demo     | AVAILABLE
14    | solr-search          | AVAILABLE
15    | go01-edge-flow       | AVAILABLE
16    | cdp-dc-profilers-443a42c2 | AVAILABLE
17    | go01-kafka-azure     | PERMISSION_DENIED
18    | worldwidebank        | AVAILABLE
19    | cod-xe0pmk42t0ds     | AVAILABLE
20    | cdp-dc-profilers-b6509a1f | PERMISSION_DENIED
21    | go01-datamart        | AVAILABLE
Do you want to proceed with shutting down specific DataHubs? (Y/N): y
Enter the indexes of the DataHubs to shut down (e.g., 1,3,5): 14,15
Initiating shutdown for solr-search...
Initiating shutdown for go01-edge-flow...
Monitoring the shutdown process for the selected DataHubs...
2024-03-15 15:21:20 - Checking status of selected DataHubs
solr-search: STOP_IN_PROGRESS
go01-edge-flow: STOP_IN_PROGRESS
...
2024-03-15 15:22:46 - Checking status of selected DataHubs
solr-search: STOPPED
go01-edge-flow: EXTERNAL_DATABASE_STOP_IN_PROGRESS
...
2024-03-15 15:33:56 - Checking status of selected DataHubs
solr-search: STOPPED
go01-edge-flow: STOPPED
All selected DataHubs have been successfully stopped.
```

### datahub-automator.py
This is a sample for locally automating startups/shutdowns, and can be run from an edge node or user's personal box. See also, Azure Functions approach below.

### Azure Functions for Automation

#### 1. Create Timer Trigger Function

Step 1: In the Azure Portal, create a new Function App if you haven't already.


Step 2: Within your Function App, create a new function and select the "Timer trigger" template.


Step 3: Set the schedule expression using the NCRONTAB format. For example, to run at 8am EST every Monday, you might use 0 0 13 * * Mon assuming the Azure server's time zone is UTC. Adjust the time accordingly for 6pm EST on Fridays.


#### 2. Implement the Script Execution
Azure Functions support various programming languages, including Python. You can implement the logic to execute your shell scripts (start-datahubs.sh and stop-datahubs.sh) within the function. For Python, you would use the subprocess module, similar to the local Python script approach.

```python
import datetime
import logging
import subprocess
import azure.functions as func

def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function ran at %s', utc_timestamp)

    # Example to run a script - adjust the path and script name as needed
    script_path = "/path/to/your/script.sh"
    result = subprocess.run(["bash", script_path], capture_output=True, text=True)

    logging.info(f"Script output: {result.stdout}")
    if result.stderr:
        logging.error(f"Script error: {result.stderr}")
```


#### 3. Adjust for Time Zones
Azure Functions run in UTC by default. You can adjust the CRON expression for your timezone, or you can manage timezone settings within the Azure Function App settings by setting the WEBSITE_TIME_ZONE to the desired timezone, like Eastern Standard Time.


#### 4. Deploy and Monitor
Deploy your function to Azure, and monitor its execution through the Azure Portal. Azure provides logs and monitoring tools to help you track the function's execution and troubleshoot any issues.

