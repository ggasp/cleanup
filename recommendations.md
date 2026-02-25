Below is an expanded, more opinionated checklist, with concrete paths and commands, structured for a “deep clean” of disk + realistic performance gains.

Use sudo only where indicated. Anything touching rm -rf is destructive; adjust to your risk tolerance.

⸻

0. Safety / Baseline
	•	Fully updated macOS
	•	System Settings → General → Software Update.
	•	Backup snapshot
	•	Time Machine (external disk) or at minimum: clone key folders before doing rm -rf.
	•	Basic system health checks
	•	Disk health: diskutil list and diskutil verifyVolume /System/Volumes/Data
	•	Free space: df -h

⸻

1. Core System Cleanup (enhanced)

1.1 Time Machine local snapshots
	•	View local snapshots:

tmutil listlocalsnapshots /


	•	Delete all snapshots (loop):  ￼

for s in $(tmutil listlocalsnapshots / | sed 's/com.apple.TimeMachine.//'); do
  sudo tmutil deletelocalsnapshots "$s"
done


	•	GUI method (safer): disable “Back Up Automatically” in Time Machine settings; macOS will discard local snapshots when not needed. ￼

⸻

1.2 System and user cache files

Many caches are auto-managed, but large build-ups are safe to clear.
	•	User caches:

rm -rf ~/Library/Caches/*


	•	System-wide caches (more aggressive):

sudo rm -rf /Library/Caches/*
sudo rm -rf /System/Library/Caches/*  # Only if you know what you’re doing


	•	Safe-mode cache purge (Apple-approved): boot into Safe Mode once; macOS clears certain system caches automatically. ￼

⸻

1.3 Browser caches

For each browser (quit it first):
	•	Safari:

rm -rf ~/Library/Caches/com.apple.Safari
rm -rf ~/Library/Safari/Databases
rm -rf ~/Library/Safari/LocalStorage


	•	Chrome (and Chromium-based: Edge, Brave, Opera):

rm -rf ~/Library/Caches/Google/Chrome/*
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Code\ Cache/*
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker/CacheStorage/*

Adjust vendor prefix: ~/Library/Application Support/Microsoft Edge, ~/Library/Application Support/BraveSoftware, etc.

	•	Firefox:

rm -rf ~/Library/Caches/Firefox/*



⸻

1.4 Logs and temporary files
	•	User logs:

rm -rf ~/Library/Logs/*


	•	System logs (older ones):

sudo rm -rf /var/log/*

macOS will recreate needed logs.

	•	Temporary folders:

sudo rm -rf /private/var/tmp/*
sudo rm -rf /tmp/*



⸻

1.5 iOS device backups (huge space hog)
	•	Finder → select device → “Manage Backups…” and delete old ones. ￼
	•	Direct path:

open ~/Library/Application\ Support/MobileSync/Backup
# Then manually delete old device folders



⸻

1.6 Trash and “purgeable” space
	•	Empty Trash (all users if needed):

rm -rf ~/.Trash/*
sudo rm -rf /Users/*/.Trash/*


	•	Trigger some purgeable cleanup (indirect, but effective): use Apple’s “Manage Storage” → “Recommendations” to move files to iCloud / delete large files. ￼

(Tricks like filling the disk with dd or DMGs to force purgeable cleanup exist, but are hacky and not needed if you’re already doing the rest. ￼)

⸻

1.7 Inactive memory purge

On modern macOS memory management is already good; manual purge is rarely useful.
	•	Traditional command (works on some versions):

sudo purge



Better practical “memory optimization” is in section 5 (closing heavy apps, controlling login items, browser tabs).

⸻

2. Developer Tools Cleanup (extended)

2.1 Homebrew
	•	Update + cleanup: ￼

brew update
brew upgrade
brew cleanup        # removes old versions and cached downloads
brew cleanup --prune=all


	•	Optional: nuke all cached downloads (more aggressive):  ￼

rm -rf "$(brew --cache)"



⸻

2.2 Python (pip / conda)
	•	pip cache:

pip cache dir
pip cache purge


	•	Virtualenvs: delete old ones manually from where you store them (~/venvs, .venv, etc.).
	•	Conda (if used):

conda clean --all --yes  # removes package tarballs, index caches, etc.



⸻

2.3 Node.js package managers
	•	npm cache: ￼

npm cache clean --force
npm cache verify


	•	yarn cache: ￼

yarn cache dir          # see where it is
yarn cache clean        # clear it


	•	pnpm store/cache: ￼

pnpm store path         # inspect
pnpm store prune        # remove unreferenced packages


	•	bun global cache: ￼

bun pm cache            # show cache path
bun pm cache rm         # clear cache (per docs/issues)



⸻

2.4 Ruby, Rust, etc.
	•	Ruby gems:

gem env home           # gem dir
gem cleanup            # remove old gem versions


	•	Bundler cache:

bundle clean --force


	•	Rust / Cargo:

cargo cache -a         # if cargo-cache installed
# or manual:
rm -rf ~/.cargo/registry/*
rm -rf ~/.cargo/git/*



⸻

2.5 Xcode & iOS development (huge savings)
	•	DerivedData: ￼

rm -rf ~/Library/Developer/Xcode/DerivedData/*


	•	iOS DeviceSupport (symbol files for devices): ￼

open ~/Library/Developer/Xcode/iOS\ DeviceSupport
# delete old iOS versions you no longer need


	•	Watch/tvOS DeviceSupport similarly.
	•	Simulators (CoreSimulator Devices): ￼

xcrun simctl delete unavailable
rm -rf ~/Library/Developer/CoreSimulator/Devices/*


	•	Old platform runtimes via Xcode GUI: Xcode → Settings → Platforms/Components → remove old iOS/watchOS/tvOS versions (can be tens of GB). ￼

⸻

3. Professional Applications Cleanup

Adjust according to the apps you actually have.

3.1 Adobe Creative Cloud

Common cache locations (quit apps & CC first):

rm -rf ~/Library/Caches/Adobe/*
rm -rf ~/Library/Application\ Support/Adobe/Common/Media\ Cache\ Files/*
rm -rf ~/Library/Application\ Support/Adobe/Common/Media\ Cache/*

Use Adobe’s own “Media Cache Management” where available inside Premiere/After Effects.

⸻

3.2 Final Cut Pro / Logic Pro
	•	Final Cut Pro libraries: move or delete old .fcpbundle projects from your media drive.
	•	Render/cache:

rm -rf ~/Movies/Final\ Cut\ Pro\ Backups/*
rm -rf ~/Movies/Motion\ Templates/ # if unused


	•	Logic Pro: clean old project backups and bounce files in your project folders and:

rm -rf ~/Music/Audio\ Music\ Apps/Project\ Backups/*



⸻

3.3 Design tools (Sketch, Figma, etc.)

Typical examples:

rm -rf ~/Library/Caches/com.bohemiancoding.sketch3/*
rm -rf ~/Library/Application\ Support/Sketch/*
rm -rf ~/Library/Application\ Support/Figma/*
rm -rf ~/Library/Caches/Figma/*


⸻

3.4 3D / Game engines (Unity, Blender, etc.)
	•	Unity:

rm -rf ~/Library/Unity/Cache/*
rm -rf ~/Library/Unity/Asset\ Store-*

Clean per-project Library/ folders if you’re OK with reimports.

	•	Blender:

rm -rf ~/Library/Application\ Support/Blender/*/cache/*



⸻

4. Advanced System Cleanup

4.1 Docker: containers, images, cache
	•	Inspect usage:

docker system df


	•	Prune everything unused: ￼

docker system prune            # containers, networks, dangling images, build cache
docker system prune -a         # also removes unused images
docker volume prune            # orphaned volumes



⸻

4.2 Mail attachments and downloads

Mail app accumulates a lot of attachments.

open ~/Library/Containers/com.apple.mail/Data/Library/Mail\ Downloads
# delete contents as desired

Also clean ~/Downloads generally.

⸻

4.3 Font cache + QuickLook thumbnails
	•	Clear font caches (user only): ￼

atsutil databases -removeUser
# or to clear all font caches (system + user):
sudo atsutil databases -remove
atsutil server -shutdown
atsutil server -ping

Log out/in or reboot.

	•	QuickLook / Finder previews are mostly refreshed automatically; any heavy cleanup can be handled via regular cache clearing or a Safe Mode boot. ￼

⸻

4.4 Language localizations (.lproj)

For each large app bundle (do this only if you accept the risk):

cd /Applications
sudo find "AppName.app" -type d -name "*.lproj" ! -name "en.lproj" -maxdepth 3 -exec rm -rf {} +

This frees space but can break updates or localization; consider it “aggressive tuning”.

⸻

4.5 macOS / App Store update caches, installers
	•	Remove old macOS installers:

ls /Applications | grep "Install macOS"
sudo rm -rf "/Applications/Install macOS Sonoma.app"


	•	Remove large DMGs / PKGs in ~/Downloads and ~/Library/Updates.

⸻

4.6 Virtual machines and emulators

Scan typical locations:

open ~/Virtual\ Machines.localized
open ~/Parallels
open ~/Library/Application\ Support/VirtualBox
open ~/Library/Containers

Delete old VM images (.vdi, .vhdx, .qcow2, etc.) you no longer need.

⸻

4.7 Hibernation sleepimage (only if desperate for space)

/private/var/vm/sleepimage is usually equal to RAM size. It will be recreated; disabling safe sleep has trade-offs. ￼

Example:

sudo rm /private/var/vm/sleepimage
# It will come back after sleep; permanent disable requires pmset changes (not generally recommended).


⸻

4.8 Spotlight index optimization

If Spotlight is slow or bloated, rebuild index: ￼

sudo mdutil -i off /
sudo rm -rf /.Spotlight*
sudo mdutil -i on /
sudo mdutil -E /

Spotlight will reindex in background; performance often improves after.

⸻

4.9 Hidden user caches and Core Data / CloudKit junk

Look for large folders under:

open ~/Library/Application\ Support
open ~/Library/Group\ Containers
open ~/Library/Containers

Then selectively delete caches within specific apps you recognize (e.g., old chat histories, map caches, etc.).

⸻

5. Performance & Memory Tuning (non-disk, but high impact)

5.1 Login items / launch agents
	•	System Settings → General → Login Items: disable anything not essential.
	•	LaunchAgents / LaunchDaemons:

ls ~/Library/LaunchAgents
ls /Library/LaunchAgents
ls /Library/LaunchDaemons

Unload and remove entries you truly don’t need.

⸻

5.2 Background processes and menubar apps
	•	Activity Monitor → sort by CPU and Memory; remove permanently any menubar utilities you don’t use.
	•	Browsers: reduce tab count and disable heavy extensions.

⸻

5.3 iCloud Drive / Photos / cloud sync

Offload large, rarely used material to cloud-only state using the “Optimize Mac Storage” / iCloud options. ￼

This frees both disk and some background sync load.

⸻

5.4 Safe-mode one-time pass

One reboot in Safe Mode cleans system caches and can resolve performance regressions around certain updates. ￼

⸻

6. Disk Usage Recon / Large File Scanner

You already have “Large file scanner and suggestions”; make it concrete:
	•	GUI: Apple menu → About This Mac → Storage → Manage → “Reduce Clutter” to list large files and old documents. ￼
	•	Terminal: focus on your data volume:

# Top-level usage on data volume
sudo du -hxd 1 /System/Volumes/Data | sort -h

# Focus on your home
du -hxd 1 ~ | sort -h

# Drill into Library if big
du -hxd 1 ~/Library | sort -h

This tells you where the remaining GBs are hiding after the scripted cleanup.

⸻

This set turns your original checklist into a near-complete “deep clean playbook” for macOS: system caches, developer tooling, pro apps, heavy runtimes (Docker/Xcode/VMs), plus realistic performance levers (login items, Spotlight, cloud sync, Safe Mode).
