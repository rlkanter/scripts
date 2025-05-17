#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] [file1] [file2] [file3] ..."
    echo "Options:"
    echo "  --include-types=<ext1,ext2,...>   Include files with specified extensions"
    echo "  --exclude-directory=<dir1,dir2,...>   Exclude files from specified directories"
    echo ""
    echo "Examples:"
    echo "  $0 --include-types=js,md"
    echo "  $0 --exclude-directory=node_modules,vendor file1.php file2.php"
    echo "  $0 --include-types=php,js --exclude-directory=tests"
    exit 1
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_usage
fi

# Default values
include_types=""
exclude_dirs=""
files_to_process=()
home_dir=$(pwd)
output_file="/efs-uploads/uploads/uploads/logs/code.txt"

# Process command line arguments
for arg in "$@"; do
    if [[ $arg == --include-types=* ]]; then
        include_types="${arg#*=}"
    elif [[ $arg == --exclude-directory=* ]]; then
        exclude_dirs="${arg#*=}"
    elif [[ $arg == --help ]]; then
        show_usage
    else
        files_to_process+=("$arg")
    fi
done

# Function to check if a file is in .gitignore
is_ignored() {
    local file="$1"
    local relative_path="${file#$home_dir/}"

    # Check if .gitignore exists
    if [ -f "$home_dir/.gitignore" ]; then
        # Check if file matches any pattern in .gitignore
        if git check-ignore -q "$relative_path" 2>/dev/null; then
            return 0  # File is ignored
        fi
    fi
    return 1  # File is not ignored
}

# Function to check if a file should be excluded based on directory
should_exclude_dir() {
    local file="$1"

    if [ -n "$exclude_dirs" ]; then
        IFS=',' read -ra DIRS <<< "$exclude_dirs"
        for dir in "${DIRS[@]}"; do
            if [[ "$file" == *"/$dir/"* || "$file" == *"/$dir" ]]; then
                return 0  # Exclude this file
            fi
        done
    fi
    return 1  # Don't exclude
}

# Function to check if a file should be included based on extension
should_include_type() {
    local file="$1"

    # If no include_types specified, include all files
    if [ -z "$include_types" ]; then
        return 0  # Include this file
    fi

    IFS=',' read -ra EXTS <<< "$include_types"
    for ext in "${EXTS[@]}"; do
        if [[ "$file" == *".$ext" ]]; then
            return 0  # Include this file
        fi
    done
    return 1  # Don't include
}

# Function to find files based on extensions
find_files_by_type() {
    IFS=',' read -ra EXTS <<< "$include_types"
    find_args=()

    for ext in "${EXTS[@]}"; do
        find_args+=(-o -name "*.$ext")
    done

    # Remove the first -o if it exists
    if [ ${#find_args[@]} -gt 0 ]; then
        find_args=("${find_args[@]:1}")
    fi

    find "$home_dir" -type f "${find_args[@]}" 2>/dev/null
}

# Clear the output file if it exists
> "$output_file"

# Store list of processed files
processed_files=()
file_tree=()

# Process the files
if [ ${#files_to_process[@]} -gt 0 ]; then
    # Process explicitly provided files
    for file in "${files_to_process[@]}"; do
        if [ -f "$file" ]; then
            if ! is_ignored "$file" && ! should_exclude_dir "$file" && should_include_type "$file"; then
                echo "File: $file" >> "$output_file"
                cat "$file" >> "$output_file"
                echo "----------------" >> "$output_file"
                processed_files+=("$file")
                relative_path="${file#$home_dir/}"
                file_tree+=("$relative_path")
            fi
        else
            echo "Warning: File '$file' not found." >&2
        fi
    done
elif [ -n "$include_types" ]; then
    # Find and process files by type
    while IFS= read -r file; do
        if ! is_ignored "$file" && ! should_exclude_dir "$file"; then
            echo "File: $file" >> "$output_file"
            cat "$file" >> "$output_file"
            echo "----------------" >> "$output_file"
            processed_files+=("$file")
            relative_path="${file#$home_dir/}"
            file_tree+=("$relative_path")
        fi
    done < <(find_files_by_type)
else
    echo "Error: Either specific files or --include-types must be provided."
    show_usage
fi

# Sort file paths to build the tree structure
IFS=$'\n' sorted_files=($(sort <<<"${file_tree[*]}"))
unset IFS

# Print file tree structure
echo -e "\nFiles included:"
printf -- '- %s\n' "${sorted_files[@]}"

# Build and print a proper tree structure
echo -e "\nDirectory structure:"

# Convert list of files to a tree structure
declare -A dirs
root_dir=""

# Process each file path
for file in "${sorted_files[@]}"; do
    path=""
    # Split the path into components
    IFS='/' read -ra PARTS <<< "$file"

    # Process each part of the path
    for ((i=0; i<${#PARTS[@]}-1; i++)); do
        part=${PARTS[i]}
        if [ -z "$path" ]; then
            path="$part"
        else
            path="$path/$part"
        fi
        dirs["$path"]=1
    done

    # Store the full path with the filename
    if [ -z "$path" ]; then
        dirs["${PARTS[-1]}"]=2  # 2 marks it as a file
    else
        dirs["$path/${PARTS[-1]}"]=2  # 2 marks it as a file
    fi
done

# Sort the keys
sorted_keys=($(printf '%s\n' "${!dirs[@]}" | sort))

# Build the tree
previous_parts=()
for key in "${sorted_keys[@]}"; do
    IFS='/' read -ra current_parts <<< "$key"

    # Calculate the common prefix length
    common_len=0
    for ((i=0; i<${#previous_parts[@]} && i<${#current_parts[@]}; i++)); do
        if [ "${previous_parts[i]}" = "${current_parts[i]}" ]; then
            ((common_len++))
        else
            break
        fi
    done

    # Print the parts that are different
    for ((i=common_len; i<${#current_parts[@]}; i++)); do
        indent=$(printf "%*s" $((i*2)) "")
        if [ $i -eq $((${#current_parts[@]}-1)) ] && [ ${dirs["$key"]} -eq 2 ]; then
            echo "$indent└── ${current_parts[i]}"
        else
            echo "$indent├── ${current_parts[i]}/"
        fi
    done

    previous_parts=("${current_parts[@]}")
done

echo "Output has been written to $output_file"
echo "Total files processed: ${#processed_files[@]}"

