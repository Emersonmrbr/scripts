#!/bin/bash

# Directory where the scripts to be executed are located
SCRIPT_DIR="/volume1/scripts"

# List of scripts to be executed
SCRIPTS=("${SCRIPT_DIR}/github-cron-wrapper.sh" "${SCRIPT_DIR}/paymo-cron-wrapper.sh")

# Loop to execute each script in the list
for script in "${SCRIPTS[@]}"; do
    # Executes the script in the background
    bash "$script" &
    PROCESS=$!
    # Waits for the background process to finish
    wait $PROCESS
    EXIT_CODE=$?
    # Checks if there was an error during script execution
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Error executing $script (exit code: $EXIT_CODE)"
        continue 1
    fi
    done