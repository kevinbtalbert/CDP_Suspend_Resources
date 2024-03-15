# CDP Suspend Datahub Resources

This repo contains a set of shell/python utilities to start, stop, and check the status of CDP environments and datahubs. It enables automation use cases in starting and stopping datahubs and environments to save resource consumption costs.

## Prerequisite scripts

### setup-venv.sh (STEP 1)
This script should be run first. It instantiates a virtual environment on the system for running the cdp cli. If this is being run on a utility node with the cdp cli installed as part of its core, this step can be skipped.


### setup-credentials.sh (STEP 2)
This step configures the cli to leverage the CDP credential with access to the environment. It is necessary for the utility scripts to  touch the necessary resources to perform the remaining scripts in the archive. (e.g. start/stop services) For most public cloud usage, [default] and [https://console.us-west-1.cdp.cloudera.com] should be used.

![](/misc/setup-credentials.png)

## Script Library

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


### stop-datahubs.sh
This script allows users to STOP datahubs the credential being used has access to. It constantly polls for START status completion of the selected datahubs. The below example shows shutting down 2 datahubs however more or less can be done as well using comma separated values in the command line.

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


