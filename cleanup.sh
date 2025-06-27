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
echo -e "${RED}${BOLD}IMPORTANT SAFETY NOTICE:${NC}"
echo -e "${YELLOW}• Create a backup of your important data before proceeding${NC}"
echo -e "${YELLOW}• Some operations may require applications to be restarted${NC}"
echo -e "${YELLOW}• Review each operation carefully before confirming${NC}"
echo -e "${YELLOW}• When in doubt, skip the operation${NC}"
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

# Function to get double confirmation for dangerous operations
double_confirm() {
    echo -e "${RED}${BOLD}DANGEROUS OPERATION WARNING${NC}"
    echo -e "${RED}$1${NC}"
    echo -e "${YELLOW}This operation may affect system functionality or cause data loss.${NC}"
    read -p "$(echo -e "${RED}Type 'YES' (all caps) to confirm: ${NC}")" response
    if [ "$response" = "YES" ]; then
        return 0
    else
        echo -e "${GREEN}Operation cancelled for safety.${NC}"
        return 1
    fi
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
    
    if double_confirm "You are about to delete ALL Time Machine local snapshots. This will remove your ability to restore recent changes from local snapshots."; then
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

echo -e "${YELLOW}Note: Clearing system caches may cause apps to start slower initially.${NC}"
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

echo -e "${YELLOW}Note: Clearing user caches may reset app preferences and login states.${NC}"
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
FIREFOX_PROFILES_PATH="/Users/$(whoami)/Library/Caches/Firefox/Profiles"
if [ -d "$FIREFOX_CACHE_PATH" ]; then
    FIREFOX_CACHE_SIZE=$(calculate_size "$FIREFOX_CACHE_PATH")
    echo -e "Firefox Cache size: ${BOLD}$FIREFOX_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Firefox cache?"; then
        echo "Clearing Firefox Cache..."
        rm -rf "$FIREFOX_CACHE_PATH"/* 2>/dev/null
        
        # Also clear profile caches
        if [ -d "$FIREFOX_PROFILES_PATH" ]; then
            find "$FIREFOX_PROFILES_PATH" -name "cache2" -type d -exec rm -rf {} + 2>/dev/null
        fi
        
        echo -e "${GREEN}Firefox cache cleared.${NC}"
    else
        echo "Skipping Firefox cache."
    fi
fi

# Edge Cache
EDGE_CACHE_PATH="/Users/$(whoami)/Library/Caches/com.microsoft.edgemac"
if [ -d "$EDGE_CACHE_PATH" ]; then
    EDGE_CACHE_SIZE=$(calculate_size "$EDGE_CACHE_PATH")
    echo -e "Microsoft Edge Cache size: ${BOLD}$EDGE_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Microsoft Edge cache?"; then
        echo "Clearing Microsoft Edge Cache..."
        rm -rf "$EDGE_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Microsoft Edge cache cleared.${NC}"
    else
        echo "Skipping Microsoft Edge cache."
    fi
fi

# Opera Cache
OPERA_CACHE_PATH="/Users/$(whoami)/Library/Caches/com.operasoftware.Opera"
if [ -d "$OPERA_CACHE_PATH" ]; then
    OPERA_CACHE_SIZE=$(calculate_size "$OPERA_CACHE_PATH")
    echo -e "Opera Cache size: ${BOLD}$OPERA_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Opera cache?"; then
        echo "Clearing Opera Cache..."
        rm -rf "$OPERA_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Opera cache cleared.${NC}"
    else
        echo "Skipping Opera cache."
    fi
fi

# Brave Cache
BRAVE_CACHE_PATH="/Users/$(whoami)/Library/Caches/BraveSoftware/Brave-Browser"
if [ -d "$BRAVE_CACHE_PATH" ]; then
    BRAVE_CACHE_SIZE=$(calculate_size "$BRAVE_CACHE_PATH")
    echo -e "Brave Browser Cache size: ${BOLD}$BRAVE_CACHE_SIZE${NC}"
    
    if confirm "Do you want to clear Brave Browser cache?"; then
        echo "Clearing Brave Browser Cache..."
        rm -rf "$BRAVE_CACHE_PATH"/* 2>/dev/null
        echo -e "${GREEN}Brave Browser cache cleared.${NC}"
    else
        echo "Skipping Brave Browser cache."
    fi
fi

echo ""

# 5. Clear Log Files
print_section "5. Clearing Log Files"
SYSTEM_LOGS_SIZE=$(calculate_size "/Library/Logs/")
USER_LOGS_SIZE=$(calculate_size "/Users/$(whoami)/Library/Logs/")
echo -e "System Logs size: ${BOLD}$SYSTEM_LOGS_SIZE${NC}"
echo -e "User Logs size: ${BOLD}$USER_LOGS_SIZE${NC}"

echo -e "${YELLOW}Note: Log files may be needed for troubleshooting system issues.${NC}"
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
USER_TEMP_SIZE=$(calculate_size "/private/var/folders/")
echo -e "System temporary files size: ${BOLD}$TEMP_SIZE${NC}"
echo -e "User temporary folders size: ${BOLD}$USER_TEMP_SIZE${NC}"

if confirm "Do you want to clear temporary files?"; then
    echo "Clearing system temporary files..."
    rm -rf /private/var/tmp/* 2>/dev/null
    rm -rf /tmp/* 2>/dev/null
    
    echo "Clearing user-specific temporary files..."
    # Clean user temp folders safely
    find /private/var/folders -name "T" -type d 2>/dev/null | while read -r tempdir; do
        if [ -d "$tempdir" ] && [ -w "$tempdir" ]; then
            echo "Cleaning $(dirname "$tempdir")/T"
            rm -rf "$tempdir"/* 2>/dev/null
        fi
    done
    
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
    
    if double_confirm "You are about to delete ALL iOS device backups stored locally. You will lose the ability to restore your iPhone/iPad from these backups."; then
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
    
    # Modern alternative to periodic scripts
    echo "Rebuilding Launch Services database..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    
    echo "Rebuilding dyld cache..."
    sudo update_dyld_shared_cache -force
    
    echo "Updating locate database..."
    sudo /usr/libexec/locate.updatedb
    
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

# 11. Purgeable Space Recovery
print_section "11. Purgeable Space Recovery"
echo -e "${YELLOW}Note: This will attempt to reclaim purgeable space by creating temporary large files.${NC}"
echo -e "${YELLOW}This process may take several minutes and requires monitoring disk space.${NC}"

if confirm "Do you want to attempt purgeable space recovery?"; then
    echo "Checking available disk space..."
    AVAILABLE_SPACE_GB=$(df -g / | grep -v Filesystem | awk '{print $4}')
    
    if [ "$AVAILABLE_SPACE_GB" -gt 5 ]; then
        echo "Creating temporary large files to trigger purgeable space cleanup..."
        mkdir -p ~/temp_cleanup_purgeable 2>/dev/null
        
        # Create files totaling about 2GB or half available space, whichever is smaller
        FILE_SIZE_GB=$((AVAILABLE_SPACE_GB / 2))
        if [ "$FILE_SIZE_GB" -gt 2 ]; then
            FILE_SIZE_GB=2
        fi
        
        echo "Creating ${FILE_SIZE_GB}GB temporary file..."
        dd if=/dev/zero of=~/temp_cleanup_purgeable/bigfile bs=1024m count=$FILE_SIZE_GB 2>/dev/null
        
        # Wait a moment for system to process
        sleep 5
        
        echo "Removing temporary files..."
        rm -rf ~/temp_cleanup_purgeable
        
        echo "Running system purge command..."
        purge
        
        echo -e "${GREEN}Purgeable space recovery completed.${NC}"
    else
        echo -e "${RED}Insufficient disk space for safe purgeable space recovery. Skipping.${NC}"
    fi
else
    echo "Skipping purgeable space recovery."
fi

echo ""

# 12. Docker Cleanup
print_section "12. Docker Cleanup"
if command -v docker &> /dev/null; then
    echo "Docker installation detected. Checking Docker disk usage..."
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        DOCKER_SYSTEM_SIZE=$(docker system df --format "table {{.Size}}" 2>/dev/null | tail -n +2 | head -1)
        if [ -z "$DOCKER_SYSTEM_SIZE" ]; then
            DOCKER_SYSTEM_SIZE="unknown"
        fi
        echo -e "Docker system usage: ${BOLD}$DOCKER_SYSTEM_SIZE${NC}"
        
        if confirm "Do you want to clean up Docker containers, images, and cache?"; then
            echo "Cleaning up Docker containers..."
            docker container prune -f 2>/dev/null
            
            echo "Cleaning up Docker images..."
            docker image prune -a -f 2>/dev/null
            
            echo "Cleaning up Docker volumes..."
            docker volume prune -f 2>/dev/null
            
            echo "Cleaning up Docker networks..."
            docker network prune -f 2>/dev/null
            
            echo "Cleaning up Docker build cache..."
            docker builder prune -a -f 2>/dev/null
            
            echo -e "${GREEN}Docker cleanup completed.${NC}"
        else
            echo "Skipping Docker cleanup."
        fi
    else
        echo -e "${YELLOW}Docker daemon is not running. Skipping Docker cleanup.${NC}"
    fi
else
    echo -e "${YELLOW}Docker is not installed on this system.${NC}"
fi

echo ""

# 13. Xcode and Developer Tools Cleanup
print_section "13. Xcode and Developer Tools Cleanup"
XCODE_PATH="$HOME/Library/Developer/Xcode"

if [ -d "$XCODE_PATH" ]; then
    echo "Xcode installation detected. Checking developer data sizes..."
    
    # Check DerivedData
    DERIVED_DATA_PATH="$XCODE_PATH/DerivedData"
    if [ -d "$DERIVED_DATA_PATH" ]; then
        DERIVED_DATA_SIZE=$(calculate_size "$DERIVED_DATA_PATH")
        echo -e "Xcode DerivedData size: ${BOLD}$DERIVED_DATA_SIZE${NC}"
    fi
    
    # Check iOS DeviceSupport
    DEVICE_SUPPORT_PATH="$XCODE_PATH/iOS DeviceSupport"
    if [ -d "$DEVICE_SUPPORT_PATH" ]; then
        DEVICE_SUPPORT_SIZE=$(calculate_size "$DEVICE_SUPPORT_PATH")
        echo -e "iOS DeviceSupport size: ${BOLD}$DEVICE_SUPPORT_SIZE${NC}"
    fi
    
    # Check Archives
    ARCHIVES_PATH="$XCODE_PATH/Archives"
    if [ -d "$ARCHIVES_PATH" ]; then
        ARCHIVES_SIZE=$(calculate_size "$ARCHIVES_PATH")
        echo -e "Xcode Archives size: ${BOLD}$ARCHIVES_SIZE${NC}"
    fi
    
    if confirm "Do you want to clean Xcode derived data and caches?"; then
        if [ -d "$DERIVED_DATA_PATH" ]; then
            echo "Cleaning Xcode DerivedData..."
            rm -rf "$DERIVED_DATA_PATH"/* 2>/dev/null
        fi
        
        if [ -d "$DEVICE_SUPPORT_PATH" ]; then
            echo "Cleaning iOS DeviceSupport files..."
            rm -rf "$DEVICE_SUPPORT_PATH"/* 2>/dev/null
        fi
        
        # Clean simulator data
        if command -v xcrun &> /dev/null; then
            if double_confirm "This will delete ALL iOS Simulator data and apps. You will lose any simulator data."; then
                echo "Cleaning iOS Simulator data..."
                xcrun simctl delete unavailable 2>/dev/null
                xcrun simctl erase all 2>/dev/null
            else
                echo "Skipping iOS Simulator cleanup."
            fi
        fi
        
        echo -e "${GREEN}Xcode cleanup completed.${NC}"
    else
        echo "Skipping Xcode cleanup."
    fi
    
    if [ -d "$ARCHIVES_PATH" ] && double_confirm "You are about to delete ALL Xcode Archives. You will lose the ability to distribute or re-sign previously archived apps."; then
        echo "Cleaning Xcode Archives..."
        rm -rf "$ARCHIVES_PATH"/* 2>/dev/null
        echo -e "${GREEN}Xcode Archives cleaned.${NC}"
    fi
else
    echo -e "${YELLOW}Xcode is not installed on this system.${NC}"
fi

echo ""

# 14. Mail Downloads and Attachments Cleanup
print_section "14. Mail Downloads and Attachments Cleanup"
MAIL_ATTACHMENTS_PATH="$HOME/Library/Mail"

if [ -d "$MAIL_ATTACHMENTS_PATH" ]; then
    echo "Checking Mail app data..."
    
    # Check for Mail attachments
    MAIL_ATTACHMENTS_SIZE="0"
    if find "$MAIL_ATTACHMENTS_PATH" -name "Attachments" -type d 2>/dev/null | head -1 | grep -q .; then
        MAIL_ATTACHMENTS_SIZE=$(find "$MAIL_ATTACHMENTS_PATH" -name "Attachments" -type d -exec du -sh {} + 2>/dev/null | awk '{total+=$1} END {print total "B"}')
        if [ -z "$MAIL_ATTACHMENTS_SIZE" ] || [ "$MAIL_ATTACHMENTS_SIZE" = "0B" ]; then
            MAIL_ATTACHMENTS_SIZE="minimal"
        fi
    fi
    
    echo -e "Mail attachments size: ${BOLD}$MAIL_ATTACHMENTS_SIZE${NC}"
    
    # Check Downloads folder for old files
    DOWNLOADS_PATH="$HOME/Downloads"
    if [ -d "$DOWNLOADS_PATH" ]; then
        OLD_DOWNLOADS_COUNT=$(find "$DOWNLOADS_PATH" -type f -mtime +30 2>/dev/null | wc -l | tr -d ' ')
        echo -e "Downloads older than 30 days: ${BOLD}$OLD_DOWNLOADS_COUNT files${NC}"
    fi
    
    if confirm "Do you want to clean Mail attachments and old downloads?"; then
        # Clean Mail attachments
        find "$MAIL_ATTACHMENTS_PATH" -name "Attachments" -type d 2>/dev/null | while read -r attachdir; do
            if [ -d "$attachdir" ]; then
                echo "Cleaning Mail attachments in $attachdir..."
                rm -rf "$attachdir"/* 2>/dev/null
            fi
        done
        
        # Clean old downloads
        if [ -d "$DOWNLOADS_PATH" ] && [ "$OLD_DOWNLOADS_COUNT" -gt 0 ]; then
            echo "Cleaning downloads older than 30 days..."
            find "$DOWNLOADS_PATH" -type f -mtime +30 -delete 2>/dev/null
        fi
        
        echo -e "${GREEN}Mail and Downloads cleanup completed.${NC}"
    else
        echo "Skipping Mail and Downloads cleanup."
    fi
else
    echo -e "${YELLOW}Mail app data not found.${NC}"
fi

echo ""

# 15. Font Cache and QuickLook Cleanup
print_section "15. Font Cache and QuickLook Cleanup"
echo "Checking system font and preview caches..."

if confirm "Do you want to clear font caches and QuickLook thumbnails?"; then
    echo "Clearing font caches..."
    # Clear font caches
    sudo atsutil databases -remove 2>/dev/null
    sudo atsutil server -shutdown 2>/dev/null
    sudo atsutil server -ping 2>/dev/null
    
    echo "Clearing QuickLook thumbnails..."
    # Clear QuickLook cache
    qlmanage -r cache 2>/dev/null
    
    echo "Clearing DNS cache..."
    # Clear DNS cache
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    
    echo -e "${GREEN}Font cache and QuickLook cleanup completed.${NC}"
else
    echo "Skipping font cache and QuickLook cleanup."
fi

echo ""

# 16. Language Localization Files Cleanup
print_section "16. Language Localization Files Cleanup"
echo -e "${YELLOW}This will remove language files for languages you don't use (keeps English and system language).${NC}"
echo -e "${YELLOW}Warning: This is an advanced operation. Make sure you have backups.${NC}"

echo -e "${RED}${BOLD}ADVANCED OPERATION WARNING${NC}"
echo -e "${RED}Removing language files may cause some applications to malfunction or crash.${NC}"
echo -e "${YELLOW}Make sure you have backups and can reinstall applications if needed.${NC}"
if double_confirm "You are about to remove language localization files from Applications. This may break some apps."; then
    echo "Scanning for localization files in Applications..."
    
    # Get system language
    SYSTEM_LANG=$(defaults read NSGlobalDomain AppleLanguages | sed -n 's/.*"\([^"]*\)".*/\1/p' | head -1)
    echo -e "System language detected: ${BOLD}$SYSTEM_LANG${NC}"
    
    APPS_TO_CLEAN=0
    SPACE_TO_FREE="0"
    
    # Scan Applications folder for .lproj directories
    find /Applications -name "*.lproj" -type d 2>/dev/null | grep -v -E "(en|English|$SYSTEM_LANG)" | head -20 | while read -r lproj_dir; do
        if [ -d "$lproj_dir" ]; then
            LPROJ_SIZE=$(calculate_size "$lproj_dir")
            echo "Found: $(basename "$lproj_dir") in $(dirname "$lproj_dir" | sed 's|.*/||') - $LPROJ_SIZE"
            ((APPS_TO_CLEAN++))
        fi
    done
    
    if confirm "Proceed with removing these language files?"; then
        echo "Removing unused language localization files..."
        find /Applications -name "*.lproj" -type d 2>/dev/null | grep -v -E "(en|English|$SYSTEM_LANG)" | while read -r lproj_dir; do
            if [ -d "$lproj_dir" ]; then
                echo "Removing $(basename "$lproj_dir") from $(dirname "$lproj_dir" | sed 's|.*/||')..."
                rm -rf "$lproj_dir" 2>/dev/null
            fi
        done
        echo -e "${GREEN}Language localization files cleanup completed.${NC}"
    else
        echo "Skipping language files removal."
    fi
else
    echo "Skipping language localization files cleanup."
fi

echo ""

# 17. macOS and App Store Updates Cleanup
print_section "17. macOS and App Store Updates Cleanup"
echo "Checking for downloaded but not installed updates..."

UPDATES_PATHS=(
    "/Library/Updates"
    "/System/Library/Updates"  
    "$HOME/Library/Caches/com.apple.appstore"
    "$HOME/Library/Caches/com.apple.SoftwareUpdate"
)

TOTAL_UPDATE_SIZE="0"
for update_path in "${UPDATES_PATHS[@]}"; do
    if [ -d "$update_path" ]; then
        UPDATE_SIZE=$(calculate_size "$update_path")
        echo -e "$update_path: ${BOLD}$UPDATE_SIZE${NC}"
    fi
done

if confirm "Do you want to clear downloaded macOS and App Store updates?"; then
    echo "Clearing update caches and downloads..."
    
    for update_path in "${UPDATES_PATHS[@]}"; do
        if [ -d "$update_path" ]; then
            echo "Cleaning $update_path..."
            rm -rf "$update_path"/* 2>/dev/null
        fi
    done
    
    # Clear Software Update cache
    sudo softwareupdate --clear-catalog 2>/dev/null
    
    echo -e "${GREEN}macOS and App Store updates cleanup completed.${NC}"
else
    echo "Skipping macOS and App Store updates cleanup."
fi

echo ""

# 18. Virtual Machine Images Cleanup
print_section "18. Virtual Machine Images Cleanup"
echo "Checking for virtual machine installations and images..."

VM_TOOLS=(
    "Parallels Desktop"
    "VMware Fusion" 
    "VirtualBox"
    "UTM"
)

VM_PATHS=(
    "$HOME/Parallels"
    "$HOME/Documents/Parallels"
    "$HOME/Virtual Machines.localized"
    "$HOME/Documents/Virtual Machines.localized"
    "$HOME/VirtualBox VMs"
    "$HOME/Library/Containers/com.utmapp.UTM"
)

FOUND_VMS=false
for vm_path in "${VM_PATHS[@]}"; do
    if [ -d "$vm_path" ]; then
        VM_SIZE=$(calculate_size "$vm_path")
        echo -e "Found VMs in $vm_path: ${BOLD}$VM_SIZE${NC}"
        FOUND_VMS=true
    fi
done

if [ "$FOUND_VMS" = true ]; then
    echo -e "${YELLOW}Warning: This will show you VM directories but won't auto-delete them.${NC}"
    echo -e "${YELLOW}You should manually review and delete unused VMs from their respective applications.${NC}"
    
    if confirm "Do you want to see detailed VM information?"; then
        for vm_path in "${VM_PATHS[@]}"; do
            if [ -d "$vm_path" ]; then
                echo -e "\n${CYAN}Contents of $vm_path:${NC}"
                ls -la "$vm_path" 2>/dev/null | head -10
            fi
        done
        
        echo -e "\n${YELLOW}To safely remove VMs:${NC}"
        echo "- Parallels: Use Parallels Desktop Control Center"
        echo "- VMware: Use VMware Fusion Library"
        echo "- VirtualBox: Use VirtualBox Manager"
        echo "- UTM: Use UTM application"
    fi
else
    echo -e "${GREEN}No virtual machine directories found.${NC}"
fi

echo ""

# 19. Professional Applications Cache Cleanup
print_section "19. Professional Applications Cache Cleanup"
echo "Checking for professional application caches..."

PROFESSIONAL_APPS=(
    "Adobe After Effects:$HOME/Library/Caches/com.adobe.AfterEffects"
    "Adobe Photoshop:$HOME/Library/Caches/com.adobe.Photoshop"
    "Adobe Premiere Pro:$HOME/Library/Caches/com.adobe.PremierePro"
    "Final Cut Pro:$HOME/Library/Caches/com.apple.FinalCut"
    "Logic Pro:$HOME/Library/Caches/com.apple.logic10"
    "Sketch:$HOME/Library/Caches/com.bohemiancoding.sketch3"
    "Figma:$HOME/Library/Caches/com.figma.Desktop"
    "Cinema 4D:$HOME/Library/Caches/net.maxon.cinema4d"
    "Unity Hub:$HOME/Library/Caches/com.unity3d.UnityHub"
    "Blender:$HOME/Library/Caches/org.blenderfoundation.blender"
)

FOUND_PROFESSIONAL_CACHES=false
TOTAL_PROFESSIONAL_SIZE=0

for app_info in "${PROFESSIONAL_APPS[@]}"; do
    APP_NAME="${app_info%:*}"
    CACHE_PATH="${app_info#*:}"
    
    if [ -d "$CACHE_PATH" ]; then
        CACHE_SIZE=$(calculate_size "$CACHE_PATH")
        echo -e "$APP_NAME cache: ${BOLD}$CACHE_SIZE${NC}"
        FOUND_PROFESSIONAL_CACHES=true
    fi
done

# Check for additional professional app patterns
ADDITIONAL_PATHS=(
    "$HOME/Library/Caches/com.adobe.*"
    "$HOME/Library/Caches/com.apple.FinalCut*"
    "$HOME/Library/Caches/com.apple.motion*"
    "$HOME/Library/Caches/com.apple.logic*"
    "$HOME/Library/Caches/com.apple.compressor*"
)

if [ "$FOUND_PROFESSIONAL_CACHES" = true ]; then
    if confirm "Do you want to clear professional application caches?"; then
        echo "Clearing professional application caches..."
        
        for app_info in "${PROFESSIONAL_APPS[@]}"; do
            CACHE_PATH="${app_info#*:}"
            APP_NAME="${app_info%:*}"
            
            if [ -d "$CACHE_PATH" ]; then
                echo "Clearing $APP_NAME cache..."
                rm -rf "$CACHE_PATH"/* 2>/dev/null
            fi
        done
        
        echo -e "${GREEN}Professional application caches cleared.${NC}"
    else
        echo "Skipping professional application cache cleanup."
    fi
else
    echo -e "${GREEN}No professional application caches found.${NC}"
fi

echo ""

# 20. Hibernation Sleep Image Cleanup
print_section "20. Hibernation Sleep Image Cleanup"
echo "Checking hibernation sleep image file..."

SLEEPIMAGE_PATH="/private/var/vm/sleepimage"
if [ -f "$SLEEPIMAGE_PATH" ]; then
    SLEEPIMAGE_SIZE=$(calculate_size "$SLEEPIMAGE_PATH")
    echo -e "Sleep image file size: ${BOLD}$SLEEPIMAGE_SIZE${NC}"
    echo -e "${YELLOW}Warning: This will disable hibernation mode and remove the sleep image file.${NC}"
    echo -e "${YELLOW}This may affect battery life during sleep on laptops.${NC}"
    
    echo -e "${RED}${BOLD}SYSTEM CONFIGURATION WARNING${NC}"
echo -e "${RED}This will permanently disable hibernation mode on your Mac.${NC}"
echo -e "${YELLOW}On laptops, this may reduce battery life during sleep mode.${NC}"
echo -e "${YELLOW}Your Mac will use more power when sleeping.${NC}"
if double_confirm "You are about to disable hibernation and remove the sleep image file. This affects power management."; then
        echo "Disabling hibernation mode..."
        sudo pmset -a hibernatemode 0
        
        echo "Removing sleep image file..."
        sudo rm -f "$SLEEPIMAGE_PATH"
        
        echo "Creating empty sleep image file to prevent recreation..."
        sudo touch "$SLEEPIMAGE_PATH"
        sudo chflags uchg "$SLEEPIMAGE_PATH"
        
        echo -e "${GREEN}Hibernation disabled and sleep image removed.${NC}"
        echo -e "${CYAN}Note: To re-enable hibernation later, run: sudo pmset -a hibernatemode 3${NC}"
    else
        echo "Skipping hibernation cleanup."
    fi
else
    echo -e "${GREEN}No sleep image file found.${NC}"
fi

echo ""

# 21. Hidden User Folders Cleanup
print_section "21. Hidden User Folders Cleanup"
echo "Checking hidden user folders for temporary files..."
echo -e "${YELLOW}This will clean common hidden cache and temporary directories.${NC}"

HIDDEN_FOLDERS=(
    "$HOME/.cache"
    "$HOME/.npm/_cacache"
    "$HOME/.node-gyp"
    "$HOME/.yarn/cache"
    "$HOME/.gradle/caches"
    "$HOME/.m2/repository"
    "$HOME/.composer/cache"
    "$HOME/.gem/cache"
    "$HOME/.cargo/registry/cache"
    "$HOME/.rustup/downloads"
    "$HOME/.pip/cache"
    "$HOME/.pnpm-store"
    "$HOME/.local/share/Trash"
)

FOUND_HIDDEN=false
for folder in "${HIDDEN_FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        FOLDER_SIZE=$(calculate_size "$folder")
        echo -e "$(basename "$folder"): ${BOLD}$FOLDER_SIZE${NC}"
        FOUND_HIDDEN=true
    fi
done

if [ "$FOUND_HIDDEN" = true ]; then
    if confirm "Do you want to clear these hidden cache folders?"; then
        echo "Clearing hidden user cache folders..."
        
        for folder in "${HIDDEN_FOLDERS[@]}"; do
            if [ -d "$folder" ]; then
                echo "Clearing $(basename "$folder")..."
                # Safer removal - avoid removing critical hidden files
                find "$folder" -name "cache*" -type f -delete 2>/dev/null
                find "$folder" -name "*.tmp" -type f -delete 2>/dev/null
                find "$folder" -name "*.log" -type f -delete 2>/dev/null
                # Only remove contents, not the folder structure
                find "$folder" -type f -mtime +7 -delete 2>/dev/null
            fi
        done
        
        echo -e "${GREEN}Hidden user folders cleanup completed.${NC}"
    else
        echo "Skipping hidden folders cleanup."
    fi
else
    echo -e "${GREEN}No significant hidden cache folders found.${NC}"
fi

echo ""

# 22. Homebrew cleanup and update
print_section "22. Homebrew Cleanup and Update"
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
echo -e "${CYAN}Post-Cleanup Actions:${NC}"
echo "1. Restart your Mac to ensure all changes take effect"
echo "2. Check app functionality - some apps may need to be relaunched"
echo "3. Run Disk Utility's First Aid to check for disk issues"
echo ""
echo -e "${CYAN}Ongoing Maintenance:${NC}"
echo "4. Create regular backups using Time Machine or other backup solutions"
echo "5. Monitor storage using 'About This Mac > Storage > Manage'"
echo "6. Consider running this script monthly for maintenance"
echo "7. Use Safe Mode occasionally (boot holding Shift) for deeper cleanup"
echo ""
echo -e "${CYAN}Recovery Information:${NC}"
echo "8. If apps misbehave after cleanup, try logging out and back in"
echo "9. To restore hibernation: sudo pmset -a hibernatemode 3"
echo "10. Reinstall apps if language file removal causes issues"
echo ""

exit 0
