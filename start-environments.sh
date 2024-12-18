#!/bin/bash

source cdpclienv/bin/activate

declare -a environmentNames
declare -a environmentStatuses
declare -a validEnvironmentNames  # Hold only valid environment names for actions
declare -a selectedEnvironmentsIndexes
interactive=1  # Flag to control interactive prompts based on argument presence

# Function to print environments with status in a tabular format
printEnvironments() {
    echo "Index | Environment Name      | Status"
    echo "--------------------------------------"
    for i in "${!validEnvironmentNames[@]}"; do
        printf "%-5d | %-24s | %s\n" "$((i+1))" "${validEnvironmentNames[$i]}" "${environmentStatuses[$i]}"
    done
}

# Function to check each environment's status and add to arrays if the environment exists
checkEnvironmentStatus() {
    local environmentName=$1
    local output=$(cdp environments describe-environment --environment-name "$environmentName" 2>&1)

    if echo "$output" | grep -q 'does not exist'; then
        echo "Environment $environmentName does not exist, skipping."
        return  # Skip this environment if it does not exist
    fi

    local status=$(echo "$output" | grep '"status":' | awk -F': "' '{print $2}' | tr -d '",')
    if [[ -z "$status" ]]; then
        status="PERMISSION_DENIED"
    fi

    validEnvironmentNames+=("$environmentName")
    environmentStatuses+=("$status")
}

# Determine if specific environment names were provided as input
if [ $# -gt 0 ]; then
    IFS=',' read -ra environmentNames <<< "$1"
    interactive=0  # Disable interactive mode if parameters are provided
else
    # Main logic to list environments and process each if no specific names are provided
    environmentList=$(cdp environments list-environments | grep -o '"environmentName": *"[^"]*' | awk -F'"' '{print $4}')
    for environmentName in $environmentList; do
        checkEnvironmentStatus "$environmentName"
    done
fi

for environmentName in "${environmentNames[@]}"; do
    checkEnvironmentStatus "$environmentName"
done

printEnvironments

if [[ $interactive -eq 1 ]]; then
    read -p "Do you want to proceed with starting specific environments? (Y/N): " proceed

    if [[ $proceed =~ ^[Yy]$ ]]; then
        read -p "Enter the indexes of the environments to start (e.g., 1,3,5): " indexes
        IFS=',' read -ra ADDR <<< "$indexes"
        for i in "${ADDR[@]}"; do
            index=$((i-1))
            if [[ $index -lt ${#validEnvironmentNames[@]} ]]; then
                if [[ "${environmentStatuses[$index]}" != "PERMISSION_DENIED" ]]; then
                    selectedEnvironmentsIndexes+=("$index")
                else
                    echo "Skipping ${validEnvironmentNames[$index]} due to permissions error."
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
    # Automatically select all provided environments for starting, skipping any with PERMISSION_DENIED status
    for i in "${!validEnvironmentNames[@]}"; do
        if [[ "${environmentStatuses[$i]}" != "PERMISSION_DENIED" ]]; then
            selectedEnvironmentsIndexes+=("$i")
        else
            echo "Skipping ${validEnvironmentNames[$i]} due to permissions error."
        fi
    done
fi

# Starting selected environments
for index in "${selectedEnvironmentsIndexes[@]}"; do
    environmentName="${validEnvironmentNames[$index]}"
    echo "Initiating start for $environmentName..."
    cdp environments start-environment --environment-name "$environmentName"
done

if [ ${#selectedEnvironmentsIndexes[@]} -gt 0 ]; then
    echo "Monitoring the start process for the selected environments..."
    while :; do
        allStarted=true
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking status of selected environments"
        for index in "${selectedEnvironmentsIndexes[@]}"; do
            environmentName="${validEnvironmentNames[$index]}"
            status=$(cdp environments describe-environment --environment-name "$environmentName" | grep -o '"status": *"[^"]*' | awk -F'"' '{print $4}')
            echo "$environmentName: $status"
            if [[ "$status" != "AVAILABLE" && "$status" != "RUNNING" ]]; then
                allStarted=false
            fi
        done
        if [[ "$allStarted" = true ]]; then
            echo "All selected environments have been successfully started."
            break
        fi
        sleep 15
    done
    exit 0  # Ensure the script terminates after monitoring is complete
else
    echo "No valid selections made. No environments are being started."
fi

