# Análisis de Seguridad del Script cleanup.sh

Fecha: 2026-01-28

## Resumen Ejecutivo

El script `cleanup.sh` es **generalmente seguro** para uso con confirmación del usuario, pero tiene algunas operaciones que podrían causar problemas en casos específicos. A continuación se detallan los hallazgos.

---

## ✅ Operaciones Seguras

Las siguientes operaciones son seguras y no deberían causar problemas:

| Operación | Líneas | Comentario |
|-----------|--------|------------|
| Eliminar snapshots Time Machine | 530-542 | macOS los regenera cuando necesita |
| Limpiar cachés de usuario | 584-587 | `~/Library/Caches` es seguro |
| Cachés de navegadores | 249-301 | Seguro, solo cierra sesiones web |
| Logs de usuario | 603 | `~/Library/Logs` es regenerable |
| Archivos temporales en `/tmp` | 621 | macOS los limpia automáticamente |
| Papelera | 662-670 | Operación estándar |
| Purga de memoria | 677-687 | Comando oficial de macOS |
| Docker cleanup | 712-727 | Usa comandos oficiales de Docker |
| Homebrew cleanup | 770-788 | Usa comandos oficiales de brew |
| DNS cache flush | 821-822 | Operación estándar y segura |

---

## ⚠️ Operaciones de Riesgo Moderado

### 1. Eliminación de `/Library/Caches/*` (Línea 580)

```bash
clean_cache_directory "System" "/Library/Caches"
```

**Riesgo**: Puede eliminar cachés de aplicaciones del sistema que tardarán en regenerarse.

**Recomendación**: Añadir exclusiones para:
- `/Library/Caches/com.apple.*` (cachés críticos de Apple)
- Mostrar advertencia más clara sobre el impacto

### 2. Eliminación de archivos temporales de usuario (Líneas 624-628)

```bash
find /private/var/folders -name "T" -type d 2>/dev/null | while read -r tempdir; do
    rm -rf "$tempdir"/* 2>/dev/null
done
```

**Riesgo**: Puede interrumpir aplicaciones en ejecución que usan archivos temporales.

**Recomendación**:
- Verificar que no hay procesos usando esos archivos
- Añadir lista de exclusión para procesos conocidos

### 3. Limpieza de Xcode iOS DeviceSupport (Línea 742)

```bash
[ -d "$XCODE_PATH/iOS DeviceSupport" ] && rm -rf "$XCODE_PATH/iOS DeviceSupport"/*
```

**Riesgo**: Elimina símbolos necesarios para debugging de dispositivos iOS.

**Recomendación**:
- Mantener al menos las últimas 2-3 versiones de iOS
- Avisar que se necesitará reconectar dispositivos para regenerar

---

## 🔴 Operaciones de Alto Riesgo

### 1. Eliminación de archivos Swap (Líneas 1346-1352)

```bash
rm -f /private/var/vm/swapfile* 2>/dev/null
```

**Riesgo ALTO**:
- Puede causar inestabilidad si hay presión de memoria
- Procesos pueden perder datos si están usando swap
- Requiere reinicio para efecto completo

**Recomendación**:
- Verificar uso de swap antes de eliminar: `sysctl vm.swapusage`
- Solo proceder si swap usado < 500MB
- Cerrar aplicaciones pesadas primero

### 2. Modificación de Hibernación (Líneas 1100-1108)

```bash
sudo pmset -a hibernatemode 0
sudo rm -f "$SLEEPIMAGE_PATH"
sudo touch "$SLEEPIMAGE_PATH"
sudo chflags uchg "$SLEEPIMAGE_PATH"
```

**Riesgo ALTO**:
- Si la batería se agota durante sleep, se perderá todo el trabajo no guardado
- El archivo bloqueado con `chflags uchg` impide que macOS lo regenere
- Afecta la funcionalidad de "Safe Sleep"

**Recomendación**:
- Solo para usuarios avanzados con alimentación constante
- Documentar claramente cómo revertir
- Considerar eliminar el `chflags uchg`

### 3. Eliminación de Localizaciones (Líneas 1148-1198)

```bash
find "$app" -type d -name "*.lproj" ! -name "en.lproj" ! -name "English.lproj" -maxdepth 5 -exec rm -rf {} +
```

**Riesgo ALTO**:
- Puede romper actualizaciones de aplicaciones
- Algunas apps verifican integridad y fallan
- App Store puede marcar apps como "dañadas"

**Recomendación**:
- Excluir aplicaciones de Apple (System apps)
- Usar herramientas como Monolingual que son más seguras
- Advertir que puede requerir reinstalar apps

### 4. Rebuild de Spotlight (Líneas 1066-1077)

```bash
sudo mdutil -i off /
sudo rm -rf /.Spotlight-V100
sudo mdutil -i on /
```

**Riesgo MODERADO-ALTO**:
- El reindexado puede tomar horas
- Alto uso de CPU durante el proceso
- Búsquedas no funcionarán correctamente hasta completar

**Recomendación**:
- Avisar del tiempo estimado (2-6 horas dependiendo del disco)
- Sugerir hacerlo durante la noche

---

## 🚫 Operaciones que NUNCA deben incluirse

El script actual NO incluye estas operaciones peligrosas (verificado):

| Operación Peligrosa | Estado |
|---------------------|--------|
| `rm -rf /System/*` | ✅ No incluido |
| `rm -rf /System/Library/Caches/*` | ✅ No incluido |
| `rm -rf /usr/*` | ✅ No incluido |
| `rm -rf /private/var/db/*` | ✅ No incluido |
| `rm -rf ~/Library/Preferences/*` | ✅ No incluido |
| `rm -rf ~/Library/Application Support/*` | ✅ No incluido |
| Modificación de archivos de boot | ✅ No incluido |

---

## Mejoras de Seguridad Sugeridas

### 1. Añadir verificación de procesos activos

```bash
check_active_processes() {
    local path="$1"
    if lsof +D "$path" 2>/dev/null | grep -q .; then
        echo -e "${RED}Warning: Files in $path are in use by running processes${NC}"
        return 1
    fi
    return 0
}
```

### 2. Añadir dry-run mode

```bash
DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "Running in DRY RUN mode - no changes will be made"
fi
```

### 3. Crear backup de configuración antes de cambios

```bash
backup_config() {
    local backup_dir="$USER_HOME/.cleanup_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    # Backup critical plist files, etc.
}
```

### 4. Añadir rollback para operaciones de pmset

```bash
# Guardar configuración actual antes de cambiar
ORIGINAL_HIBERNATE=$(pmset -g | grep hibernatemode | awk '{print $2}')
echo "Original hibernatemode: $ORIGINAL_HIBERNATE" >> "$LOG_FILE"
```

---

## Directorios que NUNCA deben eliminarse

| Directorio | Razón |
|------------|-------|
| `/System/` | Archivos del sistema operativo |
| `/usr/` | Binarios y librerías del sistema |
| `/private/var/db/` | Bases de datos del sistema |
| `/Library/Preferences/` | Configuración global del sistema |
| `~/Library/Preferences/*.plist` | Configuración de aplicaciones |
| `~/Library/Application Support/` (completo) | Datos de aplicaciones |
| `~/Library/Keychains/` | Contraseñas y certificados |
| `/private/var/protected/` | Archivos protegidos por SIP |

---

## Conclusión

El script es **seguro para uso general** con las siguientes condiciones:

1. El usuario debe leer y confirmar cada operación
2. Las operaciones de "double confirm" están correctamente implementadas para las acciones más agresivas
3. Se recomienda implementar las mejoras sugeridas para mayor seguridad

**Calificación de Seguridad**: 7/10 (Bueno, con margen de mejora)
