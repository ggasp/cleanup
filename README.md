# MacBook Storage Cleanup Script

A comprehensive command-line tool for freeing up storage space on macOS systems. This script provides an interactive, safe, and thorough approach to cleaning your Mac.

## Features

- **Interactive cleanup** - Asks for confirmation before each operation
- **Safe operations** - Shows file sizes before deletion and warns about important data
- **Comprehensive coverage** - Cleans multiple types of system and user files
- **Visual feedback** - Color-coded output and progress indicators
- **Before/after comparison** - Shows storage space freed up

## What It Cleans

1. **Time Machine Local Snapshots** - Local backup snapshots that can take up significant space
2. **System Cache Files** - System-level cache files in `/Library/Caches/`
3. **User Cache Files** - User-specific cache files in `~/Library/Caches/`
4. **Browser Caches** - Safari, Chrome, and Firefox cache files
5. **Log Files** - System and user log files
6. **Temporary Files** - Files in `/tmp/` and `/private/var/tmp/`
7. **iOS Device Backups** - iPhone and iPad backup files
8. **Trash** - Empty the Trash folder
9. **macOS Maintenance Scripts** - Run daily, weekly, and monthly maintenance
10. **Inactive Memory** - Purge inactive memory to free up RAM
11. **Homebrew Cleanup** - Update and clean Homebrew packages (if installed)

## Usage

```bash
# Run with sudo for full functionality
sudo bash cleanup.sh
```

**Important:** The script requires `sudo` privileges to access system-level files and perform comprehensive cleanup operations.

## Safety Features

- **Backup warning** - Reminds users to backup important data
- **Confirmation prompts** - Asks before each cleanup operation
- **Size display** - Shows how much space each operation will free
- **Non-destructive** - Only removes cache, temporary, and log files
- **Selective cleaning** - You can skip any operation you're not comfortable with

## Comparison with CleanMyMac.app

| Feature | cleanup.sh | CleanMyMac.app |
|---------|------------|----------------|
| **Cost** | Free and open source | Paid subscription (~$95/year) |
| **Transparency** | Fully visible operations | Black box operations |
| **Control** | Granular control over each operation | Limited customization |
| **Safety** | Manual confirmation for each step | Automated with some user control |
| **Coverage** | Comprehensive system cleanup | Broader feature set (malware scan, optimization) |
| **Learning** | Educational - shows what's being cleaned | User-friendly but less educational |
| **Dependencies** | Pure bash script | Requires app installation |
| **Updates** | Manual script updates | Automatic app updates |

### Advantages of cleanup.sh

- **Complete transparency** - You can see exactly what commands are being run
- **Educational value** - Learn about macOS file system and cleanup operations
- **No subscription costs** - Free to use and modify
- **Scriptable** - Can be automated or customized for specific needs
- **Lightweight** - No background processes or system monitoring
- **Open source** - Can be audited and modified as needed

### Advantages of CleanMyMac.app

- **User-friendly GUI** - More accessible for non-technical users
- **Additional features** - Malware detection, duplicate finder, app uninstaller
- **Automated scheduling** - Can run cleanups automatically
- **Professional support** - Customer service and regular updates
- **System monitoring** - Real-time storage and performance monitoring
- **Integration** - Better integration with macOS notifications and system

## When to Use Each

**Use cleanup.sh when:**
- You want full control over what gets cleaned
- You prefer command-line tools
- You want to understand what cleanup operations do
- You need a free solution
- You want to customize or script the cleanup process

**Use CleanMyMac.app when:**
- You prefer a graphical interface
- You want additional features like malware scanning
- You need automated, scheduled cleanups
- You don't mind paying for convenience
- You want professional support

## Requirements

- macOS (tested on macOS 10.14+)
- Sudo privileges
- Terminal access

## Installation

1. Download the `cleanup.sh` script
2. Make it executable: `chmod +x cleanup.sh`
3. Run with sudo: `sudo bash cleanup.sh`

## Contributing

This script is open source and can be modified to suit your specific needs. Common customizations include:
- Adding additional cleanup locations
- Modifying confirmation prompts
- Changing color schemes
- Adding logging functionality

## Disclaimer

Always backup important data before running any cleanup operations. While this script is designed to be safe and only remove temporary/cache files, use at your own risk.