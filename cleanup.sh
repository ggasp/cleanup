#!/bin/bash

# MacBook Storage Cleanup Script
# Script to help free up storage space on your Mac
# Run this script with sudo for full functionality

# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}=========================================================${NC}"
echo -e "${BOLD}${BLUE}           MacBook Storage Cleanup Script                ${NC}"
echo -e "${BOLD}${BLUE}=========================================================${NC}"
echo ""
echo -e "${BOLD}This script will help free up storage space on your Mac.${NC}"
echo -e "${YELLOW}Please make sure to have a backup of your important data before proceeding.${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Function to calculate sizes
calculate_size() {
    du -sh "$1" 2>/dev/null | awk '{print $1}'
}

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script with sudo for full functionality.${NC}"
        echo -e "${YELLOW}Example: sudo bash cleanup-script.sh${NC}"
        exit 1
    fi
}

# Function to get user confirmation
confirm() {
    read -p "$(echo -e ${YELLOW}$1 [y/N]: ${NC})" response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# Function to show space before and after cleaning
show_space_info() {
    local operation=$1
    df -h / | grep -v Filesystem | awk '{print "Available space " operation ": " $4 " (Used: " $3 ", Total: " $2 ")"}'
}

# Start of cleanup operations
check_sudo
SPACE_BEFORE=$(df -h / | grep -v Filesystem | awk '{print $4}')
echo -e "${BLUE}Current available space: ${BOLD}$SPACE_BEFORE${NC}"
echo ""

# 1. Clear Time Machine Local Snapshots
print_section "1. Clearing Time Machine Local Snapshots"
echo "Checking for Time Machine local snapshots..."
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null)

if [ -z "$SNAPSHOTS" ]; then
    echo -e "${GREEN}No Time Machine local snapshots found.${NC}"
else
    echo -e "${YELLOW}Found Time Machine local snapshots.${NC}"
    echo "$SNAPSHOTS"
    
    if confirm "Do you want to delete these snapshots?"; then
        echo "Deleting Time Machine local snapshots..."
        for snapshot in $(tmutil listlocalsnapshots / | cut -d. -f4); do
            echo "Deleting snapshot: $snapshot"
            tmutil deletelocalsnapshots "$snapshot"
        done
        echo -e "${GREEN}All Time Machine local snapshots have been deleted.${NC}"
    else
        echo "Skipping Time Machine snapshots deletion."
    fi
fi

echo ""

# 2. Clear System Cache Files
print_section "2. Clearing System Cache Files"
SYSTEM_CACHE_SIZE=$(calculate_size "/Library/Caches/")
echo -e "System Cache size: ${BOLD}$SYSTEM_CACHE_SIZE${NC}"

if confirm "Do you want to clear system cache files?"; then
    echo "Clearing System Cache files..."
    for cacheDir in /Library/Caches/*; do
        if [ -d "$cacheDir" ]; then
            CACHE_NAME=$(basename "$cacheDir")
            CACHE_SIZE=$(calculate_size "$cacheDir")
            echo "Clearing $CACHE_NAME ($CACHE_SIZE)..."
            rm -rf "$cacheDir"/* 2>/dev/null
        fi
    done
    echo -e "${GREEN}System cache files cleared.${NC}"
else
    echo "Skipping system cache files."
fi

echo ""

# 3. Clear User Cache Files
print_section "3. Clearing User Cache Files"
USER_CACHE_SIZE=$(calculate_size "/Users/$(whoami)/Library/Caches/")
echo -e "User Cache size: ${BOLD}$USER_CACHE_SIZE${NC}"

if confirm "Do you want to clear user cache files?"; then
    echo "Clearing User Cache files..."
    for cacheDir in /Users/$(whoami)/Library/Caches/*; do
        if [ -d "$cacheDir" ]; then
            CACHE_NAME=$(basename "$cacheDir")
            CACHE_SIZE=$(calculate_size "$cacheDir")
            echo "Clearing $CACHE_NAME ($CACHE_SIZE)..."
            rm -rf "$cacheDir"/* 2>/dev/null
        fi
    done
    echo -e "${GREEN}User cache files cleared.${NC}"
else
    echo "Skipping user cache files."
fi

echo ""

# 4. Clear Browser Caches
print_section "4. Clearing Browser Caches"

# Safari Cache
SAFARI_CACHE_PATH="/Users/$(whoami)/Library/Caches/com.apple.Safari"
if [ -d "$SAFARI_CACHE_PATH" ]; then
    SAFARI_CACHE_SIZE=$(calculate_size "$SAFARI_CACHE_PATH")
    echo -e "Safari Cache size: ${BOLD}$SAFARI_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Safari cache?"; then
        echo "Clearing Safari Cache..."
        rm -rf "$SAFARI_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Safari cache cleared.${NC}"
    else
        echo "Skipping Safari cache."
    fi
fi

# Chrome Cache
CHROME_CACHE_PATH="/Users/$(whoami)/Library/Caches/Google/Chrome"
if [ -d "$CHROME_CACHE_PATH" ]; then
    CHROME_CACHE_SIZE=$(calculate_size "$CHROME_CACHE_PATH")
    echo -e "Chrome Cache size: ${BOLD}$CHROME_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Chrome cache?"; then
        echo "Clearing Chrome Cache..."
        rm -rf "$CHROME_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Chrome cache cleared.${NC}"
    else
        echo "Skipping Chrome cache."
    fi
fi

# Firefox Cache
FIREFOX_CACHE_PATH="/Users/$(whoami)/Library/Caches/Firefox"
if [ -d "$FIREFOX_CACHE_PATH" ]; then
    FIREFOX_CACHE_SIZE=$(calculate_size "$FIREFOX_CACHE_PATH")
    echo -e "Firefox Cache size: ${BOLD}$FIREFOX_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Firefox cache?"; then
        echo "Clearing Firefox Cache..."
        rm -rf "$FIREFOX_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Firefox cache cleared.${NC}"
    else
        echo "Skipping Firefox cache."
    fi
fi

echo ""

# 5. Clear Log Files
print_section "5. Clearing Log Files"
SYSTEM_LOGS_SIZE=$(calculate_size "/Library/Logs/")
USER_LOGS_SIZE=$(calculate_size "/Users/$(whoami)/Library/Logs/")
echo -e "System Logs size: ${BOLD}$SYSTEM_LOGS_SIZE${NC}"
echo -e "User Logs size: ${BOLD}$USER_LOGS_SIZE${NC}"

if confirm "Do you want to clear log files?"; then
    echo "Clearing System Log files..."
    rm -rf /Library/Logs/* 2>/dev/null
    echo "Clearing User Log files..."
    rm -rf /Users/$(whoami)/Library/Logs/* 2>/dev/null
    echo -e "${GREEN}Log files cleared.${NC}"
else
    echo "Skipping log files."
fi

echo ""

# 6. Clear Temporary Files
print_section "6. Clearing Temporary Files"
TEMP_SIZE=$(calculate_size "/private/var/tmp/")
echo -e "Temporary files size: ${BOLD}$TEMP_SIZE${NC}"

if confirm "Do you want to clear temporary files?"; then
    echo "Clearing Temporary files..."
    rm -rf /private/var/tmp/* 2>/dev/null
    rm -rf /tmp/* 2>/dev/null
    echo -e "${GREEN}Temporary files cleared.${NC}"
else
    echo "Skipping temporary files."
fi

echo ""

# 7. Clear iOS Device Backups
print_section "7. Clearing iOS Device Backups"
IOS_BACKUP_PATH="/Users/$(whoami)/Library/Application Support/MobileSync/Backup"
if [ -d "$IOS_BACKUP_PATH" ]; then
    IOS_BACKUP_SIZE=$(calculate_size "$IOS_BACKUP_PATH")
    echo -e "iOS Backups size: ${BOLD}$IOS_BACKUP_SIZE${NC}"
    
    if confirm "Do you want to clear iOS device backups? (Warning: This will delete iPhone/iPad backups)"; then
        echo "Clearing iOS device backups..."
        rm -rf "$IOS_BACKUP_PATH"/* 2>/dev/null
        echo -e "${GREEN}iOS device backups cleared.${NC}"
    else
        echo "Skipping iOS device backups."
    fi
else
    echo "No iOS device backups found."
fi

echo ""

# 8. Empty Trash
print_section "8. Empty Trash"
if confirm "Do you want to empty the Trash?"; then
    echo "Emptying Trash..."
    rm -rf /Users/$(whoami)/.Trash/* 2>/dev/null
    echo -e "${GREEN}Trash emptied.${NC}"
else
    echo "Skipping emptying Trash."
fi

echo ""

# 9. Run macOS maintenance scripts
print_section "9. Running macOS Maintenance Scripts"
if confirm "Do you want to run macOS maintenance scripts?"; then
    echo "Running maintenance scripts..."
    sudo /usr/libexec/periodic/daily
    sudo /usr/libexec/periodic/weekly
    sudo /usr/libexec/periodic/monthly
    
    echo -e "${GREEN}Maintenance scripts completed.${NC}"
else
    echo "Skipping maintenance scripts."
fi

echo ""

# 10. Purge inactive memory (requires sudo)
print_section "10. Purging Inactive Memory"
if confirm "Do you want to purge inactive memory?"; then
    echo "Purging inactive memory..."
    purge
    echo -e "${GREEN}Inactive memory purged.${NC}"
else
    echo "Skipping memory purge."
fi

echo ""

# 11. Homebrew cleanup and update
print_section "11. Homebrew Cleanup and Update"
if command -v brew &> /dev/null; then
    BREW_CLEANUP_SIZE=$(brew cleanup -n | grep -i "would free" | awk '{print $4$5}')
    if [ -z "$BREW_CLEANUP_SIZE" ]; then
        BREW_CLEANUP_SIZE="unknown"
    fi
    echo -e "Potential Homebrew cleanup size: ${BOLD}$BREW_CLEANUP_SIZE${NC}"
    
    if confirm "Do you want to update and clean Homebrew packages?"; then
        echo "Updating Homebrew..."
        brew update
        
        echo "Upgrading Homebrew packages..."
        brew upgrade
        
        echo "Cleaning up Homebrew cache and old versions..."
        brew cleanup
        
        echo -e "${GREEN}Homebrew packages updated and cleaned.${NC}"
    else
        echo "Skipping Homebrew update and cleanup."
    fi
else
    echo -e "${YELLOW}Homebrew is not installed on this system.${NC}"
fi

echo ""

# Show final space information
print_section "Results"
SPACE_AFTER=$(df -h / | grep -v Filesystem | awk '{print $4}')
echo -e "${BLUE}Space before cleaning: ${BOLD}$SPACE_BEFORE${NC}"
echo -e "${GREEN}Space after cleaning: ${BOLD}$SPACE_AFTER${NC}"

if [ "$SPACE_BEFORE" != "$SPACE_AFTER" ]; then
    echo -e "${BOLD}${GREEN}Cleanup successfully freed up space on your Mac!${NC}"
else
    echo -e "${YELLOW}No significant space was freed up. Your Mac might need more specific cleanup methods.${NC}"
    echo -e "Consider using Disk Utility to analyze your storage further or check large applications manually."
fi

echo ""
echo -e "${BOLD}${BLUE}Cleanup process completed. Thank you for using the MacBook Storage Cleanup Script.${NC}"
echo ""

# Recommendations
print_section "Additional Recommendations"
echo "1. Use Disk Utility's First Aid to check for and repair disk issues."
echo "2. Restart your Mac to ensure all changes take effect."
echo "3. Consider using Safe Mode (boot holding Shift key) occasionally to clear additional system caches."
echo "4. Check your Applications folder for large apps you no longer use."
echo "5. Use 'About This Mac > Storage > Manage' for more storage management options."
echo ""

exit 0
