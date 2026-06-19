# Aggressive Python Cleanup Automation Design

Date: 2026-06-19

## Goal

Expand the Python cleanup CLI so it can reclaim more disk space automatically, while preserving the current scanner-first safety model and dry-run behavior.

The next version should make `cleanup.py` more useful for users who explicitly want aggressive cleanup. It should still avoid blindly automating operations that can remove backups, rollback points, active memory files, app integrity resources, or personal data.

## Current Context

The repository now has two cleanup implementations:

- `cleanup.sh`: legacy shell script with broad and sometimes risky deletion behavior.
- `cleanup.py` and `mac_clean/`: newer Python CLI with scan, report, doctor, clean, and fresh-start commands.

The Python CLI is the safer foundation for future work. It already scans common space hogs, supports JSON output, has dry-run cleanup actions, and refuses protected paths. Its current action surface is intentionally narrow compared with the legacy shell script.

## Command Model

Keep the existing command meanings and add one new command:

- `scan`: report storage opportunities without deleting anything.
- `doctor`: summarize disk pressure and risk tiers.
- `clean`: clean only `SAFE` findings, only with `--yes-safe`.
- `fresh-start`: clean actionable `SAFE` and reasonable `MODERATE` findings after `--i-understand fresh-start`.
- `deep-clean`: clean a broader set of actionable `MODERATE` findings after `--i-understand deep-clean`.

`deep-clean` is intentionally more aggressive than `fresh-start`. It is for users who have reviewed a dry run and want an automated heavy reclaim pass.

## Risk Boundaries

The three risk levels remain:

- `SAFE`: regenerable data with low user impact.
- `MODERATE`: usually removable data that may require re-downloads, rebuilds, app relaunches, or manual review.
- `HIGH`: data loss, rollback loss, system stability risk, or app integrity risk.

`deep-clean` may automate only `SAFE` and selected `MODERATE` actions. It must not automate `HIGH` findings in this iteration.

The following remain report-only:

- Time Machine local snapshots.
- APFS snapshots.
- iOS and iPadOS device backups.
- Sleep image and hibernation setting changes.
- Swap files.
- Language localization removal from `.app` bundles.
- Full application support directories.
- Arbitrary old Downloads files.
- Large personal files.
- Xcode archives; this implementation does not automate archive deletion.

## Expanded Scan Coverage

Add findings for more disk pressure points:

- Safari website storage: `Databases`, `LocalStorage`, `WebsiteData`.
- Chromium browser runtime cache: `Code Cache`, `GPUCache`, and `Service Worker/CacheStorage` for Chrome, Edge, Brave, Vivaldi, Arc, and Opera where paths exist.
- Additional package and development caches: conda package/cache directories, Ruby gem cache, Bundler cache, uv cache, pipx cache, Go build/module caches, Deno cache, Gradle, Maven, Cargo, Rustup, npm, Yarn, pnpm, Bun, and Poetry.
- Xcode and Apple developer artifacts: `DerivedData`, `iOS DeviceSupport`, watchOS/tvOS DeviceSupport if present, CoreSimulator caches, unavailable simulator devices as a command-backed action if `xcrun` is available.
- Professional app caches: Adobe media caches, Final Cut render/cache data where path-scoped, Logic cache data, Figma cache, Sketch cache, Blender cache, Unity Hub cache.
- AI and editor tool caches: Cursor, Claude, Continue, VS Code cached data, and common Electron app `Cache`, `Code Cache`, and `GPUCache` subdirectories where path-scoped.
- macOS generated storage: user logs, diagnostic reports, Mail downloads, app store caches, software update caches, aerial wallpaper videos, and common installer artifacts.

Findings should include clear details explaining the expected consequence of cleanup: re-download, rebuild, app relaunch, lost local cache, or manual review required.

## Action Model

Extend `mac_clean/actions.py` with reusable action handlers:

- `clean-directory-contents`: delete children while preserving the directory.
- `remove-matching-children`: remove direct children matching known installer/cache patterns.
- `remove-path`: remove a specific path when scanner owns the path and it is not protected.
- `clean-known-subdirs`: remove named cache subdirectories below a scanned root, such as `Cache`, `Code Cache`, and `GPUCache`.
- `run-command`: execute a small allowlisted maintenance command when the command exists and has no shell interpolation.

The command-backed action list should stay small and explicit. Initial candidates:

- `xcrun simctl delete unavailable`.
- Package-manager cache commands only where they are stable and safer than deleting broad directories.

Every action must support dry-run. For command-backed actions, dry-run reports what would run instead of executing it.

## Safety Guards

Deletion guards stay centralized:

- Refuse protected roots: `/`, `/System`, `/Library`, `/Applications`, and the user home directory itself.
- Refuse symlink traversal.
- Refuse broad parent directories unless the action targets known child names or direct contents.
- Tolerate paths already removed by earlier parent actions.
- Keep high-risk findings non-actionable.

The scanner should prefer precise cache directories over broad application data roots. For example, scan `~/Library/Application Support/Cursor/Cache`, not all of `~/Library/Application Support/Cursor`.

## CLI Behavior

Add:

```bash
python3 cleanup.py deep-clean --dry-run --i-understand deep-clean
python3 cleanup.py deep-clean --i-understand deep-clean
```

If the keyword is missing, print a clear no-op message and exit with status `2`, matching `fresh-start`.

Output should reuse the existing report rendering and action result summaries. JSON output should continue to describe findings, not mutate output structure unexpectedly.

## Testing

Use temp-directory fixtures only. Tests should cover:

- New scanner findings for browser, Safari, developer, professional app, AI/editor, and macOS generated caches.
- `deep-clean` requires the exact keyword.
- `deep-clean --dry-run` does not delete files.
- `deep-clean` removes actionable moderate findings but preserves high-risk and report-only findings.
- Command-backed actions are allowlisted and dry-run safe.
- Protected path refusals remain intact.
- Nested findings already removed by a parent action do not fail the run.

Run:

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile cleanup.py mac_clean/*.py
```

## Documentation

Update `README.md` to document:

- The difference between `clean`, `fresh-start`, and `deep-clean`.
- Recommended workflow: scan, deep-clean dry-run, then deep-clean.
- Which aggressive tricks are intentionally report-only.
- The expected consequences of clearing developer, browser, editor, and professional app caches.

## Acceptance Criteria

- `cleanup.py deep-clean --dry-run --i-understand deep-clean` reports actions without deleting files.
- `cleanup.py deep-clean --i-understand deep-clean` cleans selected safe and moderate findings.
- High-risk findings are still never automatically cleaned.
- Tests and syntax checks pass.
- README accurately reflects the new command and safety model.
