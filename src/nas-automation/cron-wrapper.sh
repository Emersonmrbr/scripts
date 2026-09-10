#!/bin/bash

# Directory where the scripts to be executed are located
SCRIPT_DIR="/volume1/Scripts/src/nas-automation"

# List of scripts to be executed
SCRIPTS=("${SCRIPT_DIR}"/*-cron-wrapper.sh)

# Loop to execute each script in the list
for script in "${SCRIPTS[@]}"; do
    # Executes the script in the background
if [[ "$script" != *paymo* ]]; then
    bash "$script" < /dev/null &
    PROCESS=$!
    # Waits for the background process to finish
    wait $PROCESS
    EXIT_CODE=$?
    # Checks if there was an error during script execution
    if (( $EXIT_CODE != 0 )); then
        echo "Error executing $script (exit code: $EXIT_CODE)"
        continue
    fi
fi
done

# Ensure all background processes are terminated
wait
exit 0