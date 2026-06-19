# MacBook Disk Maintenance CLI

`cleanup.py` is a scanner-first CLI for keeping a MacBook disk healthy without blindly deleting important data. It identifies storage pressure, ranks cleanup opportunities, labels each item by risk, and only performs conservative safe cleanup actions when explicitly requested.

The older `cleanup.sh` script is still present as a legacy reference, but the Python CLI is now the safer foundation for ongoing development.

## Install

Rich is used for the terminal interface:

```bash
python3 -m pip install rich
```

The CLI has a plain-text fallback if Rich is not installed.

## Usage

```bash
python3 cleanup.py scan
python3 cleanup.py scan --json
python3 cleanup.py doctor
python3 cleanup.py clean --dry-run --yes-safe
python3 cleanup.py clean --yes-safe
python3 cleanup.py fresh-start --dry-run --i-understand fresh-start
python3 cleanup.py fresh-start --i-understand fresh-start
python3 cleanup.py deep-clean --dry-run --i-understand deep-clean
python3 cleanup.py deep-clean --i-understand deep-clean
```

Useful filters:

```bash
python3 cleanup.py scan --min-size 500M
python3 cleanup.py scan --large-file-threshold 2G
```

## Commands

- `scan`: default command. Reports reclaimable disk opportunities without deleting anything.
- `report`: alias-style report command for scan output.
- `doctor`: summarizes disk pressure by safety tier and calls out high-risk items for review.
- `clean`: cleans only findings marked `SAFE`, and only when `--yes-safe` is provided.
- `fresh-start`: cleans `SAFE` findings plus reasonable actionable `MODERATE` findings after the explicit `--i-understand fresh-start` keyword. Run with `--dry-run` first.
- `deep-clean`: cleans a broader set of actionable `MODERATE` findings after the explicit `--i-understand deep-clean` keyword. This is the aggressive automated mode.

## Safety Model

Findings are grouped into three risk levels:

- `SAFE`: regenerable files such as the current user's Trash, user cache contents, and user logs.
- `MODERATE`: usually removable, but should be reviewed first, such as installers, browser runtime caches, Xcode build artifacts, package-manager caches, Mail downloads, Homebrew cache, project dependency directories, dynamic wallpaper videos, Docker data, and large personal files.
- `HIGH`: data-loss or rollback-impacting items such as iOS device backups. These are reported but not automatically cleaned in the first Python version.

The CLI intentionally avoids dangerous legacy patterns:

- It does not delete `.venv` or `venv` directories automatically.
- It does not broadly delete inside `/private/var/folders` by vendor name.
- It does not delete inside `/System/Library/Caches`.
- It does not clean arbitrary Downloads automatically; `fresh-start` only removes common installer artifacts such as `.dmg`, `.pkg`, `.iso`, and `Install macOS*.app`.
- It refuses protected roots such as `/`, `/System`, `/Library`, `/Applications`, and the home directory itself.

## Fresh Start Mode

`fresh-start` is intended for a heavy reclaim pass while keeping high-risk data out of automation. It can remove:

- Trash, user caches, and user logs.
- Browser runtime caches such as Code Cache, GPUCache, and Service Worker cache folders.
- Package-manager caches for npm, Yarn, pnpm, Bun, pip, Poetry, Gradle, Maven, Cargo, Rustup, and Deno.
- Xcode DerivedData, iOS DeviceSupport, and CoreSimulator caches.
- Mail Downloads, common installer files in Downloads, dynamic wallpaper videos, and `node_modules` directories under common project folders.

It still only reports high-risk items such as iOS backups and review-only items such as Docker Desktop data and large personal files. Use the scan output to decide what to handle manually.

## Deep Clean Mode

`deep-clean` is for a heavier automated reclaim pass. Run the dry-run first:

```bash
python3 cleanup.py deep-clean --dry-run --i-understand deep-clean
```

It can clean browser website storage, expanded package-manager caches, Apple developer caches, selected professional app caches, AI/editor caches, generated macOS caches, dynamic wallpaper videos, Mail downloads, installers, and project dependency directories.

It still does not automatically delete Time Machine snapshots, APFS snapshots, iOS device backups, sleep images, swap files, app localizations, Xcode archives, arbitrary Downloads content, or large personal files.

## Development

Run tests:

```bash
python3 -m unittest discover -s tests -v
```

Run syntax checks:

```bash
python3 -m py_compile cleanup.py mac_clean/*.py
```

Project layout:

```text
cleanup.py              # CLI entry point
mac_clean/cli.py        # argparse commands
mac_clean/scanner.py    # storage scanners
mac_clean/actions.py    # guarded cleanup actions
mac_clean/models.py     # findings, reports, size formatting
mac_clean/reporters.py  # Rich/plain/JSON rendering
mac_clean/safety.py     # risk helpers
tests/                  # unittest suite
```

## Legacy Script

`cleanup.sh` remains available, but it contains aggressive operations that should be reviewed before use. Prefer `cleanup.py` for day-to-day disk maintenance.
