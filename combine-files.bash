#!/bin/bash

# Check if at least one filename is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1> [file2] [file3] ..."
    exit 1
fi

# Output file
output_file="/var/www/html/output.txt"

# Clear the output file if it exists
> "$output_file"

# Loop through all provided filenames
for file in "$@"; do
    if [ -f "$file" ]; then
        # Write the filename
        echo "File: $file" >> "$output_file"
        
        # Write the file content
        cat "$file" >> "$output_file"
        
        # Write the separator
        echo "----------------" >> "$output_file"
    else
        echo "Warning: File '$file' not found." >&2
    fi
done

echo "Output has been written to $output_file"
