#!/bin/bash

declare -a dataHubNames
declare -a dataHubStatuses
declare -a validDataHubNames  # Array to hold only valid DataHub names
declare -a selectedDataHubsIndexes
interactive=1  # Flag to control interactive prompts

# Function to print DataHubs with status in a tabular format
printDataHubs() {
    echo "Index | DataHub Name         | Status"
    echo "-------------------------------------"
    for i in "${!validDataHubNames[@]}"; do
        printf "%-5d | %-20s | %s\n" "$((i+1))" "${validDataHubNames[$i]}" "${dataHubStatuses[$i]}"
    done
}

# Function to check each DataHub's status and add to arrays if the DataHub exists
checkDataHubStatus() {
    local dataHubName=$1
    local exists=$(cdp datahub describe-cluster --cluster-name "$dataHubName" 2>&1)

    if echo "$exists" | grep -q 'does not exist'; then
        echo "DataHub $dataHubName does not exist, skipping."
        return  # Skip this DataHub if it does not exist
    fi

    local status=$(echo "$exists" | grep '"clusterStatus":' | awk -F': "' '{print $2}' | tr -d '",')
    if [[ -z "$status" ]]; then
        status="PERMISSION_DENIED"
    fi

    validDataHubNames+=("$dataHubName")
    dataHubStatuses+=("$status")
}

# Determine if specific DataHub names were provided as input
if [ $# -gt 0 ]; then
    IFS=',' read -ra dataHubNames <<< "$1"
    interactive=0  # Disable interactive mode if parameters are provided
else
    # Main logic to list clusters and process each if no specific names are provided
    dataHubList=$(cdp datahub list-clusters | grep -o '"clusterName": *"[^"]*' | awk -F'"' '{print $4}')
    dataHubNames=($dataHubList)  # Store all cluster names in dataHubNames array
fi

for dataHubName in "${dataHubNames[@]}"; do
    checkDataHubStatus "$dataHubName"
done

printDataHubs

if [[ $interactive -eq 1 ]]; then
    read -p "Do you want to proceed with starting specific DataHubs? (Y/N): " proceed

    if [[ $proceed =~ ^[Yy]$ ]]; then
        read -p "Enter the indexes of the DataHubs to start (e.g., 1,3,5): " indexes
        IFS=',' read -ra ADDR <<< "$indexes"
        for i in "${ADDR[@]}"; do
            index=$((i-1))
            if [[ $index -lt ${#dataHubNames[@]} ]]; then
                if [[ "${dataHubStatuses[$index]}" != "PERMISSION_DENIED" ]]; then
                    selectedDataHubsIndexes+=("$index")
                else
                    echo "Skipping ${dataHubNames[$index]} due to permissions error."
                fi
            else
                echo "Index $i is out of range."
            fi
        done
    else
        echo "Operation canceled by user."
        exit 1
    fi
else
    # Automatically select all provided DataHubs for starting, skipping any with PERMISSION_DENIED status
    for i in "${!dataHubNames[@]}"; do
        if [[ "${dataHubStatuses[$i]}" != "PERMISSION_DENIED" ]]; then
            selectedDataHubsIndexes+=("$i")
        else
            echo "Skipping ${dataHubNames[$i]} due to permissions error."
        fi
    done
fi

# Start the selected DataHubs
for index in "${selectedDataHubsIndexes[@]}"; do
    dataHubName="${dataHubNames[$index]}"
    echo "Initiating start for $dataHubName..."
    cdp datahub start-cluster --cluster-name "$dataHubName"
done

if [ ${#selectedDataHubsIndexes[@]} -gt 0 ]; then
    echo "Monitoring the start process for the selected DataHubs..."
    while :; do
        allRunning=true
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking status of selected DataHubs"
        for index in "${selectedDataHubsIndexes[@]}"; do
            dataHubName="${dataHubNames[$index]}"
            status=$(cdp datahub describe-cluster --cluster-name "$dataHubName" | grep -o '"clusterStatus": *"[^"]*' | awk -F'"' '{print $4}')
            echo "$dataHubName: $status"
            if [[ "$status" != "AVAILABLE" ]]; then
                allRunning=false
            fi
        done
        if [[ "$allRunning" = true ]]; then
            echo "All selected DataHubs have been successfully started."
            break
        fi
        sleep 15
    done
else
    echo "No valid selections made. No DataHubs are being started."
fi
