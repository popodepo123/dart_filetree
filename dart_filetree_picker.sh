#!/usr/bin/env bash

# DFT Picker for Helix - Improved temporary file approach
# Uses temporary file but with better error handling

# The first argument ($1) will be the Helix command (e.g., 'open', 'vsplit', 'hsplit')
# The second argument ($2) will be the directory of the current buffer, passed from Helix.

# Determine the starting directory for DFT
if [[ -n "$2" && -d "$2" ]]; then
    START_DIR="$2"
else
    START_DIR="."
fi

# Set up environment for zellij compatibility
export TERM=xterm-256color
export COLUMNS=${COLUMNS:-80}
export LINES=${LINES:-24}

# Create a temporary file for DFT to write the selected path to
chooser_file=$(mktemp)
trap 'rm -f "$chooser_file"' EXIT

# Ensure we're in a proper terminal environment
if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    echo "Error: This script must be run in an interactive terminal" >&2
    zellij action toggle-floating-panes
    exit 1
fi

# Run DFT with the chooser file
~/dart_filetree/bin/dart_filetree.exe "$START_DIR" --chooser-file="$chooser_file"

# Read the selected path from the chooser file
selected_path=$(cat "$chooser_file" 2>/dev/null)

# Check if a path was selected
if [[ -n "$selected_path" && -e "$selected_path" ]]; then
    # If a valid path was selected, send it to Helix
    zellij action toggle-floating-panes
    zellij action write 27 # send <Escape> key
    zellij action write-chars ":$1 $selected_path"
    zellij action write 13 # send <Enter> key
else
    # If no valid path was selected, just close the pane
    zellij action toggle-floating-panes
fi
