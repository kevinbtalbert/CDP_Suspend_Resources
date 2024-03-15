#!/bin/bash
source cdpclienv/bin/activate

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
    local status=$(cdp datahub describe-cluster --cluster-name "$dataHubName" 2>&1 | grep '"clusterStatus":' | awk -F': "' '{print $2}' | tr -d '",')

    if [[ -z "$status" ]]; then
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
        fi
    done

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
fi
