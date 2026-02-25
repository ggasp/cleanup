# Nuevas Técnicas de Limpieza para macOS (2025-2026)

Basado en investigación de Apple Support, MacRumors, Reddit y comunidades de desarrolladores.

---

## 1. Videos de Pantalla de Bloqueo (Sonoma/Sequoia) - HASTA 45GB

**Ubicación**: `/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS/`

Los videos 4K de los fondos de pantalla animados y salvapantallas aéreos pueden ocupar entre **10-45GB**.

### Cómo limpiar:

```bash
# Ver tamaño actual
du -sh "/Library/Application Support/com.apple.idleassetsd/Customer/"

# Eliminar videos (requiere sudo)
sudo rm -rf "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS/"*
```

### Prevenir re-descarga:

1. Ir a **System Settings > Wallpaper** y seleccionar una imagen estática
2. Ir a **System Settings > Screen Saver** y sincronizar con el wallpaper estático
3. Eliminar también:
   - `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`
   - `/Library/Application Support/com.apple.idleassetsd/TVIdleScreenSnapshotLog.plist`

### Código sugerido para el script:

```bash
# Screen Saver/Wallpaper Videos (macOS Sonoma/Sequoia)
print_section "🎬 Aerial Videos & Dynamic Wallpapers"
AERIAL_PATH="/Library/Application Support/com.apple.idleassetsd/Customer"
if [ -d "$AERIAL_PATH" ]; then
    AERIAL_SIZE=$(calculate_size "$AERIAL_PATH")
    echo -e "Aerial/Wallpaper videos: ${BOLD}${AERIAL_SIZE}${NC}"
    echo -e "${YELLOW}Note: These are 4K videos for screen savers and dynamic wallpapers.${NC}"

    if confirm "Delete aerial videos? They will re-download if dynamic wallpaper is active."; then
        sudo rm -rf "$AERIAL_PATH/4KSDR240FPS"/* 2>/dev/null
        echo -e "${GREEN}Aerial videos deleted.${NC}"
        echo -e "${CYAN}Tip: Set a static wallpaper to prevent re-download.${NC}"
    fi
fi
```

---

## 2. Cachés Adicionales de Safari

**Ubicaciones adicionales no cubiertas**:
- `~/Library/Safari/Databases/` - Bases de datos de sitios web
- `~/Library/Safari/LocalStorage/` - Almacenamiento local de sitios

### Código sugerido:

```bash
# Safari additional storage
SAFARI_EXTRA_PATHS=(
    "$USER_HOME/Library/Safari/Databases"
    "$USER_HOME/Library/Safari/LocalStorage"
    "$USER_HOME/Library/Safari/WebsiteData"
)

for path in "${SAFARI_EXTRA_PATHS[@]}"; do
    if [ -d "$path" ]; then
        size=$(calculate_size "$path")
        echo -e "$(basename "$path"): ${BOLD}${size}${NC}"
    fi
done
```

---

## 3. Cachés Adicionales de Chrome/Chromium

**Ubicaciones importantes no cubiertas**:
- `~/Library/Application Support/Google/Chrome/Default/Code Cache/`
- `~/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage/`
- `~/Library/Application Support/Google/Chrome/Default/GPUCache/`

### Para otros navegadores Chromium:

```bash
CHROMIUM_BROWSERS=(
    "Google/Chrome"
    "Microsoft Edge"
    "BraveSoftware/Brave-Browser"
    "Vivaldi"
)

for browser in "${CHROMIUM_BROWSERS[@]}"; do
    BROWSER_PATH="$USER_HOME/Library/Application Support/$browser"
    if [ -d "$BROWSER_PATH" ]; then
        rm -rf "$BROWSER_PATH"/*/Code\ Cache/* 2>/dev/null
        rm -rf "$BROWSER_PATH"/*/Service\ Worker/CacheStorage/* 2>/dev/null
        rm -rf "$BROWSER_PATH"/*/GPUCache/* 2>/dev/null
    fi
done
```

---

## 4. Mail Downloads (Ubicación Correcta)

La ubicación correcta en macOS moderno es diferente:

```bash
# Ubicación correcta para macOS Sonoma+
MAIL_DOWNLOADS="$USER_HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"

if [ -d "$MAIL_DOWNLOADS" ]; then
    MAIL_SIZE=$(calculate_size "$MAIL_DOWNLOADS")
    echo -e "Mail Downloads: ${BOLD}${MAIL_SIZE}${NC}"
fi
```

---

## 5. Eliminación Segura de Time Machine Snapshots (Método Mejorado)

El comando actual puede fallar. Método más robusto:

```bash
# Método mejorado para eliminar snapshots
delete_tm_snapshots() {
    echo "Deleting Time Machine local snapshots..."

    # Método 1: Por fecha
    for snapshot in $(tmutil listlocalsnapshotdates / 2>/dev/null); do
        echo "  Deleting snapshot from: $snapshot"
        tmutil deletelocalsnapshots "$snapshot" 2>/dev/null
    done

    # Método 2: Forzar thin (más agresivo)
    tmutil thinlocalsnapshots / 999999999999 1 2>/dev/null
}
```

---

## 6. Sistema de Datos ("System Data") - Técnicas Específicas

El "System Data" en macOS puede crecer a 50-100GB. Componentes principales:

### 6.1 APFS Snapshots (además de Time Machine)

```bash
# Listar snapshots APFS
diskutil apfs listSnapshots /

# Eliminar por UUID
diskutil apfs deleteSnapshot / -uuid "UUID_AQUI"
```

### 6.2 Logs de diagnóstico del sistema

```bash
# Ubicaciones de logs pesados
DIAG_PATHS=(
    "/Library/Logs/DiagnosticReports"
    "$USER_HOME/Library/Logs/DiagnosticReports"
    "/private/var/log/asl"
    "/private/var/log/DiagnosticMessages"
)
```

### 6.3 Caché de actualizaciones de software

```bash
# Limpiar catálogo de actualizaciones
sudo softwareupdate --clear-catalog

# Eliminar actualizaciones descargadas
sudo rm -rf /Library/Updates/*
```

---

## 7. Deno Cache (Nuevo Runtime JS)

Si usas Deno (alternativa a Node.js):

```bash
DENO_CACHE="$USER_HOME/.cache/deno"
if [ -d "$DENO_CACHE" ]; then
    deno cache --reload 2>/dev/null || rm -rf "$DENO_CACHE"/*
fi
```

---

## 8. Claude Code / AI Tools Cache

Para usuarios de herramientas de IA:

```bash
AI_CACHES=(
    "$USER_HOME/.claude"
    "$USER_HOME/.cursor"
    "$USER_HOME/.continue"
    "$USER_HOME/Library/Application Support/Cursor"
    "$USER_HOME/Library/Application Support/Claude"
)

for cache in "${AI_CACHES[@]}"; do
    if [ -d "$cache/cache" ]; then
        size=$(calculate_size "$cache/cache")
        echo -e "$(basename "$cache") cache: ${BOLD}${size}${NC}"
    fi
done
```

---

## 9. Containers de Aplicaciones Sandboxed

macOS guarda datos de apps sandboxed que pueden persistir después de desinstalar:

```bash
# Escanear containers huérfanos
echo "Scanning for potentially orphaned containers..."

for container in "$USER_HOME/Library/Containers"/*; do
    if [ -d "$container" ]; then
        app_id=$(basename "$container")
        # Verificar si la app existe
        if ! mdfind "kMDItemCFBundleIdentifier == '$app_id'" 2>/dev/null | grep -q .; then
            size=$(calculate_size "$container")
            echo -e "  Orphaned: ${BOLD}$app_id${NC} - $size"
        fi
    fi
done
```

---

## 10. Optimización de Fotos (iCloud Photos)

```bash
# Verificar uso de Photos Library
PHOTOS_LIB="$USER_HOME/Pictures/Photos Library.photoslibrary"
if [ -d "$PHOTOS_LIB" ]; then
    PHOTOS_SIZE=$(calculate_size "$PHOTOS_LIB")
    echo -e "Photos Library: ${BOLD}${PHOTOS_SIZE}${NC}"
    echo -e "${CYAN}Tip: Enable 'Optimize Mac Storage' in Photos settings to save space.${NC}"
fi
```

---

## 11. Limpieza de MobileDevice (iTunes/Finder Sync)

```bash
# Logs de sincronización de dispositivos
MOBILE_LOGS=(
    "$USER_HOME/Library/Logs/MobileDevice"
    "/Library/Logs/MobileDevice"
)

for log_path in "${MOBILE_LOGS[@]}"; do
    if [ -d "$log_path" ]; then
        rm -rf "$log_path"/* 2>/dev/null
    fi
done
```

---

## 12. Herramientas de Terceros Recomendadas

Basado en recomendaciones de la comunidad (Reddit/MacRumors):

| Herramienta | Uso | Seguridad |
|-------------|-----|-----------|
| **DaisyDisk** | Visualización de disco | Alta |
| **OmniDiskSweeper** | Escaneo de archivos grandes | Alta |
| **AppCleaner** | Desinstalación completa de apps | Alta |
| **Monolingual** | Eliminación de localizaciones | Media |
| **CleanMyMac X** | Limpieza general | Media (verificar permisos) |

---

## Fuentes

- [Apple Support - Free up storage space](https://support.apple.com/en-us/102624)
- [MacRumors Forums - Aerial wallpapers](https://forums.macrumors.com/threads/how-to-remove-downloaded-aerial-wallpapers.2392675/)
- [macOS Daily - Sonoma wallpaper location](https://osxdaily.com/2023/10/27/location-of-macos-sonoma-moving-wallpapers-aerial-screen-savers/)
- [DrBuho - System Data cleanup](https://www.drbuho.com/how-to/clear-system-storage-mac)
- [MacPaw - Clear system storage](https://macpaw.com/how-to/clear-system-storage-mac)
