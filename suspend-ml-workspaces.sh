#!/bin/bash

source cdpclienv/bin/activate

declare -a workspaceCRNs
declare -a workspaceNames
declare -a workspaceStatuses
declare -a validWorkspaceCRNs  # Hold only valid workspace CRNs for actions
declare -a selectedWorkspaceIndexes
interactive=1  # Flag to control interactive prompts based on argument presence

# Function to print workspaces with status in a tabular format
printWorkspaces() {
    echo "Index | Workspace Name                    | CRN                                     | Status"
    echo "--------------------------------------------------------------------------------------------"
    for i in "${!validWorkspaceCRNs[@]}"; do
        printf "%-5d | %-32s | %-40s | %s\n" "$((i+1))" "${workspaceNames[$i]}" "${validWorkspaceCRNs[$i]}" "${workspaceStatuses[$i]}"
    done
}

# Function to check each workspace's status and add to arrays if it exists
checkWorkspaceStatus() {
    local workspaceCRN=$1
    local output=$(cdp ml describe-workspace --workspace-crn "$workspaceCRN" 2>&1)

    if echo "$output" | grep -q 'does not exist'; then
        echo "Workspace with CRN $workspaceCRN does not exist, skipping."
        return  # Skip this workspace if it does not exist
    fi

    local status=$(echo "$output" | grep '"instanceStatus":' | awk -F': "' '{print $2}' | tr -d '",')
    local name=$(echo "$output" | grep '"instanceName":' | awk -F': "' '{print $2}' | tr -d '",')

    if [[ -z "$status" ]]; then
        status="PERMISSION_DENIED"
    fi

    validWorkspaceCRNs+=("$workspaceCRN")
    workspaceStatuses+=("$status")
    workspaceNames+=("$name")
}

# Determine if specific workspace CRNs were provided as input
if [ $# -gt 0 ]; then
    IFS=',' read -ra workspaceCRNs <<< "$1"
    interactive=0  # Disable interactive mode if parameters are provided
else
    # Main logic to list workspaces and process each if no specific CRNs are provided
    workspaceList=$(cdp ml list-workspaces | grep -o '"crn": *"[^"]*' | awk -F'"' '{print $4}')
    for workspaceCRN in $workspaceList; do
        checkWorkspaceStatus "$workspaceCRN"
    done
fi

for workspaceCRN in "${workspaceCRNs[@]}"; do
    checkWorkspaceStatus "$workspaceCRN"
done

printWorkspaces

if [[ $interactive -eq 1 ]]; then
    read -p "Do you want to proceed with suspending specific workspaces? (Y/N): " proceed

    if [[ $proceed =~ ^[Yy]$ ]]; then
        read -p "Enter the indexes of the workspaces to suspend (e.g., 1,3,5): " indexes
        IFS=',' read -ra ADDR <<< "$indexes"
        for i in "${ADDR[@]}"; do
            index=$((i-1))
            if [[ $index -lt ${#validWorkspaceCRNs[@]} ]]; then
                if [[ "${workspaceStatuses[$index]}" != "PERMISSION_DENIED" ]]; then
                    selectedWorkspaceIndexes+=("$index")
                else
                    echo "Skipping ${workspaceNames[$index]} due to permissions error."
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
    # Automatically select all provided workspaces for suspension, skipping any with PERMISSION_DENIED status
    for i in "${!validWorkspaceCRNs[@]}"; do
        if [[ "${workspaceStatuses[$i]}" != "PERMISSION_DENIED" ]]; then
            selectedWorkspaceIndexes+=("$i")
        else
            echo "Skipping ${workspaceNames[$i]} due to permissions error."
        fi
    done
fi

# Suspending selected workspaces
declare -a workspacesToMonitor  # Track workspaces that need monitoring
for index in "${selectedWorkspaceIndexes[@]}"; do
    workspaceCRN="${validWorkspaceCRNs[$index]}"
    currentStatus="${workspaceStatuses[$index]}"
    
    # Check if workspace is already suspended
    if [[ "$currentStatus" == "suspend:finished" ]]; then
        echo "✓ Workspace ${workspaceNames[$index]} is already suspended. Skipping."
        continue
    fi
    
    # Check if workspace is already in the process of suspending
    if [[ "$currentStatus" == "suspend:started" ]]; then
        echo "⟳ Workspace ${workspaceNames[$index]} is already suspending. Will monitor progress."
        workspacesToMonitor+=("$index")
        continue
    fi
    
    echo "Initiating suspension for workspace ${workspaceNames[$index]} ($workspaceCRN)..."
    suspendOutput=$(cdp ml suspend-workspace --workspace-crn "$workspaceCRN" 2>&1)
    
    if echo "$suspendOutput" | grep -q "Cannot suspend a workbench that is not ready"; then
        echo "✓ Workspace ${workspaceNames[$index]} is already suspended."
    elif echo "$suspendOutput" | grep -q "error"; then
        echo "⚠ Warning: Error suspending workspace ${workspaceNames[$index]}: $suspendOutput"
    else
        workspacesToMonitor+=("$index")
    fi
done

if [ ${#workspacesToMonitor[@]} -gt 0 ]; then
    echo "Monitoring the suspension process for the selected workspaces..."
    while :; do
        allSuspended=true
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking status of workspaces"
        for index in "${workspacesToMonitor[@]}"; do
            workspaceCRN="${validWorkspaceCRNs[$index]}"
            status=$(cdp ml describe-workspace --workspace-crn "$workspaceCRN" | grep -o '"instanceStatus": *"[^"]*' | awk -F'"' '{print $4}')
            echo "${workspaceNames[$index]} ($workspaceCRN): $status"
            # Check for suspend:finished (completed) or suspend:started (in progress)
            if [[ "$status" != "suspend:finished" ]]; then
                allSuspended=false
            fi
        done
        if [[ "$allSuspended" = true ]]; then
            echo "All workspaces have been successfully suspended."
            break
        fi
        sleep 15
    done
elif [ ${#selectedWorkspaceIndexes[@]} -gt 0 ]; then
    echo "All selected workspaces were already suspended. No monitoring needed."
else
    echo "No valid selections made. No workspaces are being suspended."
fi


