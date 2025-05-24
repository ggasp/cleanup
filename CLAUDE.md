# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a MacBook storage cleanup script (`cleanup.sh`) designed to help free up storage space on macOS systems. The script provides several cleanup options that can be run with user confirmation.

## Running the Script

The script requires sudo privileges for full functionality and can be run with:

```bash
sudo bash cleanup.sh
```

## Script Functionality

The cleanup script performs the following operations:
- Clearing Time Machine local snapshots
- Clearing system and user cache files
- Clearing browser caches (Safari, Chrome, Firefox)
- Clearing log files
- Clearing temporary files
- Clearing iOS device backups
- Emptying Trash
- Purging inactive memory

## Script Architecture

1. **User Interface**
   - Uses color-coded terminal output for better readability
   - Provides section headers and clear prompts
   - Asks for confirmation before each cleaning operation

2. **Core Functions**
   - `check_sudo`: Ensures script is run with sudo privileges
   - `confirm`: Gets user confirmation before operations
   - `calculate_size`: Shows the size of directories to be cleaned
   - `print_section`: Formats section headers consistently 
   - `show_space_info`: Displays available space information

3. **Safety Features**
   - Warns users to back up important data before proceeding
   - Requires explicit confirmation for each cleanup operation
   - Shows before/after space utilization

## Development Notes

When modifying the script, be careful with:
- Commands that delete files, especially those using `rm -rf`
- User permission handling and sudo requirements
- Directory paths which may vary between macOS versions