#!/bin/bash

declare -a dataHubNames
declare -a dataHubStatuses
declare -a selectedDataHubsIndexes

# Function to print DataHubs with status in a tabular format
printDataHubs() {
    echo "Index | DataHub Name         | Status"
    echo "-------------------------------------"
    for i in "${!dataHubNames[@]}"; do
        printf "%-5d | %-20s | %s\n" "$((i+1))" "${dataHubNames[$i]}" "${dataHubStatuses[$i]}"
    done
}

# Function to check each DataHub's status and add to arrays
checkDataHubStatus() {
    local dataHubName=$1
    local output=$(cdp datahub describe-cluster --cluster-name "$dataHubName" 2>&1)
    local status=$(cdp datahub describe-cluster --cluster-name "$dataHubName" 2>&1 | grep '"clusterStatus":' | awk -F': "' '{print $2}' | tr -d '",')

    # Check if status was successfully extracted; if not, it might be a permissions error or other issue
    if [[ -z "$status" ]]; then
        # Assuming permission denied or similar issue if status is empty
        status="PERMISSION_DENIED"
    fi

    dataHubNames+=("$dataHubName")
    dataHubStatuses+=("$status")
}

# Main logic to list clusters and process each
dataHubList=$(cdp datahub list-clusters | grep -o '"clusterName": *"[^"]*' | awk -F'"' '{print $4}')
for dataHubName in $dataHubList; do
    checkDataHubStatus "$dataHubName"
done

printDataHubs