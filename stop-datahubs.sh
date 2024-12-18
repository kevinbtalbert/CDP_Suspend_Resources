#!/bin/bash

source cdpclienv/bin/activate

declare -a dataHubNames
declare -a dataHubStatuses
declare -a validDataHubNames  # Hold only valid DataHub names for actions
declare -a selectedDataHubsIndexes
interactive=1  # Flag to control interactive prompts based on argument presence

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
    local output=$(cdp datahub describe-cluster --cluster-name "$dataHubName" 2>&1)
    
    if echo "$output" | grep -q 'does not exist'; then
        echo "DataHub $dataHubName does not exist, skipping."
        return  # Skip this DataHub if it does not exist
    fi

    local status=$(echo "$output" | grep '"clusterStatus":' | awk -F': "' '{print $2}' | tr -d '",')
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
    for dataHubName in $dataHubList; do
        checkDataHubStatus "$dataHubName"
    done
fi

for dataHubName in "${dataHubNames[@]}"; do
    checkDataHubStatus "$dataHubName"
done

printDataHubs

if [[ $interactive -eq 1 ]]; then
    read -p "Do you want to proceed with shutting down specific DataHubs? (Y/N): " proceed

    if [[ $proceed =~ ^[Yy]$ ]]; then
        read -p "Enter the indexes of the DataHubs to shut down (e.g., 1,3,5): " indexes
        IFS=',' read -ra ADDR <<< "$indexes"
        for i in "${ADDR[@]}"; do
            index=$((i-1))
            if [[ $index -lt ${#validDataHubNames[@]} ]]; then
                if [[ "${dataHubStatuses[$index]}" != "PERMISSION_DENIED" ]]; then
                    selectedDataHubsIndexes+=("$index")
                else
                    echo "Skipping ${validDataHubNames[$index]} due to permissions error."
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
    # Automatically select all provided DataHubs for shutting down, skipping any with PERMISSION_DENIED status
    for i in "${!validDataHubNames[@]}"; do
        if [[ "${dataHubStatuses[$i]}" != "PERMISSION_DENIED" ]]; then
            selectedDataHubsIndexes+=("$i")
        else
            echo "Skipping ${validDataHubNames[$i]} due to permissions error."
        fi
    done
fi

# Shutting down selected DataHubs
for index in "${selectedDataHubsIndexes[@]}"; do
    dataHubName="${validDataHubNames[$index]}"
    echo "Initiating shutdown for $dataHubName..."
    cdp datahub stop-cluster --cluster-name "$dataHubName"
done

if [ ${#selectedDataHubsIndexes[@]} -gt 0 ]; then
    echo "Monitoring the shutdown process for the selected DataHubs..."
    while :; do
        allStopped=true
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking status of selected DataHubs"
        for index in "${selectedDataHubsIndexes[@]}"; do
            dataHubName="${validDataHubNames[$index]}"
            status=$(cdp datahub describe-cluster --cluster-name "$dataHubName" | grep -o '"clusterStatus": *"[^"]*' | awk -F'"' '{print $4}')
            echo "$dataHubName: $status"
            if [[ "$status" != "STOPPED" && "$status" != "STOPPING" ]]; then
                allStopped=false
            fi
        done
        if [[ "$allStopped" = true ]]; then
            echo "All selected DataHubs have been successfully stopped."
            break
        fi
        sleep 15
    done
else
    echo "No valid selections made. No DataHubs are being shut down."
fi
