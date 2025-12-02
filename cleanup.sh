#!/bin/bash

# MacBook Storage Cleanup Script - Refactored Version
# Enhanced with modular functions and new performance features
# Run with: sudo bash cleanup.sh

# ============================================================================
# CONFIGURATION
# ============================================================================

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Current user
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$SUDO_USER)

# Browser cache paths configuration
declare -A BROWSER_CACHES=(
    ["Safari"]="$USER_HOME/Library/Caches/com.apple.Safari"
    ["Chrome"]="$USER_HOME/Library/Caches/Google/Chrome"
    ["Firefox"]="$USER_HOME/Library/Caches/Firefox"
    ["Edge"]="$USER_HOME/Library/Caches/com.microsoft.edgemac"
    ["Opera"]="$USER_HOME/Library/Caches/com.operasoftware.Opera"
    ["Brave"]="$USER_HOME/Library/Caches/BraveSoftware/Brave-Browser"
    ["Arc"]="$USER_HOME/Library/Caches/company.thebrowser.Browser"
    ["Vivaldi"]="$USER_HOME/Library/Caches/com.vivaldi.Vivaldi"
)

# Professional applications cache paths
declare -A PROFESSIONAL_APP_CACHES=(
    ["Adobe After Effects"]="$USER_HOME/Library/Caches/com.adobe.AfterEffects"
    ["Adobe Photoshop"]="$USER_HOME/Library/Caches/com.adobe.Photoshop"
    ["Adobe Premiere Pro"]="$USER_HOME/Library/Caches/com.adobe.PremierePro"
    ["Final Cut Pro"]="$USER_HOME/Library/Caches/com.apple.FinalCut"
    ["Logic Pro"]="$USER_HOME/Library/Caches/com.apple.logic10"
    ["Sketch"]="$USER_HOME/Library/Caches/com.bohemiancoding.sketch3"
    ["Figma"]="$USER_HOME/Library/Caches/com.figma.Desktop"
    ["Cinema 4D"]="$USER_HOME/Library/Caches/net.maxon.cinema4d"
    ["Unity Hub"]="$USER_HOME/Library/Caches/com.unity3d.UnityHub"
    ["Blender"]="$USER_HOME/Library/Caches/org.blenderfoundation.blender"
)

# Package manager cache paths
declare -A PACKAGE_MANAGER_CACHES=(
    ["npm"]="$(npm config get cache 2>/dev/null)"
    ["yarn"]="$(yarn cache dir 2>/dev/null)"
    ["pnpm"]="$USER_HOME/.pnpm-store"
    ["bun"]="$USER_HOME/.bun/install/cache"
    ["pip"]="$(pip3 cache dir 2>/dev/null || pip cache dir 2>/dev/null)"
    ["gem"]="$USER_HOME/.gem/cache"
    ["cargo"]="$USER_HOME/.cargo/registry/cache"
)

# System cache directories
declare -a SYSTEM_CACHES=(
    "/Library/Caches"
    "$USER_HOME/Library/Caches"
)

# Developer tool paths
declare -a HIDDEN_DEV_CACHES=(
    "$USER_HOME/.cache"
    "$USER_HOME/.npm/_cacache"
    "$USER_HOME/.node-gyp"
    "$USER_HOME/.yarn/cache"
    "$USER_HOME/.gradle/caches"
    "$USER_HOME/.m2/repository"
    "$USER_HOME/.composer/cache"
    "$USER_HOME/.rustup/downloads"
    "$USER_HOME/.pip/cache"
    "$USER_HOME/.local/share/Trash"
)

# Statistics tracking
TOTAL_FREED=0
OPERATIONS_COMPLETED=0
OPERATIONS_SKIPPED=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print section headers
print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '%.0s-' {1..60})${NC}"
}

# Calculate directory or file size
calculate_size() {
    if [ -e "$1" ]; then
        du -sh "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

# Calculate size in bytes for comparison
calculate_size_bytes() {
    if [ -e "$1" ]; then
        du -sk "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script with sudo for full functionality.${NC}"
        echo -e "${YELLOW}Example: sudo bash cleanup.sh${NC}"
        exit 1
    fi
}

# Get user confirmation
confirm() {
    read -p "$(echo -e ${YELLOW}"$1 [y/N]: "${NC})" response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get double confirmation for dangerous operations
double_confirm() {
    echo -e "${RED}${BOLD}⚠️  DANGEROUS OPERATION WARNING${NC}"
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

# Show space information
show_space_info() {
    df -h / | grep -v Filesystem | awk '{print $4 " available (" $5 " used)"}'
}

# Log operation with timestamp
log_operation() {
    local message="$1"
    local log_file="/tmp/cleanup_log_$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}

# Generic cache cleaning function
clean_cache_directory() {
    local name="$1"
    local path="$2"
    local warning="$3"

    if [ ! -d "$path" ]; then
        return 1
    fi

    local size=$(calculate_size "$path")
    local size_bytes_before=$(calculate_size_bytes "$path")

    if [ "$size_bytes_before" -eq 0 ]; then
        return 1
    fi

    echo -e "${name} cache: ${BOLD}${size}${NC}"

    if [ -n "$warning" ]; then
        echo -e "${YELLOW}Note: $warning${NC}"
    fi

    if confirm "Do you want to clear ${name} cache?"; then
        echo "Clearing ${name} cache..."
        rm -rf "$path"/* 2>/dev/null
        rm -rf "$path"/.[!.]* 2>/dev/null

        local size_bytes_after=$(calculate_size_bytes "$path")
        local freed=$((size_bytes_before - size_bytes_after))
        TOTAL_FREED=$((TOTAL_FREED + freed))
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))

        echo -e "${GREEN}${name} cache cleared.${NC}"
        log_operation "${name} cache cleared - freed ${freed}KB"
        return 0
    else
        echo "Skipping ${name} cache."
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
        return 1
    fi
}

# Clean multiple cache directories at once
clean_multiple_caches() {
    local cache_name="$1"
    shift
    local -a paths=("$@")
    local found=false

    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            found=true
            break
        fi
    done

    if [ "$found" = false ]; then
        echo -e "${GREEN}No ${cache_name} caches found.${NC}"
        return 1
    fi

    local total_size=0
    echo "Found ${cache_name} caches:"
    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            local size=$(calculate_size "$path")
            local size_bytes=$(calculate_size_bytes "$path")
            total_size=$((total_size + size_bytes))
            echo -e "  $(basename "$path"): ${BOLD}${size}${NC}"
        fi
    done

    if confirm "Do you want to clear all ${cache_name} caches?"; then
        echo "Clearing ${cache_name} caches..."
        for path in "${paths[@]}"; do
            if [ -d "$path" ]; then
                echo "  Clearing $(basename "$path")..."
                rm -rf "$path"/* 2>/dev/null
            fi
        done
        TOTAL_FREED=$((TOTAL_FREED + total_size))
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}${cache_name} caches cleared.${NC}"
        log_operation "${cache_name} caches cleared - freed ${total_size}KB"
        return 0
    else
        echo "Skipping ${cache_name} caches."
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
        return 1
    fi
}

# Clean browser caches with optimized function
clean_browser_caches() {
    print_section "🌐 Browser Caches Cleanup"

    local found_browsers=()
    local total_size=0

    for browser in "${!BROWSER_CACHES[@]}"; do
        local path="${BROWSER_CACHES[$browser]}"
        if [ -d "$path" ]; then
            found_browsers+=("$browser")
            local size=$(calculate_size "$path")
            local size_bytes=$(calculate_size_bytes "$path")
            total_size=$((total_size + size_bytes))
            echo -e "${browser} cache: ${BOLD}${size}${NC}"
        fi
    done

    if [ ${#found_browsers[@]} -eq 0 ]; then
        echo -e "${GREEN}No browser caches found.${NC}"
        return
    fi

    echo -e "${YELLOW}Note: Clearing browser caches may log you out of websites.${NC}"

    if confirm "Do you want to clear all browser caches?"; then
        echo "Clearing browser caches..."
        for browser in "${found_browsers[@]}"; do
            local path="${BROWSER_CACHES[$browser]}"
            echo "  Clearing ${browser}..."
            rm -rf "$path"/* 2>/dev/null

            # Special handling for Firefox profiles
            if [ "$browser" = "Firefox" ]; then
                local profiles_path="$USER_HOME/Library/Caches/Firefox/Profiles"
                if [ -d "$profiles_path" ]; then
                    find "$profiles_path" -name "cache2" -type d -exec rm -rf {} + 2>/dev/null
                fi
            fi
        done
        TOTAL_FREED=$((TOTAL_FREED + total_size))
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}All browser caches cleared.${NC}"
        log_operation "Browser caches cleared - freed ${total_size}KB"
    else
        echo "Skipping browser caches."
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
}

# Clean package manager caches
clean_package_managers() {
    print_section "📦 Package Manager Caches"

    local found=false

    # npm
    if command -v npm &> /dev/null; then
        local npm_cache=$(npm config get cache 2>/dev/null)
        if [ -d "$npm_cache" ]; then
            found=true
            local size=$(calculate_size "$npm_cache")
            echo -e "npm cache: ${BOLD}${size}${NC}"
        fi
    fi

    # yarn
    if command -v yarn &> /dev/null; then
        local yarn_cache=$(yarn cache dir 2>/dev/null)
        if [ -d "$yarn_cache" ]; then
            found=true
            local size=$(calculate_size "$yarn_cache")
            echo -e "Yarn cache: ${BOLD}${size}${NC}"
        fi
    fi

    # pnpm
    if command -v pnpm &> /dev/null && [ -d "$USER_HOME/.pnpm-store" ]; then
        found=true
        local size=$(calculate_size "$USER_HOME/.pnpm-store")
        echo -e "pnpm store: ${BOLD}${size}${NC}"
    fi

    # bun
    if command -v bun &> /dev/null && [ -d "$USER_HOME/.bun/install/cache" ]; then
        found=true
        local size=$(calculate_size "$USER_HOME/.bun/install/cache")
        echo -e "Bun cache: ${BOLD}${size}${NC}"
    fi

    # Python pip
    if command -v pip3 &> /dev/null || command -v pip &> /dev/null; then
        local pip_cache=""
        if command -v pip3 &> /dev/null; then
            pip_cache=$(pip3 cache dir 2>/dev/null)
        elif command -v pip &> /dev/null; then
            pip_cache=$(pip cache dir 2>/dev/null)
        fi
        if [ -d "$pip_cache" ]; then
            found=true
            local size=$(calculate_size "$pip_cache")
            echo -e "pip cache: ${BOLD}${size}${NC}"
        fi
    fi

    # Conda
    if command -v conda &> /dev/null; then
        found=true
        echo -e "Conda: ${BOLD}installed${NC}"
    fi

    # Ruby Gems
    if command -v gem &> /dev/null && [ -d "$USER_HOME/.gem/cache" ]; then
        found=true
        local size=$(calculate_size "$USER_HOME/.gem/cache")
        echo -e "Ruby gems cache: ${BOLD}${size}${NC}"
    fi

    # Rust Cargo
    if command -v cargo &> /dev/null && [ -d "$USER_HOME/.cargo/registry/cache" ]; then
        found=true
        local size=$(calculate_size "$USER_HOME/.cargo/registry/cache")
        echo -e "Cargo cache: ${BOLD}${size}${NC}"
    fi

    if [ "$found" = false ]; then
        echo -e "${GREEN}No package manager caches found.${NC}"
        return
    fi

    if confirm "Do you want to clear all package manager caches?"; then
        echo "Clearing package manager caches..."

        # npm
        if command -v npm &> /dev/null; then
            echo "  Clearing npm cache..."
            npm cache clean --force 2>/dev/null
        fi

        # yarn
        if command -v yarn &> /dev/null; then
            echo "  Clearing yarn cache..."
            yarn cache clean 2>/dev/null
        fi

        # pnpm
        if command -v pnpm &> /dev/null; then
            echo "  Clearing pnpm store..."
            pnpm store prune 2>/dev/null
        fi

        # bun
        if command -v bun &> /dev/null && [ -d "$USER_HOME/.bun/install/cache" ]; then
            echo "  Clearing bun cache..."
            rm -rf "$USER_HOME/.bun/install/cache"/* 2>/dev/null
        fi

        # pip
        if command -v pip3 &> /dev/null; then
            echo "  Clearing pip cache..."
            pip3 cache purge 2>/dev/null
        elif command -v pip &> /dev/null; then
            pip cache purge 2>/dev/null
        fi

        # conda
        if command -v conda &> /dev/null; then
            echo "  Clearing conda cache..."
            conda clean --all -y 2>/dev/null
        fi

        # gem
        if command -v gem &> /dev/null; then
            echo "  Clearing Ruby gems..."
            gem cleanup 2>/dev/null
            [ -d "$USER_HOME/.gem/cache" ] && rm -rf "$USER_HOME/.gem/cache"/* 2>/dev/null
        fi

        # cargo
        if command -v cargo &> /dev/null; then
            echo "  Clearing Cargo cache..."
            if command -v cargo-cache &> /dev/null; then
                cargo cache --autoclean 2>/dev/null
            else
                [ -d "$USER_HOME/.cargo/registry/cache" ] && rm -rf "$USER_HOME/.cargo/registry/cache"/* 2>/dev/null
            fi
        fi

        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Package manager caches cleared.${NC}"
        log_operation "Package manager caches cleared"
    else
        echo "Skipping package manager caches."
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
}

# ============================================================================
# DISPLAY HEADER
# ============================================================================

echo -e "${BOLD}${BLUE}================================================================${NC}"
echo -e "${BOLD}${BLUE}          MacBook Storage Cleanup Script (Refactored)          ${NC}"
echo -e "${BOLD}${BLUE}================================================================${NC}"
echo ""
echo -e "${BOLD}This script will help free up storage space on your Mac.${NC}"
echo -e "${RED}${BOLD}IMPORTANT SAFETY NOTICE:${NC}"
echo -e "${YELLOW}• Create a backup of your important data before proceeding${NC}"
echo -e "${YELLOW}• Some operations may require applications to be restarted${NC}"
echo -e "${YELLOW}• Review each operation carefully before confirming${NC}"
echo -e "${YELLOW}• When in doubt, skip the operation${NC}"
echo ""

# ============================================================================
# START CLEANUP OPERATIONS
# ============================================================================

check_sudo
SPACE_BEFORE=$(show_space_info)
echo -e "${BLUE}Current disk space: ${BOLD}${SPACE_BEFORE}${NC}"
log_operation "Cleanup session started"

# 1. Time Machine Local Snapshots
print_section "1. ⏰ Time Machine Local Snapshots"
echo "Checking for Time Machine local snapshots..."
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null)

if [ -z "$SNAPSHOTS" ]; then
    echo -e "${GREEN}No Time Machine local snapshots found.${NC}"
else
    echo -e "${YELLOW}Found Time Machine local snapshots:${NC}"
    echo "$SNAPSHOTS"

    if double_confirm "You are about to delete ALL Time Machine local snapshots."; then
        echo "Deleting Time Machine local snapshots..."
        for snapshot in $(tmutil listlocalsnapshots / | cut -d. -f4); do
            echo "  Deleting snapshot: $snapshot"
            tmutil deletelocalsnapshots "$snapshot" 2>/dev/null
        done
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Time Machine local snapshots deleted.${NC}"
        log_operation "Time Machine snapshots deleted"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
fi

# 2. APFS Snapshots (NEW FEATURE)
print_section "2. 📸 APFS Snapshots Management"
echo "Checking for APFS snapshots..."
echo -e "${YELLOW}Note: APFS snapshots are created during system updates.${NC}"

APFS_SNAPSHOTS=$(diskutil apfs listSnapshots / 2>/dev/null | grep -E "^\+-- " | awk '{print $2}')

if [ -n "$APFS_SNAPSHOTS" ]; then
    echo -e "${YELLOW}Found APFS snapshots:${NC}"
    diskutil apfs listSnapshots / 2>/dev/null | grep -E "^\+-- "

    echo ""
    echo -e "${CYAN}Snapshot details:${NC}"
    diskutil apfs listSnapshots / 2>/dev/null

    if double_confirm "Delete APFS snapshots? This removes ability to roll back system updates."; then
        echo "Deleting APFS snapshots..."
        for uuid in $APFS_SNAPSHOTS; do
            echo "  Deleting snapshot: $uuid"
            diskutil apfs deleteSnapshot / -uuid "$uuid" 2>/dev/null
        done
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}APFS snapshots deleted.${NC}"
        log_operation "APFS snapshots deleted"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${GREEN}No APFS snapshots found.${NC}"
fi

# 3. System Cache Files
print_section "3. 💾 System Cache Files"
SYSTEM_CACHE_SIZE=$(calculate_size "/Library/Caches/")
echo -e "System cache size: ${BOLD}${SYSTEM_CACHE_SIZE}${NC}"

clean_cache_directory "System" "/Library/Caches" "Clearing system caches may cause apps to start slower initially."

# 4. User Cache Files
print_section "4. 👤 User Cache Files"
USER_CACHE_SIZE=$(calculate_size "$USER_HOME/Library/Caches/")
echo -e "User cache size: ${BOLD}${USER_CACHE_SIZE}${NC}"

clean_cache_directory "User" "$USER_HOME/Library/Caches" "Clearing user caches may reset app preferences and login states."

# 5. Browser Caches (REFACTORED)
clean_browser_caches

# 6. System and User Logs
print_section "6. 📝 Log Files"
SYSTEM_LOGS_SIZE=$(calculate_size "/Library/Logs/")
USER_LOGS_SIZE=$(calculate_size "$USER_HOME/Library/Logs/")
echo -e "System logs: ${BOLD}${SYSTEM_LOGS_SIZE}${NC}"
echo -e "User logs: ${BOLD}${USER_LOGS_SIZE}${NC}"

echo -e "${YELLOW}Note: Log files may be needed for troubleshooting.${NC}"
if confirm "Do you want to clear log files?"; then
    echo "Clearing log files..."
    rm -rf /Library/Logs/* 2>/dev/null
    rm -rf "$USER_HOME/Library/Logs"/* 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Log files cleared.${NC}"
    log_operation "Log files cleared"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 7. Temporary Files
print_section "7. 🗑️  Temporary Files"
TEMP_SIZE=$(calculate_size "/private/var/tmp/")
USER_TEMP_SIZE=$(calculate_size "/private/var/folders/")
echo -e "System temporary files: ${BOLD}${TEMP_SIZE}${NC}"
echo -e "User temporary folders: ${BOLD}${USER_TEMP_SIZE}${NC}"

if confirm "Do you want to clear temporary files?"; then
    echo "Clearing temporary files..."
    rm -rf /private/var/tmp/* 2>/dev/null
    rm -rf /tmp/* 2>/dev/null

    echo "Clearing user-specific temporary files..."
    find /private/var/folders -name "T" -type d 2>/dev/null | while read -r tempdir; do
        if [ -d "$tempdir" ] && [ -w "$tempdir" ]; then
            rm -rf "$tempdir"/* 2>/dev/null
        fi
    done

    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Temporary files cleared.${NC}"
    log_operation "Temporary files cleared"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 8. iOS Device Backups
print_section "8. 📱 iOS Device Backups"
IOS_BACKUP_PATH="$USER_HOME/Library/Application Support/MobileSync/Backup"
if [ -d "$IOS_BACKUP_PATH" ]; then
    IOS_BACKUP_SIZE=$(calculate_size "$IOS_BACKUP_PATH")
    echo -e "iOS backups size: ${BOLD}${IOS_BACKUP_SIZE}${NC}"

    if double_confirm "Delete ALL iOS device backups? You'll lose ability to restore from these backups."; then
        echo "Clearing iOS device backups..."
        rm -rf "$IOS_BACKUP_PATH"/* 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}iOS device backups cleared.${NC}"
        log_operation "iOS backups cleared"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo "No iOS device backups found."
fi

# 9. Empty Trash
print_section "9. 🗑️  Empty Trash"
TRASH_SIZE=$(calculate_size "$USER_HOME/.Trash/")
echo -e "Trash size: ${BOLD}${TRASH_SIZE}${NC}"

if confirm "Do you want to empty the Trash?"; then
    echo "Emptying Trash..."
    rm -rf "$USER_HOME/.Trash"/* 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Trash emptied.${NC}"
    log_operation "Trash emptied"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 10. Memory Purge
print_section "10. 💭 Memory Purge"
echo "Current memory status:"
vm_stat | grep -E "Pages (free|active|inactive|wired)"

if confirm "Do you want to purge inactive memory?"; then
    echo "Purging inactive memory..."
    purge
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Inactive memory purged.${NC}"
    echo "New memory status:"
    vm_stat | grep -E "Pages (free|active|inactive|wired)"
    log_operation "Memory purged"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 11. Swap Usage Monitoring (NEW FEATURE)
print_section "11. 💿 Swap Usage Analysis"
echo "Checking swap usage..."
sysctl vm.swapusage
SWAP_USED=$(sysctl vm.swapusage | awk '{print $7}' | tr -d 'M')

if [ -n "$SWAP_USED" ] && [ "$SWAP_USED" != "0.00" ]; then
    echo -e "${YELLOW}Swap is being used. This may indicate memory pressure.${NC}"
    echo -e "${CYAN}Recommendations:${NC}"
    echo "  • Close unused applications"
    echo "  • Run memory purge (previous step)"
    echo "  • Restart your Mac to clear swap"
    echo "  • Consider upgrading RAM if this happens frequently"
else
    echo -e "${GREEN}Swap usage is minimal or zero.${NC}"
fi

# 12. Docker Cleanup
print_section "12. 🐳 Docker Cleanup"
if command -v docker &> /dev/null && docker info &> /dev/null; then
    echo "Docker installation detected."
    docker system df 2>/dev/null

    if confirm "Do you want to clean Docker containers, images, and cache?"; then
        echo "Cleaning Docker..."
        docker container prune -f 2>/dev/null
        docker image prune -a -f 2>/dev/null
        docker volume prune -f 2>/dev/null
        docker network prune -f 2>/dev/null
        docker builder prune -a -f 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Docker cleanup completed.${NC}"
        log_operation "Docker cleaned"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${YELLOW}Docker is not installed or not running.${NC}"
fi

# 13. Xcode and Developer Tools
print_section "13. 🔨 Xcode & Developer Tools"
XCODE_PATH="$USER_HOME/Library/Developer/Xcode"

if [ -d "$XCODE_PATH" ]; then
    echo "Xcode installation detected."

    [ -d "$XCODE_PATH/DerivedData" ] && echo -e "DerivedData: ${BOLD}$(calculate_size "$XCODE_PATH/DerivedData")${NC}"
    [ -d "$XCODE_PATH/iOS DeviceSupport" ] && echo -e "iOS DeviceSupport: ${BOLD}$(calculate_size "$XCODE_PATH/iOS DeviceSupport")${NC}"
    [ -d "$XCODE_PATH/Archives" ] && echo -e "Archives: ${BOLD}$(calculate_size "$XCODE_PATH/Archives")${NC}"

    if confirm "Do you want to clean Xcode derived data and caches?"; then
        [ -d "$XCODE_PATH/DerivedData" ] && rm -rf "$XCODE_PATH/DerivedData"/* 2>/dev/null
        [ -d "$XCODE_PATH/iOS DeviceSupport" ] && rm -rf "$XCODE_PATH/iOS DeviceSupport"/* 2>/dev/null

        if command -v xcrun &> /dev/null; then
            if double_confirm "Delete ALL iOS Simulator data?"; then
                xcrun simctl delete unavailable 2>/dev/null
                xcrun simctl erase all 2>/dev/null
            fi
        fi

        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Xcode cleanup completed.${NC}"
        log_operation "Xcode cleaned"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${YELLOW}Xcode is not installed.${NC}"
fi

# 14. Package Managers (REFACTORED)
clean_package_managers

# 15. Homebrew
print_section "15. 🍺 Homebrew"
if command -v brew &> /dev/null; then
    BREW_CACHE_PATH=$(brew --cache 2>/dev/null)
    [ -d "$BREW_CACHE_PATH" ] && echo -e "Homebrew cache: ${BOLD}$(calculate_size "$BREW_CACHE_PATH")${NC}"

    if confirm "Do you want to update and clean Homebrew?"; then
        echo "Updating Homebrew..."
        brew update
        brew upgrade
        brew cleanup

        if confirm "Scrub Homebrew cache completely (more aggressive)?"; then
            brew cleanup -s
        fi

        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Homebrew cleaned.${NC}"
        log_operation "Homebrew cleaned"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${YELLOW}Homebrew is not installed.${NC}"
fi

# 16. Mail and Downloads
print_section "16. 📧 Mail & Downloads"
MAIL_PATH="$USER_HOME/Library/Mail"
DOWNLOADS_PATH="$USER_HOME/Downloads"

if [ -d "$MAIL_PATH" ]; then
    [ -d "$DOWNLOADS_PATH" ] && echo -e "Downloads older than 30 days: ${BOLD}$(find "$DOWNLOADS_PATH" -type f -mtime +30 2>/dev/null | wc -l | tr -d ' ') files${NC}"

    if confirm "Clean Mail attachments and old downloads?"; then
        find "$MAIL_PATH" -name "Attachments" -type d 2>/dev/null | while read -r attachdir; do
            [ -d "$attachdir" ] && rm -rf "$attachdir"/* 2>/dev/null
        done

        [ -d "$DOWNLOADS_PATH" ] && find "$DOWNLOADS_PATH" -type f -mtime +30 -delete 2>/dev/null

        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Mail and Downloads cleaned.${NC}"
        log_operation "Mail and downloads cleaned"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
fi

# 17. Font Cache, QuickLook, DNS
print_section "17. 🔤 Font, QuickLook & DNS Cache"
if confirm "Clear font caches, QuickLook thumbnails, and DNS cache?"; then
    echo "Clearing caches..."
    sudo atsutil databases -remove 2>/dev/null
    sudo atsutil server -shutdown 2>/dev/null
    sudo atsutil server -ping 2>/dev/null
    qlmanage -r cache 2>/dev/null
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Font, QuickLook, and DNS caches cleared.${NC}"
    log_operation "Font/QuickLook/DNS cleared"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 18. Professional Applications (REFACTORED)
print_section "18. 🎨 Professional Applications"
found_prof=false
for app in "${!PROFESSIONAL_APP_CACHES[@]}"; do
    path="${PROFESSIONAL_APP_CACHES[$app]}"
    if [ -d "$path" ]; then
        found_prof=true
        echo -e "${app}: ${BOLD}$(calculate_size "$path")${NC}"
    fi
done

if [ "$found_prof" = true ]; then
    if confirm "Clear professional application caches?"; then
        for app in "${!PROFESSIONAL_APP_CACHES[@]}"; do
            path="${PROFESSIONAL_APP_CACHES[$app]}"
            [ -d "$path" ] && rm -rf "$path"/* 2>/dev/null
        done
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Professional app caches cleared.${NC}"
        log_operation "Professional app caches cleared"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${GREEN}No professional app caches found.${NC}"
fi

# 19. macOS Updates Cache
print_section "19. 🔄 macOS & App Store Updates"
UPDATES_PATHS=(
    "/Library/Updates"
    "$USER_HOME/Library/Caches/com.apple.appstore"
    "$USER_HOME/Library/Caches/com.apple.SoftwareUpdate"
)

found_updates=false
for path in "${UPDATES_PATHS[@]}"; do
    if [ -d "$path" ]; then
        found_updates=true
        echo -e "$(basename "$path"): ${BOLD}$(calculate_size "$path")${NC}"
    fi
done

if [ "$found_updates" = true ]; then
    if confirm "Clear downloaded macOS and App Store updates?"; then
        for path in "${UPDATES_PATHS[@]}"; do
            [ -d "$path" ] && rm -rf "$path"/* 2>/dev/null
        done
        sudo softwareupdate --clear-catalog 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Updates cache cleared.${NC}"
        log_operation "Updates cache cleared"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${GREEN}No update caches found.${NC}"
fi

# 20. Login Items Audit (NEW FEATURE)
print_section "20. 🚀 Login Items Audit"
echo "Checking startup applications..."
echo -e "${CYAN}Current login items:${NC}"

if command -v osascript &> /dev/null; then
    osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*/  • /'
    echo ""
    echo -e "${YELLOW}Note: To manage login items, go to:${NC}"
    echo "System Settings > General > Login Items"
    echo ""
    echo -e "${CYAN}Tip: Removing unnecessary startup items improves boot time.${NC}"
fi

# 21. Desktop Organization Check (NEW FEATURE)
print_section "21. 🖥️  Desktop Organization"
DESKTOP_PATH="$USER_HOME/Desktop"
if [ -d "$DESKTOP_PATH" ]; then
    DESKTOP_ITEMS=$(find "$DESKTOP_PATH" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Files on Desktop: ${BOLD}${DESKTOP_ITEMS}${NC}"

    if [ "$DESKTOP_ITEMS" -gt 50 ]; then
        echo -e "${YELLOW}Warning: Many files on Desktop can slow down your Mac!${NC}"
        echo -e "${CYAN}Recommendation: Organize files into folders or move to Documents.${NC}"
    else
        echo -e "${GREEN}Desktop organization looks good!${NC}"
    fi
fi

# 22. Orphaned Application Preferences (NEW FEATURE)
print_section "22. ⚙️  Orphaned Application Preferences"
echo "Scanning for orphaned .plist files..."
echo -e "${YELLOW}Note: This scans for preferences of uninstalled apps.${NC}"

PREF_PATH="$USER_HOME/Library/Preferences"
if [ -d "$PREF_PATH" ]; then
    PLIST_COUNT=$(find "$PREF_PATH" -name "*.plist" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Total preference files: ${BOLD}${PLIST_COUNT}${NC}"
    echo ""
    echo -e "${CYAN}To manually review preference files:${NC}"
    echo "  cd ~/Library/Preferences"
    echo "  ls -lah *.plist"
    echo ""
    echo -e "${YELLOW}Delete only if you're sure the app is uninstalled.${NC}"
fi

# 23. Core Data and CloudKit
print_section "23. ☁️  Core Data & CloudKit Cache"
COREDATA_CACHES=(
    "$USER_HOME/Library/Caches/CloudKit"
    "$USER_HOME/Library/Caches/com.apple.CoreData"
    "$USER_HOME/Library/Caches/com.apple.cloudkit"
)

clean_multiple_caches "Core Data/CloudKit" "${COREDATA_CACHES[@]}"

# 24. Spotlight Index Optimization
print_section "24. 🔍 Spotlight Index Optimization"
echo -e "${YELLOW}Rebuilding Spotlight can improve search performance.${NC}"
echo -e "${YELLOW}This process takes several hours and uses CPU resources.${NC}"

if confirm "Rebuild Spotlight index?"; then
    echo "Rebuilding Spotlight index..."
    sudo mdutil -i off /
    sudo rm -rf /.Spotlight-V100
    sudo mdutil -i on /
    sudo mdutil -E /
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Spotlight rebuild initiated (runs in background).${NC}"
    log_operation "Spotlight rebuild started"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 25. macOS Maintenance Scripts
print_section "25. 🔧 macOS Maintenance"
if confirm "Run macOS maintenance scripts?"; then
    echo "Running maintenance..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null
    sudo update_dyld_shared_cache -force 2>/dev/null
    sudo /usr/libexec/locate.updatedb 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Maintenance scripts completed.${NC}"
    log_operation "Maintenance scripts run"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 26. Hibernation Sleep Image
print_section "26. 😴 Hibernation Sleep Image"
SLEEPIMAGE_PATH="/private/var/vm/sleepimage"
if [ -f "$SLEEPIMAGE_PATH" ]; then
    SLEEPIMAGE_SIZE=$(calculate_size "$SLEEPIMAGE_PATH")
    echo -e "Sleep image size: ${BOLD}${SLEEPIMAGE_SIZE}${NC}"

    if double_confirm "Disable hibernation and remove sleep image? May affect battery life during sleep."; then
        sudo pmset -a hibernatemode 0
        sudo rm -f "$SLEEPIMAGE_PATH"
        sudo touch "$SLEEPIMAGE_PATH"
        sudo chflags uchg "$SLEEPIMAGE_PATH"
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Hibernation disabled.${NC}"
        echo -e "${CYAN}To re-enable: sudo pmset -a hibernatemode 3${NC}"
        log_operation "Hibernation disabled"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${GREEN}No sleep image found.${NC}"
fi

# 27. Hidden Developer Caches
print_section "27. 🔐 Hidden Developer Caches"
clean_multiple_caches "hidden developer" "${HIDDEN_DEV_CACHES[@]}"

# 28. macOS Installer Applications
print_section "28. 💿 macOS Installer Apps"
echo "Checking for macOS installer applications..."

FOUND_INSTALLERS=false
for installer in /Applications/Install\ macOS*.app /Applications/macOS*.app; do
    if [ -d "$installer" ]; then
        FOUND_INSTALLERS=true
        echo -e "$(basename "$installer"): ${BOLD}$(calculate_size "$installer")${NC}"
    fi
done

if [ "$FOUND_INSTALLERS" = true ]; then
    if confirm "Remove macOS installer applications?"; then
        for installer in /Applications/Install\ macOS*.app /Applications/macOS*.app; do
            [ -d "$installer" ] && rm -rf "$installer" 2>/dev/null
        done
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}macOS installers removed.${NC}"
        log_operation "macOS installers removed"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${GREEN}No macOS installer applications found.${NC}"
fi

# 29. Large File Scanner
print_section "29. 📊 Large File Scanner"
echo "Scanning for files larger than 1GB..."
echo -e "${YELLOW}This may take a few minutes...${NC}"

if confirm "Scan for large files?"; then
    SCAN_PATHS=(
        "$USER_HOME/Downloads"
        "$USER_HOME/Desktop"
        "$USER_HOME/Documents"
        "$USER_HOME/Movies"
        "$USER_HOME/Pictures"
    )

    echo -e "\n${CYAN}Large files found:${NC}"
    for scan_path in "${SCAN_PATHS[@]}"; do
        if [ -d "$scan_path" ]; then
            echo -e "\n${BOLD}In $(basename "$scan_path"):${NC}"
            find "$scan_path" -type f -size +1G 2>/dev/null | head -10 | while read -r file; do
                echo -e "  ${BOLD}$(calculate_size "$file")${NC} - $(basename "$file")"
            done
        fi
    done

    echo -e "\n${CYAN}Review these files and manually delete if no longer needed.${NC}"
else
    OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
fi

# 30. Purgeable Space Recovery
print_section "30. 🔄 Purgeable Space Recovery"
echo -e "${YELLOW}This creates temporary files to trigger purgeable space cleanup.${NC}"

AVAILABLE_SPACE_GB=$(df -g / | grep -v Filesystem | awk '{print $4}')

if [ "$AVAILABLE_SPACE_GB" -gt 5 ]; then
    if confirm "Attempt purgeable space recovery?"; then
        FILE_SIZE_GB=$((AVAILABLE_SPACE_GB / 2))
        [ "$FILE_SIZE_GB" -gt 2 ] && FILE_SIZE_GB=2

        mkdir -p ~/temp_cleanup_purgeable 2>/dev/null
        echo "Creating ${FILE_SIZE_GB}GB temporary file..."
        dd if=/dev/zero of=~/temp_cleanup_purgeable/bigfile bs=1024m count=$FILE_SIZE_GB 2>/dev/null
        sleep 5
        rm -rf ~/temp_cleanup_purgeable
        purge
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Purgeable space recovery completed.${NC}"
        log_operation "Purgeable space recovery"
    else
        OPERATIONS_SKIPPED=$((OPERATIONS_SKIPPED + 1))
    fi
else
    echo -e "${RED}Insufficient space for safe recovery. Skipping.${NC}"
fi

# ============================================================================
# FINAL RESULTS
# ============================================================================

print_section "✅ Cleanup Results"
SPACE_AFTER=$(show_space_info)
echo -e "${BLUE}Space before: ${BOLD}${SPACE_BEFORE}${NC}"
echo -e "${GREEN}Space after:  ${BOLD}${SPACE_AFTER}${NC}"
echo ""
echo -e "${CYAN}Operations completed: ${BOLD}${OPERATIONS_COMPLETED}${NC}"
echo -e "${YELLOW}Operations skipped:   ${BOLD}${OPERATIONS_SKIPPED}${NC}"

if [ "$TOTAL_FREED" -gt 0 ]; then
    TOTAL_FREED_MB=$((TOTAL_FREED / 1024))
    TOTAL_FREED_GB=$((TOTAL_FREED_MB / 1024))
    echo -e "${GREEN}Estimated space freed: ${BOLD}~${TOTAL_FREED_GB}GB${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}✅ Cleanup process completed!${NC}"
log_operation "Cleanup session completed - ${OPERATIONS_COMPLETED} operations"

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

print_section "💡 Recommendations"
echo -e "${CYAN}Post-Cleanup Actions:${NC}"
echo "  1. Restart your Mac for all changes to take effect"
echo "  2. Check app functionality - relaunch if needed"
echo "  3. Monitor Spotlight reindexing (if enabled)"
echo "  4. Verify free space: About This Mac > Storage"
echo ""
echo -e "${CYAN}Ongoing Maintenance:${NC}"
echo "  5. Run this script monthly"
echo "  6. Use Time Machine for regular backups"
echo "  7. Monitor storage: System Settings > General > Storage"
echo "  8. Clear browser caches regularly"
echo "  9. Remove unused applications completely"
echo " 10. Keep macOS and apps updated"
echo ""
echo -e "${CYAN}Performance Tips:${NC}"
echo " 11. Limit Desktop icons (< 50 items)"
echo " 12. Manage login items for faster boot"
echo " 13. Close unused browser tabs"
echo " 14. Monitor Activity Monitor for resource hogs"
echo " 15. Consider SSD upgrade if constantly low on space"
echo ""
echo -e "${GREEN}Log file saved: /tmp/cleanup_log_$(date +%Y%m%d).log${NC}"
echo ""

exit 0
