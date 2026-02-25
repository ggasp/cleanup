#!/bin/bash

# MacBook Storage Cleanup Script - Simplified Version
# Run with: sudo bash cleanup.sh

# ============================================================================
# CONFIGURATION
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

USER_HOME=$(eval echo ~$SUDO_USER)

# Statistics tracking
TOTAL_FREED=0
OPERATIONS_COMPLETED=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '%.0s-' {1..60})${NC}"
}

calculate_size() {
    if [ -e "$1" ]; then
        du -sh "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

calculate_size_bytes() {
    if [ -e "$1" ]; then
        du -sk "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

show_space_info() {
    df -h / | grep -v Filesystem | awk '{print $4 " available (" $5 " used)"}'
}

log_operation() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "/tmp/cleanup_log_$(date +%Y%m%d).log"
}

confirm() {
    read -p "$(echo -e ${YELLOW}"$1 [y/N]: "${NC})" response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

double_confirm() {
    echo -e "${RED}${BOLD}⚠️  DANGEROUS OPERATION${NC}"
    echo -e "${RED}$1${NC}"
    read -p "$(echo -e "${RED}Type 'YES' to confirm: ${NC}")" response
    [ "$response" = "YES" ]
}

# Clean directory silently (no confirmation)
auto_clean() {
    local name="$1"
    local path="$2"
    [ ! -d "$path" ] && return
    local size_before=$(calculate_size_bytes "$path")
    [ "$size_before" -eq 0 ] && return
    echo -e "  ${name}: ${BOLD}$(calculate_size "$path")${NC} → cleaning..."
    rm -rf "$path"/* 2>/dev/null
    rm -rf "$path"/.[!.]* 2>/dev/null
    local freed=$((size_before - $(calculate_size_bytes "$path")))
    TOTAL_FREED=$((TOTAL_FREED + freed))
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    log_operation "${name} cleaned - freed ${freed}KB"
}

# ============================================================================
# STARTUP
# ============================================================================

echo -e "${BOLD}${BLUE}================================================================${NC}"
echo -e "${BOLD}${BLUE}            MacBook Storage Cleanup Script                      ${NC}"
echo -e "${BOLD}${BLUE}================================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with: sudo bash cleanup.sh${NC}"
    exit 1
fi

SPACE_BEFORE=$(show_space_info)
echo -e "${BLUE}Disk space: ${BOLD}${SPACE_BEFORE}${NC}"
echo -e "${YELLOW}Backup important data before proceeding.${NC}"
echo ""
log_operation "Cleanup session started"

# ============================================================================
# SAFE CLEANUP (automatic, no confirmation needed)
# ============================================================================

print_section "🧹 Safe Cleanup (caches, logs, temp files)"

# System & User caches
auto_clean "System cache" "/Library/Caches"
auto_clean "User cache" "$USER_HOME/Library/Caches"

# Browser caches
BROWSER_CACHES=(
    "Safari|$USER_HOME/Library/Caches/com.apple.Safari"
    "Chrome|$USER_HOME/Library/Caches/Google/Chrome"
    "Firefox|$USER_HOME/Library/Caches/Firefox"
    "Edge|$USER_HOME/Library/Caches/com.microsoft.edgemac"
    "Opera|$USER_HOME/Library/Caches/com.operasoftware.Opera"
    "Brave|$USER_HOME/Library/Caches/BraveSoftware/Brave-Browser"
    "Arc|$USER_HOME/Library/Caches/company.thebrowser.Browser"
    "Vivaldi|$USER_HOME/Library/Caches/com.vivaldi.Vivaldi"
)
for entry in "${BROWSER_CACHES[@]}"; do
    auto_clean "${entry%%|*} cache" "${entry#*|}"
done

# Firefox profile caches
find "$USER_HOME/Library/Caches/Firefox/Profiles" -name "cache2" -type d -exec rm -rf {} + 2>/dev/null

# Chromium extra caches (Code Cache, Service Worker, GPUCache)
for browser in "Google/Chrome" "Microsoft Edge" "BraveSoftware/Brave-Browser" "Vivaldi"; do
    BROWSER_PATH="$USER_HOME/Library/Application Support/$browser"
    if [ -d "$BROWSER_PATH" ]; then
        rm -rf "$BROWSER_PATH"/*/Code\ Cache/* 2>/dev/null
        rm -rf "$BROWSER_PATH"/*/Service\ Worker/* 2>/dev/null
        rm -rf "$BROWSER_PATH"/*/GPUCache/* 2>/dev/null
    fi
done

# Safari extra data
for path in "$USER_HOME/Library/Safari/Databases" "$USER_HOME/Library/Safari/LocalStorage" "$USER_HOME/Library/Safari/WebsiteData"; do
    auto_clean "Safari $(basename "$path")" "$path"
done

# Log files
auto_clean "System logs" "/Library/Logs"
auto_clean "User logs" "$USER_HOME/Library/Logs"

# Temporary files
echo -e "  Temp files → cleaning..."
rm -rf /private/var/tmp/* 2>/dev/null
rm -rf /tmp/* 2>/dev/null
find /private/var/folders -name "T" -type d 2>/dev/null | while read -r tempdir; do
    [ -d "$tempdir" ] && [ -w "$tempdir" ] && rm -rf "$tempdir"/* 2>/dev/null
done
OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
log_operation "Temp files cleaned"

# Crash reports
for crash_path in "/Library/Logs/DiagnosticReports" "$USER_HOME/Library/Logs/DiagnosticReports" "$USER_HOME/Library/Logs/CrashReporter"; do
    auto_clean "Crash reports ($(basename "$crash_path"))" "$crash_path"
done

# Trash
TRASH_SIZE=$(calculate_size_bytes "$USER_HOME/.Trash/")
if [ "$TRASH_SIZE" -gt 0 ]; then
    echo -e "  Trash: ${BOLD}$(calculate_size "$USER_HOME/.Trash/")${NC} → cleaning..."
    rm -rf "$USER_HOME/.Trash"/* 2>/dev/null
    TOTAL_FREED=$((TOTAL_FREED + TRASH_SIZE))
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    log_operation "Trash emptied"
fi

# Font cache, QuickLook, DNS
echo -e "  Font/QuickLook/DNS cache → cleaning..."
sudo atsutil databases -remove 2>/dev/null
sudo atsutil server -shutdown 2>/dev/null
sudo atsutil server -ping 2>/dev/null
qlmanage -r cache 2>/dev/null
sudo dscacheutil -flushcache 2>/dev/null
sudo killall -HUP mDNSResponder 2>/dev/null
OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
log_operation "Font/QuickLook/DNS cleared"

# Professional application caches
PROFESSIONAL_APP_CACHES=(
    "Adobe After Effects|$USER_HOME/Library/Caches/com.adobe.AfterEffects"
    "Adobe Photoshop|$USER_HOME/Library/Caches/com.adobe.Photoshop"
    "Adobe Premiere|$USER_HOME/Library/Caches/com.adobe.PremierePro"
    "Final Cut Pro|$USER_HOME/Library/Caches/com.apple.FinalCut"
    "Logic Pro|$USER_HOME/Library/Caches/com.apple.logic10"
    "Sketch|$USER_HOME/Library/Caches/com.bohemiancoding.sketch3"
    "Figma|$USER_HOME/Library/Caches/com.figma.Desktop"
    "Cinema 4D|$USER_HOME/Library/Caches/net.maxon.cinema4d"
    "Unity Hub|$USER_HOME/Library/Caches/com.unity3d.UnityHub"
    "Blender|$USER_HOME/Library/Caches/org.blenderfoundation.blender"
)
for entry in "${PROFESSIONAL_APP_CACHES[@]}"; do
    auto_clean "${entry%%|*}" "${entry#*|}"
done

# Core Data & CloudKit caches
auto_clean "CloudKit cache" "$USER_HOME/Library/Caches/CloudKit"
auto_clean "CoreData cache" "$USER_HOME/Library/Caches/com.apple.CoreData"
auto_clean "cloudkit cache" "$USER_HOME/Library/Caches/com.apple.cloudkit"

# macOS & App Store update caches
auto_clean "Updates" "/Library/Updates"
auto_clean "App Store cache" "$USER_HOME/Library/Caches/com.apple.appstore"
auto_clean "Software Update cache" "$USER_HOME/Library/Caches/com.apple.SoftwareUpdate"
sudo softwareupdate --clear-catalog 2>/dev/null

# Hidden developer caches
HIDDEN_DEV_CACHES=(
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
for path in "${HIDDEN_DEV_CACHES[@]}"; do
    auto_clean "$(basename "$path")" "$path"
done

# macOS installer apps
for installer in /Applications/Install\ macOS*.app /Applications/macOS*.app; do
    if [ -d "$installer" ]; then
        echo -e "  $(basename "$installer"): ${BOLD}$(calculate_size "$installer")${NC} → removing..."
        rm -rf "$installer" 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        log_operation "Removed $(basename "$installer")"
    fi
done

# Memory purge
echo -e "  Memory → purging..."
purge 2>/dev/null
log_operation "Memory purged"

echo -e "${GREEN}Safe cleanup done.${NC}"

# ============================================================================
# MODERATE RISK (simple confirmation)
# ============================================================================

print_section "📦 Developer Tools Cleanup"

# Aerial Videos
AERIAL_PATH="/Library/Application Support/com.apple.idleassetsd/Customer"
if [ -d "$AERIAL_PATH" ]; then
    AERIAL_BYTES=$(calculate_size_bytes "$AERIAL_PATH")
    if [ "$AERIAL_BYTES" -gt 0 ]; then
        echo -e "Aerial/Wallpaper videos: ${BOLD}$(calculate_size "$AERIAL_PATH")${NC}"
        if confirm "Delete aerial videos? They re-download if dynamic wallpaper is active."; then
            rm -rf "$AERIAL_PATH/4KSDR240FPS"/* 2>/dev/null
            rm -rf "$AERIAL_PATH/4KSDR30FPS"/* 2>/dev/null
            rm -f "$AERIAL_PATH/entries.json" 2>/dev/null
            rm -f "$USER_HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist" 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + AERIAL_BYTES))
            OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
            echo -e "${GREEN}Aerial videos deleted. Set a static wallpaper to prevent re-download.${NC}"
            log_operation "Aerial videos deleted"
        fi
    fi
fi

# Docker
if command -v docker &> /dev/null && docker info &> /dev/null; then
    echo ""
    echo "Docker detected:"
    docker system df 2>/dev/null
    if confirm "Clean Docker (containers, images, volumes, build cache)?"; then
        docker container prune -f 2>/dev/null
        docker image prune -a -f 2>/dev/null
        docker volume prune -f 2>/dev/null
        docker network prune -f 2>/dev/null
        docker builder prune -a -f 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Docker cleaned.${NC}"
        log_operation "Docker cleaned"
    fi
fi

# Xcode
XCODE_PATH="$USER_HOME/Library/Developer/Xcode"
if [ -d "$XCODE_PATH" ]; then
    echo ""
    echo "Xcode detected:"
    [ -d "$XCODE_PATH/DerivedData" ] && echo -e "  DerivedData: ${BOLD}$(calculate_size "$XCODE_PATH/DerivedData")${NC}"
    [ -d "$XCODE_PATH/iOS DeviceSupport" ] && echo -e "  iOS DeviceSupport: ${BOLD}$(calculate_size "$XCODE_PATH/iOS DeviceSupport")${NC}"
    [ -d "$XCODE_PATH/Archives" ] && echo -e "  Archives: ${BOLD}$(calculate_size "$XCODE_PATH/Archives")${NC}"

    if confirm "Clean Xcode derived data and device support?"; then
        [ -d "$XCODE_PATH/DerivedData" ] && rm -rf "$XCODE_PATH/DerivedData"/* 2>/dev/null
        [ -d "$XCODE_PATH/iOS DeviceSupport" ] && rm -rf "$XCODE_PATH/iOS DeviceSupport"/* 2>/dev/null
        command -v xcrun &> /dev/null && xcrun simctl delete unavailable 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Xcode cleaned.${NC}"
        log_operation "Xcode cleaned"
    fi
fi

# Package managers
print_section "📦 Package Manager Caches"
found_pkg=false

for cmd_check in "npm" "yarn" "pnpm" "bun" "pip3" "pip" "conda" "gem" "cargo"; do
    command -v "$cmd_check" &> /dev/null && found_pkg=true && break
done

if [ "$found_pkg" = true ]; then
    command -v npm &> /dev/null && echo -e "  npm: $(npm config get cache 2>/dev/null | xargs du -sh 2>/dev/null | awk '{print $1}' || echo 'N/A')"
    command -v yarn &> /dev/null && echo -e "  yarn: $(yarn cache dir 2>/dev/null | xargs du -sh 2>/dev/null | awk '{print $1}' || echo 'N/A')"
    [ -d "$USER_HOME/.pnpm-store" ] && echo -e "  pnpm: $(calculate_size "$USER_HOME/.pnpm-store")"
    [ -d "$USER_HOME/.bun/install/cache" ] && echo -e "  bun: $(calculate_size "$USER_HOME/.bun/install/cache")"

    if confirm "Clear all package manager caches?"; then
        command -v npm &> /dev/null && npm cache clean --force 2>/dev/null
        command -v yarn &> /dev/null && yarn cache clean 2>/dev/null
        command -v pnpm &> /dev/null && pnpm store prune 2>/dev/null
        [ -d "$USER_HOME/.bun/install/cache" ] && rm -rf "$USER_HOME/.bun/install/cache"/* 2>/dev/null
        command -v pip3 &> /dev/null && pip3 cache purge 2>/dev/null || { command -v pip &> /dev/null && pip cache purge 2>/dev/null; }
        command -v conda &> /dev/null && conda clean --all -y 2>/dev/null
        command -v gem &> /dev/null && gem cleanup 2>/dev/null && [ -d "$USER_HOME/.gem/cache" ] && rm -rf "$USER_HOME/.gem/cache"/* 2>/dev/null
        if command -v cargo &> /dev/null; then
            if command -v cargo-cache &> /dev/null; then
                cargo cache --autoclean 2>/dev/null
            else
                [ -d "$USER_HOME/.cargo/registry/cache" ] && rm -rf "$USER_HOME/.cargo/registry/cache"/* 2>/dev/null
            fi
        fi
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Package manager caches cleared.${NC}"
        log_operation "Package manager caches cleared"
    fi
fi

# Homebrew
if command -v brew &> /dev/null; then
    print_section "🍺 Homebrew"
    BREW_CACHE_PATH=$(brew --cache 2>/dev/null)
    [ -d "$BREW_CACHE_PATH" ] && echo -e "Homebrew cache: ${BOLD}$(calculate_size "$BREW_CACHE_PATH")${NC}"

    if confirm "Update and clean Homebrew?"; then
        brew update && brew upgrade && brew cleanup -s
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Homebrew cleaned.${NC}"
        log_operation "Homebrew cleaned"
    fi
fi

# Mail & Downloads
print_section "📧 Mail & Downloads"
MAIL_DOWNLOADS="$USER_HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"
DOWNLOADS_PATH="$USER_HOME/Downloads"

if [ -d "$MAIL_DOWNLOADS" ]; then
    echo -e "Mail Downloads: ${BOLD}$(calculate_size "$MAIL_DOWNLOADS")${NC}"
fi
if [ -d "$DOWNLOADS_PATH" ]; then
    OLD_DOWNLOADS=$(find "$DOWNLOADS_PATH" -type f -mtime +30 2>/dev/null | wc -l | tr -d ' ')
    echo -e "Downloads older than 30 days: ${BOLD}${OLD_DOWNLOADS} files${NC}"
fi

if confirm "Clean Mail attachments and old downloads (30+ days)?"; then
    [ -d "$MAIL_DOWNLOADS" ] && rm -rf "$MAIL_DOWNLOADS"/* 2>/dev/null
    if [ -d "$USER_HOME/Library/Mail" ]; then
        find "$USER_HOME/Library/Mail" -name "Attachments" -type d 2>/dev/null | while read -r attachdir; do
            [ -d "$attachdir" ] && rm -rf "$attachdir"/* 2>/dev/null
        done
    fi
    if [ -d "$DOWNLOADS_PATH" ]; then
        find "$DOWNLOADS_PATH" -type f -mtime +30 -delete 2>/dev/null
        find "$DOWNLOADS_PATH" -type f -name "*.dmg" -mtime +7 -delete 2>/dev/null
    fi
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Mail and Downloads cleaned.${NC}"
    log_operation "Mail and downloads cleaned"
fi

# Spotlight
print_section "🔍 Spotlight Index"
echo -e "${YELLOW}Rebuilding Spotlight takes several hours and uses CPU.${NC}"
if confirm "Rebuild Spotlight index?"; then
    sudo mdutil -i off / && sudo rm -rf /.Spotlight-V100 && sudo mdutil -i on / && sudo mdutil -E /
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Spotlight rebuild initiated (runs in background).${NC}"
    log_operation "Spotlight rebuild started"
fi

# macOS Maintenance
print_section "🔧 macOS Maintenance"
if confirm "Run macOS maintenance scripts (LaunchServices, dyld cache, locate db)?"; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null
    sudo update_dyld_shared_cache -force 2>/dev/null
    sudo /usr/libexec/locate.updatedb 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Maintenance completed.${NC}"
    log_operation "Maintenance scripts run"
fi

# Purgeable Space
print_section "🔄 Purgeable Space Recovery"
AVAILABLE_SPACE_GB=$(df -g / | grep -v Filesystem | awk '{print $4}')
if [ "$AVAILABLE_SPACE_GB" -gt 5 ]; then
    if confirm "Attempt purgeable space recovery (creates/deletes temp file)?"; then
        FILE_SIZE_GB=$((AVAILABLE_SPACE_GB / 2))
        [ "$FILE_SIZE_GB" -gt 2 ] && FILE_SIZE_GB=2
        mkdir -p ~/temp_cleanup_purgeable 2>/dev/null
        dd if=/dev/zero of=~/temp_cleanup_purgeable/bigfile bs=1024m count=$FILE_SIZE_GB 2>/dev/null
        sleep 5
        rm -rf ~/temp_cleanup_purgeable
        purge
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Purgeable space recovery completed.${NC}"
        log_operation "Purgeable space recovery"
    fi
else
    echo -e "${YELLOW}Insufficient space for safe recovery. Skipping.${NC}"
fi

# Performance Tuning
print_section "⚡ macOS Performance Tuning"
echo "  1. Disable window animations"
echo "  2. Speed up Dock show/hide"
echo "  3. Faster Mission Control"
if confirm "Apply UI performance optimizations?"; then
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.5
    defaults write com.apple.dock expose-animation-duration -float 0.1
    killall Dock 2>/dev/null
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Optimizations applied.${NC}"
    echo -e "${CYAN}Revert: defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled && defaults delete com.apple.dock autohide-delay && defaults delete com.apple.dock autohide-time-modifier && defaults delete com.apple.dock expose-animation-duration && killall Dock${NC}"
    log_operation "Performance optimizations applied"
fi

# ============================================================================
# HIGH RISK (double confirmation required)
# ============================================================================

print_section "⚠️  High Risk Operations"
echo -e "${RED}The following operations can cause data loss or affect system stability.${NC}"
echo -e "${RED}Each requires typing 'YES' to confirm.${NC}"
echo ""

# Time Machine Local Snapshots
SNAPSHOTS=$(tmutil listlocalsnapshots / 2>/dev/null)
if [ -n "$SNAPSHOTS" ]; then
    echo -e "${YELLOW}Time Machine local snapshots found:${NC}"
    echo "$SNAPSHOTS"
    if double_confirm "Delete ALL Time Machine local snapshots?"; then
        for snapshot_date in $(tmutil listlocalsnapshotdates / 2>/dev/null | grep -E "^[0-9]"); do
            tmutil deletelocalsnapshots "$snapshot_date" 2>/dev/null
        done
        tmutil thinlocalsnapshots / 999999999999 1 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Time Machine snapshots deleted.${NC}"
        log_operation "Time Machine snapshots deleted"
    fi
    echo ""
fi

# APFS Snapshots
APFS_SNAPSHOTS=$(diskutil apfs listSnapshots / 2>/dev/null | grep -E "^\+-- " | awk '{print $2}')
if [ -n "$APFS_SNAPSHOTS" ]; then
    echo -e "${YELLOW}APFS snapshots found:${NC}"
    diskutil apfs listSnapshots / 2>/dev/null | grep -E "^\+-- "
    if double_confirm "Delete APFS snapshots? Removes ability to roll back system updates."; then
        for uuid in $APFS_SNAPSHOTS; do
            diskutil apfs deleteSnapshot / -uuid "$uuid" 2>/dev/null
        done
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}APFS snapshots deleted.${NC}"
        log_operation "APFS snapshots deleted"
    fi
    echo ""
fi

# iOS Device Backups
IOS_BACKUP_PATH="$USER_HOME/Library/Application Support/MobileSync/Backup"
if [ -d "$IOS_BACKUP_PATH" ]; then
    IOS_BACKUP_SIZE=$(calculate_size "$IOS_BACKUP_PATH")
    IOS_BACKUP_BYTES=$(calculate_size_bytes "$IOS_BACKUP_PATH")
    if [ "$IOS_BACKUP_BYTES" -gt 0 ]; then
        echo -e "iOS backups: ${BOLD}${IOS_BACKUP_SIZE}${NC}"
        if double_confirm "Delete ALL iOS device backups?"; then
            rm -rf "$IOS_BACKUP_PATH"/* 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + IOS_BACKUP_BYTES))
            OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
            echo -e "${GREEN}iOS backups deleted.${NC}"
            log_operation "iOS backups cleared"
        fi
        echo ""
    fi
fi

# Hibernation Sleep Image
SLEEPIMAGE_PATH="/private/var/vm/sleepimage"
if [ -f "$SLEEPIMAGE_PATH" ]; then
    echo -e "Sleep image: ${BOLD}$(calculate_size "$SLEEPIMAGE_PATH")${NC}"
    echo -e "${RED}If battery dies during sleep, you WILL lose unsaved work.${NC}"
    if double_confirm "Disable hibernation and remove sleep image?"; then
        ORIGINAL_HIBERNATE=$(pmset -g | grep hibernatemode | awk '{print $2}')
        log_operation "Original hibernatemode: $ORIGINAL_HIBERNATE"
        sudo pmset -a hibernatemode 0
        sudo rm -f "$SLEEPIMAGE_PATH"
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Hibernation disabled. Re-enable: sudo pmset -a hibernatemode $ORIGINAL_HIBERNATE${NC}"
        log_operation "Hibernation disabled"
    fi
    echo ""
fi

# Swap Files
SWAP_PATH="/private/var/vm"
if [ -d "$SWAP_PATH" ]; then
    SWAP_SIZE=$(calculate_size "$SWAP_PATH")
    SWAP_USED_MB=$(sysctl vm.swapusage 2>/dev/null | awk '{print $7}' | tr -d 'M' | cut -d'.' -f1)
    echo -e "Swap directory: ${BOLD}${SWAP_SIZE}${NC}"
    if [ -n "$SWAP_USED_MB" ] && [ "$SWAP_USED_MB" -gt 500 ]; then
        echo -e "${RED}Swap is heavily used (${SWAP_USED_MB}MB). May cause instability!${NC}"
    fi
    if double_confirm "Remove swap files? Requires restart."; then
        rm -f /private/var/vm/swapfile* 2>/dev/null
        OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
        echo -e "${GREEN}Swap files removed. Restart your Mac.${NC}"
        log_operation "Swap files removed"
    fi
    echo ""
fi

# Language Localizations
echo -e "${YELLOW}Language localizations: removes non-English .lproj from third-party apps.${NC}"
echo -e "${RED}Apps may need reinstall after this. Apple apps are excluded.${NC}"
if double_confirm "Remove non-English localizations from third-party apps?"; then
    APPLE_APPS_EXCLUDE="Safari.app|Mail.app|Messages.app|FaceTime.app|Photos.app|Music.app|TV.app|News.app|Stocks.app|Books.app|Podcasts.app|Calendar.app|Contacts.app|Reminders.app|Notes.app|Maps.app|Preview.app|TextEdit.app|Finder.app|System Preferences.app|System Settings.app|App Store.app|Xcode.app"

    cleaned=0
    for app in /Applications/*.app; do
        [ ! -d "$app" ] && continue
        app_name=$(basename "$app")
        echo "$APPLE_APPS_EXCLUDE" | grep -q "$app_name" && continue
        codesign -dv "$app" 2>&1 | grep -q "Apple Inc." && continue

        LPROJ_COUNT=$(find "$app" -type d -name "*.lproj" ! -name "en.lproj" ! -name "English.lproj" ! -name "Base.lproj" -maxdepth 5 2>/dev/null | wc -l | tr -d ' ')
        if [ "$LPROJ_COUNT" -gt 0 ]; then
            echo -e "  Processing $(basename "$app")..."
            find "$app" -type d -name "*.lproj" ! -name "en.lproj" ! -name "English.lproj" ! -name "Base.lproj" -maxdepth 5 -exec rm -rf {} + 2>/dev/null
            cleaned=$((cleaned + 1))
        fi
    done
    OPERATIONS_COMPLETED=$((OPERATIONS_COMPLETED + 1))
    echo -e "${GREEN}Localizations removed from ${cleaned} apps.${NC}"
    log_operation "Language localizations removed (${cleaned} apps)"
fi

# ============================================================================
# RESULTS
# ============================================================================

print_section "✅ Cleanup Results"
SPACE_AFTER=$(show_space_info)
echo -e "${BLUE}Before: ${BOLD}${SPACE_BEFORE}${NC}"
echo -e "${GREEN}After:  ${BOLD}${SPACE_AFTER}${NC}"
echo -e "${CYAN}Operations completed: ${BOLD}${OPERATIONS_COMPLETED}${NC}"

if [ "$TOTAL_FREED" -gt 0 ]; then
    echo -e "${GREEN}Estimated freed: ${BOLD}~$((TOTAL_FREED / 1024 / 1024))GB${NC}"
fi

echo ""
echo -e "${CYAN}Post-cleanup:${NC}"
echo "  • Restart your Mac for full effect"
echo "  • Check storage: System Settings > General > Storage"
echo "  • Run monthly for best results"
echo ""
echo -e "${GREEN}Log: /tmp/cleanup_log_$(date +%Y%m%d).log${NC}"

exit 0
