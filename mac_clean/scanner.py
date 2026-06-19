from __future__ import annotations

import fnmatch
import os
from dataclasses import dataclass
from pathlib import Path

from .models import Finding, RiskLevel, ScanReport


@dataclass(frozen=True)
class ScanConfig:
    home: Path = Path.home()
    system_root: Path = Path("/")
    min_size: int = 0
    large_file_threshold: int = 1024 * 1024 * 1024


def directory_size(path: Path) -> int:
    if not path.exists():
        return 0
    if path.is_file() or path.is_symlink():
        return _file_size(path)

    total = 0
    for root, dirs, files in os.walk(path, onerror=lambda _error: None):
        root_path = Path(root)
        kept_dirs = []
        for dirname in dirs:
            child = root_path / dirname
            if not child.is_symlink():
                kept_dirs.append(dirname)
        dirs[:] = kept_dirs
        for filename in files:
            total += _file_size(root_path / filename)
    return total


def directory_size_excluding(path: Path, exclude_paths: tuple[Path, ...]) -> int:
    if not exclude_paths:
        return directory_size(path)
    if not path.exists():
        return 0
    if path.is_file() or path.is_symlink():
        return 0 if _is_excluded(path, exclude_paths) else _file_size(path)

    total = 0
    for root, dirs, files in os.walk(path, onerror=lambda _error: None):
        root_path = Path(root)
        kept_dirs = []
        for dirname in dirs:
            child = root_path / dirname
            if child.is_symlink() or _is_excluded(child, exclude_paths):
                continue
            kept_dirs.append(dirname)
        dirs[:] = kept_dirs
        if _is_excluded(root_path, exclude_paths):
            continue
        for filename in files:
            child = root_path / filename
            if not _is_excluded(child, exclude_paths):
                total += _file_size(child)
    return total


def scan(config: ScanConfig | None = None) -> ScanReport:
    config = config or ScanConfig()
    home = config.home.expanduser()
    root = config.system_root
    findings: list[Finding] = []
    appstore_cache_paths = (home / "Library" / "Caches" / "com.apple.appstore",)
    user_log_report_paths = (
        home / "Library" / "Logs" / "DiagnosticReports",
        home / "Library" / "Logs" / "CrashReporter",
    )

    _add_path_finding(
        findings,
        category="Cleanup",
        title="Trash",
        path=home / ".Trash",
        risk=RiskLevel.SAFE,
        action="clean-trash",
        detail="Files already moved to the current user's Trash.",
    )
    _add_path_finding(
        findings,
        category="Caches",
        title="User caches",
        path=home / "Library" / "Caches",
        risk=RiskLevel.SAFE,
        action=None if _any_path_exists(appstore_cache_paths) else "clean-user-caches",
        detail="Regenerable app cache files. Apps may be slower on first launch after cleanup.",
        exclude_paths=appstore_cache_paths,
    )
    _add_path_finding(
        findings,
        category="Logs",
        title="User logs",
        path=home / "Library" / "Logs",
        risk=RiskLevel.SAFE,
        action=None if _any_path_exists(user_log_report_paths) else "clean-directory-contents",
        detail="Regenerable user-level logs and diagnostic output.",
        exclude_paths=user_log_report_paths,
    )
    _add_safari_storage(findings, home)
    _add_generated_macos_storage(findings, home, root)
    _add_browser_runtime_caches(findings, home)
    _add_package_manager_caches(findings, home)
    _add_grouped_files(
        findings,
        category="Downloads",
        title="Downloads installers",
        base=home / "Downloads",
        patterns=("*.dmg", "*.pkg", "*.iso", "Install macOS*.app"),
        risk=RiskLevel.MODERATE,
        action="remove-download-installers",
        detail="Installer files are often safe to remove after installation, but review them first.",
    )
    _add_path_finding(
        findings,
        category="Mail",
        title="Mail downloads",
        path=home / "Library" / "Containers" / "com.apple.mail" / "Data" / "Library" / "Mail Downloads",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Attachments cached by Mail. Original messages remain in the mailbox.",
    )
    _add_path_finding(
        findings,
        category="Backups",
        title="iOS device backups",
        path=home / "Library" / "Application Support" / "MobileSync" / "Backup",
        risk=RiskLevel.HIGH,
        action=None,
        detail="Deleting these removes local iPhone/iPad restore points.",
    )
    _add_path_finding(
        findings,
        category="Developer",
        title="Xcode DerivedData",
        path=home / "Library" / "Developer" / "Xcode" / "DerivedData",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Rebuildable Xcode build artifacts.",
    )
    _add_path_finding(
        findings,
        category="Developer",
        title="Xcode iOS DeviceSupport",
        path=home / "Library" / "Developer" / "Xcode" / "iOS DeviceSupport",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Device symbols for debugging. Xcode can recreate needed data when devices reconnect.",
    )
    _add_path_finding(
        findings,
        category="Developer",
        title="CoreSimulator caches",
        path=home / "Library" / "Developer" / "CoreSimulator" / "Caches",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Rebuildable simulator cache files.",
    )
    _add_path_finding(
        findings,
        category="Developer",
        title="Homebrew cache",
        path=home / "Library" / "Caches" / "Homebrew",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Use brew cleanup for the most accurate cleanup.",
    )
    _add_path_finding(
        findings,
        category="Media",
        title="Aerial and wallpaper videos",
        path=root / "Library" / "Application Support" / "com.apple.idleassetsd" / "Customer",
        risk=RiskLevel.MODERATE,
        action="clean-directory-contents",
        detail="Downloaded dynamic wallpaper and screen saver videos. macOS may re-download them.",
    )
    _add_path_finding(
        findings,
        category="Containers",
        title="Docker desktop data",
        path=home / "Library" / "Containers" / "com.docker.docker" / "Data",
        risk=RiskLevel.MODERATE,
        action=None,
        detail="Use Docker prune commands or Docker Desktop to review containers, images, volumes, and build cache.",
    )
    _add_system_path_finding(
        findings,
        category="System",
        title="macOS update cache",
        path=root / "Library" / "Updates",
        risk=RiskLevel.MODERATE,
        detail="Downloaded update payloads. macOS may re-download them if needed.",
    )
    _add_project_dependencies(findings, home=home)
    _add_large_files(findings, home=home, threshold=config.large_file_threshold)

    return ScanReport(findings=findings).filtered(config.min_size)


def _file_size(path: Path) -> int:
    try:
        return path.lstat().st_size
    except OSError:
        return 0


def _is_excluded(path: Path, exclude_paths: tuple[Path, ...]) -> bool:
    try:
        resolved = path.resolve(strict=False)
    except OSError:
        resolved = path.absolute()
    for exclude_path in exclude_paths:
        try:
            exclude_resolved = exclude_path.resolve(strict=False)
        except OSError:
            exclude_resolved = exclude_path.absolute()
        if resolved == exclude_resolved or exclude_resolved in resolved.parents:
            return True
    return False


def _any_path_exists(paths: tuple[Path, ...]) -> bool:
    return any(path.exists() for path in paths)


def _add_path_finding(
    findings: list[Finding],
    *,
    category: str,
    title: str,
    path: Path,
    risk: RiskLevel,
    action: str | None,
    detail: str,
    exclude_paths: tuple[Path, ...] = (),
) -> None:
    size = directory_size_excluding(path, exclude_paths)
    if size <= 0:
        return
    findings.append(Finding(category, title, str(path), size, risk, action, detail))


def _add_system_path_finding(
    findings: list[Finding],
    *,
    category: str,
    title: str,
    path: Path,
    risk: RiskLevel,
    detail: str,
) -> None:
    _add_path_finding(
        findings,
        category=category,
        title=title,
        path=path,
        risk=risk,
        action=None,
        detail=detail,
    )


def _add_grouped_files(
    findings: list[Finding],
    *,
    category: str,
    title: str,
    base: Path,
    patterns: tuple[str, ...],
    risk: RiskLevel,
    action: str | None,
    detail: str,
) -> None:
    if not base.exists():
        return
    total = 0
    count = 0
    for path in base.iterdir():
        if any(fnmatch.fnmatch(path.name, pattern) for pattern in patterns):
            total += directory_size(path)
            count += 1
    if total <= 0:
        return
    findings.append(
        Finding(
            category=category,
            title=title,
            path=str(base),
            bytes_reclaimable=total,
            risk=risk,
            action=action,
            detail=f"{detail} Matched {count} item(s).",
        )
    )


def _add_browser_runtime_caches(findings: list[Finding], home: Path) -> None:
    browser_roots = (
        ("Chrome", home / "Library" / "Application Support" / "Google" / "Chrome"),
        ("Edge", home / "Library" / "Application Support" / "Microsoft Edge"),
        ("Brave", home / "Library" / "Application Support" / "BraveSoftware" / "Brave-Browser"),
        ("Vivaldi", home / "Library" / "Application Support" / "Vivaldi"),
        ("Arc", home / "Library" / "Application Support" / "Arc"),
        ("Opera", home / "Library" / "Application Support" / "com.operasoftware.Opera"),
    )
    cache_patterns = (
        ("Code Cache", "*/Code Cache"),
        ("GPUCache", "*/GPUCache"),
        ("Service Worker CacheStorage", "*/Service Worker/CacheStorage"),
    )
    for browser_name, browser_root in browser_roots:
        if not browser_root.exists():
            continue
        for cache_name, pattern in cache_patterns:
            for path in browser_root.glob(pattern):
                _add_path_finding(
                    findings,
                    category="Browsers",
                    title=f"{browser_name} {cache_name}",
                    path=path,
                    risk=RiskLevel.MODERATE,
                    action="clean-directory-contents",
                    detail="Runtime browser cache. Sites and web apps rebuild it as needed.",
                )


def _add_safari_storage(findings: list[Finding], home: Path) -> None:
    paths = (
        ("Safari Databases", home / "Library" / "Safari" / "Databases"),
        ("Safari LocalStorage", home / "Library" / "Safari" / "LocalStorage"),
        ("Safari WebsiteData", home / "Library" / "Safari" / "WebsiteData"),
    )
    for title, path in paths:
        _add_path_finding(
            findings,
            category="Browsers",
            title=title,
            path=path,
            risk=RiskLevel.MODERATE,
            action="clean-directory-contents",
            detail="Safari website storage. Sites may need to re-cache data or sign in again.",
        )


def _add_generated_macos_storage(findings: list[Finding], home: Path, root: Path) -> None:
    paths = (
        ("Diagnostic reports", home / "Library" / "Logs" / "DiagnosticReports", RiskLevel.SAFE),
        ("Crash reports", home / "Library" / "Logs" / "CrashReporter", RiskLevel.SAFE),
        ("App Store cache", home / "Library" / "Caches" / "com.apple.appstore", RiskLevel.MODERATE),
        ("Software Update cache", root / "Library" / "Caches" / "com.apple.SoftwareUpdate", RiskLevel.MODERATE),
    )
    for title, path, risk in paths:
        _add_path_finding(
            findings,
            category="System",
            title=title,
            path=path,
            risk=risk,
            action="clean-directory-contents",
            detail="Generated macOS storage. macOS may recreate this data when needed.",
        )


def _add_package_manager_caches(findings: list[Finding], home: Path) -> None:
    paths = (
        ("npm cache", home / ".npm" / "_cacache"),
        ("Yarn cache", home / ".yarn" / "cache"),
        ("pnpm store", home / ".pnpm-store"),
        ("Bun cache", home / ".bun" / "install" / "cache"),
        ("pip cache", home / ".cache" / "pip"),
        ("Poetry cache", home / "Library" / "Caches" / "pypoetry"),
        ("Gradle cache", home / ".gradle" / "caches"),
        ("Maven repository", home / ".m2" / "repository"),
        ("Cargo registry cache", home / ".cargo" / "registry" / "cache"),
        ("Cargo git cache", home / ".cargo" / "git"),
        ("Rustup downloads", home / ".rustup" / "downloads"),
        ("Deno cache", home / ".cache" / "deno"),
    )
    for title, path in paths:
        _add_path_finding(
            findings,
            category="Developer",
            title=title,
            path=path,
            risk=RiskLevel.MODERATE,
            action="clean-directory-contents",
            detail="Package manager cache. Reinstalling dependencies may need network downloads.",
        )


def _add_project_dependencies(findings: list[Finding], *, home: Path) -> None:
    scan_roots = (
        home / "Developer",
        home / "Projects",
        home / "Workspace",
        home / "Documents",
        home / "Desktop",
    )
    dependency_dirs = {"node_modules"}
    for scan_root in scan_roots:
        if not scan_root.exists():
            continue
        for root, dirs, _files in os.walk(scan_root, onerror=lambda _error: None):
            root_path = Path(root)
            kept_dirs = []
            for dirname in dirs:
                path = root_path / dirname
                if path.is_symlink():
                    continue
                if dirname in dependency_dirs:
                    _add_path_finding(
                        findings,
                        category="Developer",
                        title="Project dependencies",
                        path=path,
                        risk=RiskLevel.MODERATE,
                        action="remove-path",
                        detail="Reinstallable project dependencies. Run the package manager again before working in this project.",
                    )
                    continue
                kept_dirs.append(dirname)
            dirs[:] = kept_dirs


def _add_large_files(findings: list[Finding], *, home: Path, threshold: int) -> None:
    if not home.exists():
        return
    scan_roots = [home / "Downloads", home / "Desktop", home / "Documents", home / "Movies"]
    total = 0
    count = 0
    examples: list[str] = []
    for scan_root in scan_roots:
        if not scan_root.exists():
            continue
        for root, dirs, files in os.walk(scan_root, onerror=lambda _error: None):
            dirs[:] = [dirname for dirname in dirs if not (Path(root) / dirname).is_symlink()]
            for filename in files:
                path = Path(root) / filename
                size = _file_size(path)
                if size >= threshold:
                    total += size
                    count += 1
                    if len(examples) < 5:
                        examples.append(str(path))
    if total <= 0:
        return
    detail = f"{count} file(s) larger than threshold."
    if examples:
        detail += " Examples: " + "; ".join(examples)
    findings.append(
        Finding(
            category="Large files",
            title="Large files",
            path=str(home),
            bytes_reclaimable=total,
            risk=RiskLevel.MODERATE,
            action=None,
            detail=detail,
        )
    )
