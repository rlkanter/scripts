#!/bin/bash

# Check if the user provided a search term
if [ $# -lt 1 ]; then
  echo "Usage: $0 search_term"
  exit 1
fi

# Store the search term in a variable
search_term=$1

# Find and search for the term in all files in subdirectories
find . -type f -exec grep -Hn "$search_term" {} \;

# Explanation:
# - `find . -type f`: Finds all files starting from the current directory.
# - `-exec grep -Hn "$search_term" {}`: Executes the grep command on each file found.
#     - `-H`: Shows the filename with the match.
#     - `-n`: Shows the line number where the match occurs.
# - `\;`: Terminates the `-exec` option in find.
