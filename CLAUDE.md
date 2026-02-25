# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains a MacBook cleanup script (`cleanup.sh`) designed to help free up storage space on macOS systems.

## Running the Script

```bash
sudo bash cleanup.sh
```

## Script Architecture

The script is organized into three tiers based on risk level:

### 1. Safe Cleanup (automatic, no confirmation)
Operations that only delete regenerable data:
- System and user cache files
- Browser caches (Safari, Chrome, Firefox, Edge, Opera, Brave, Arc, Vivaldi)
- Browser extra data (Code Cache, Service Worker, GPUCache)
- Log files and crash reports
- Temporary files
- Trash
- Font cache, QuickLook thumbnails, DNS cache
- Professional app caches (Adobe, Final Cut, Logic, Sketch, Figma, etc.)
- Core Data and CloudKit caches
- macOS and App Store update caches
- Hidden developer caches (.cache, .npm, .gradle, etc.)
- macOS installer applications
- Memory purge

### 2. Moderate Risk (simple confirmation)
Operations that affect tools or delete user-generated content:
- Aerial/wallpaper videos
- Docker cleanup (containers, images, volumes, build cache)
- Xcode derived data and device support
- Package manager caches (npm, yarn, pnpm, bun, pip, conda, gem, cargo)
- Homebrew update and cleanup
- Mail attachments and old downloads (30+ days)
- Spotlight index rebuild
- macOS maintenance scripts
- Purgeable space recovery
- macOS UI performance tuning

### 3. High Risk (double confirmation - type 'YES')
Operations that can cause data loss or affect system stability:
- Time Machine local snapshots
- APFS snapshots
- iOS device backups
- Hibernation sleep image (disables hibernate)
- Swap files
- Language localizations removal (.lproj from third-party apps)

### Core Functions
- `print_section`: Section headers
- `calculate_size` / `calculate_size_bytes`: Directory size utilities
- `confirm`: Simple y/N confirmation
- `double_confirm`: Requires typing 'YES'
- `auto_clean`: Cleans a directory without confirmation
- `show_space_info`: Disk space display
- `log_operation`: Timestamped logging to /tmp/cleanup_log_YYYYMMDD.log

## Development Notes

When modifying the script, be careful with:
- Commands that delete files, especially those using `rm -rf`
- User permission handling and sudo requirements
- Directory paths which may vary between macOS versions
- Maintain the three-tier risk classification when adding new operations
