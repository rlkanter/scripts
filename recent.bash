#!/bin/bash

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <number_of_hours>"
    exit 1
fi

# Get the number of hours from the argument
hours=$1

# Convert hours to minutes
minutes=$((hours * 60))

# Debug information
echo "Debugging: hours = $hours"
echo "Debugging: minutes = $minutes"
echo "Debugging: Current directory: $(pwd)"

# Use find to locate files modified within the specified number of minutes
# Exclude files ending with ~
# Start the search from the current directory
echo "Running command: find \"$(pwd)\" -type f -mmin -$minutes ! -name '*~' -print"
find "$(pwd)" -type f -mmin -$minutes ! -name '*~' -print

# If no files are found, print a message
if [ $? -eq 0 ] && [ -z "$(find "$(pwd)" -type f -mmin -$minutes ! -name '*~' -print)" ]; then
    echo "No files found modified in the last $hours hours (excluding backup files ending with ~)."
fi
