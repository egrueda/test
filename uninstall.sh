#!/bin/bash

################################################################################
# Script de Desinstalación - Security Audit
#
# Desinstala el sistema de auditoría de seguridad
#
# Uso: sudo ./uninstall.sh
################################################################################

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constantes
readonly INSTALL_DIR="/opt/security-audit"
readonly CONFIG_DIR="/etc/security-audit"
readonly LOG_DIR="/var/log/security-audit"
readonly LIB_DIR="/var/lib/security-audit"
readonly CRON_FILE="/etc/cron.d/security-audit"
readonly LOGROTATE_FILE="/etc/logrotate.d/security-audit"

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

die() {
    log_error "$@"
    exit 1
}

# Banner
show_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Security Audit - Script de Desinstalación                  ║
║                    Versión 1.0.0                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
}

# Verificar que se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Este script debe ejecutarse como root. Use: sudo $0"
    fi
}

# Detectar qué componentes están instalados
detect_installed_components() {
    log_info "Detectando componentes instalados..."
    echo ""

    local found_something=false

    if [[ -d "$INSTALL_DIR" ]]; then
        echo "  ✓ Directorio de instalación: $INSTALL_DIR"
        found_something=true
    fi

    if [[ -d "$CONFIG_DIR" ]]; then
        echo "  ✓ Directorio de configuración: $CONFIG_DIR"
        found_something=true
    fi

    if [[ -d "$LOG_DIR" ]]; then
        echo "  ✓ Directorio de logs: $LOG_DIR"
        found_something=true
    fi

    if [[ -d "$LIB_DIR" ]]; then
        echo "  ✓ Directorio de datos: $LIB_DIR"
        found_something=true
    fi

    if [[ -f "$CRON_FILE" ]]; then
        echo "  ✓ Tarea cron: $CRON_FILE"
        found_something=true
    fi

    if [[ -f "$LOGROTATE_FILE" ]]; then
        echo "  ✓ Configuración logrotate: $LOGROTATE_FILE"
        found_something=true
    fi

    echo ""

    if [[ "$found_something" == false ]]; then
        log_warn "No se encontraron componentes instalados"
        echo ""
        read -p "¿Desea continuar de todas formas? [y/N]: " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            log_info "Desinstalación cancelada"
            exit 0
        fi
    fi
}

# Calcular tamaño de directorios
calculate_sizes() {
    log_info "Calculando espacio a liberar..."
    echo ""

    local total_size=0

    if [[ -d "$INSTALL_DIR" ]]; then
        local size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo "  $INSTALL_DIR: $size"
        total_size=$((total_size + $(du -sb "$INSTALL_DIR" 2>/dev/null | cut -f1)))
    fi

    if [[ -d "$CONFIG_DIR" ]]; then
        local size=$(du -sh "$CONFIG_DIR" 2>/dev/null | cut -f1)
        echo "  $CONFIG_DIR: $size"
        total_size=$((total_size + $(du -sb "$CONFIG_DIR" 2>/dev/null | cut -f1)))
    fi

    if [[ -d "$LOG_DIR" ]]; then
        local size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
        echo "  $LOG_DIR: $size"
        total_size=$((total_size + $(du -sb "$LOG_DIR" 2>/dev/null | cut -f1)))
    fi

    if [[ -d "$LIB_DIR" ]]; then
        local size=$(du -sh "$LIB_DIR" 2>/dev/null | cut -f1)
        echo "  $LIB_DIR: $size"
        total_size=$((total_size + $(du -sb "$LIB_DIR" 2>/dev/null | cut -f1)))
    fi

    # Convertir bytes a formato legible
    local total_human
    if [[ $total_size -gt 1073741824 ]]; then
        total_human="$(awk "BEGIN {printf \"%.2f\", $total_size/1073741824}")G"
    elif [[ $total_size -gt 1048576 ]]; then
        total_human="$(awk "BEGIN {printf \"%.2f\", $total_size/1048576}")M"
    elif [[ $total_size -gt 1024 ]]; then
        total_human="$(awk "BEGIN {printf \"%.2f\", $total_size/1024}")K"
    else
        total_human="${total_size}B"
    fi

    echo ""
    log_info "Espacio total a liberar: $total_human"
    echo ""
}

# Ofrecer backup
offer_backup() {
    log_info "¿Desea hacer backup antes de desinstalar?"
    echo ""
    echo "Se puede hacer backup de:"
    echo "  1. Configuración ($CONFIG_DIR)"
    echo "  2. Logs e informes ($LOG_DIR)"
    echo "  3. Datos ($LIB_DIR)"
    echo "  4. Todo lo anterior"
    echo "  5. No hacer backup"
    echo ""
    read -p "Seleccione una opción [1-5]: " backup_option

    case "$backup_option" in
        1|2|3|4)
            local backup_dir
            read -p "Directorio para el backup [~/security-audit-backup]: " backup_dir
            backup_dir=${backup_dir:-~/security-audit-backup}

            # Expandir ~ si es necesario
            backup_dir="${backup_dir/#\~/$HOME}"

            log_info "Creando backup en: $backup_dir"
            mkdir -p "$backup_dir"

            local timestamp=$(date +%Y%m%d_%H%M%S)

            case "$backup_option" in
                1)
                    if [[ -d "$CONFIG_DIR" ]]; then
                        cp -r "$CONFIG_DIR" "$backup_dir/config-$timestamp" 2>/dev/null || true
                        log_success "Backup de configuración creado"
                    fi
                    ;;
                2)
                    if [[ -d "$LOG_DIR" ]]; then
                        cp -r "$LOG_DIR" "$backup_dir/logs-$timestamp" 2>/dev/null || true
                        log_success "Backup de logs creado"
                    fi
                    ;;
                3)
                    if [[ -d "$LIB_DIR" ]]; then
                        cp -r "$LIB_DIR" "$backup_dir/lib-$timestamp" 2>/dev/null || true
                        log_success "Backup de datos creado"
                    fi
                    ;;
                4)
                    [[ -d "$CONFIG_DIR" ]] && cp -r "$CONFIG_DIR" "$backup_dir/config-$timestamp" 2>/dev/null || true
                    [[ -d "$LOG_DIR" ]] && cp -r "$LOG_DIR" "$backup_dir/logs-$timestamp" 2>/dev/null || true
                    [[ -d "$LIB_DIR" ]] && cp -r "$LIB_DIR" "$backup_dir/lib-$timestamp" 2>/dev/null || true
                    log_success "Backup completo creado en: $backup_dir"
                    ;;
            esac
            echo ""
            ;;
        5)
            log_warn "No se creará backup"
            echo ""
            ;;
        *)
            log_warn "Opción inválida, no se creará backup"
            echo ""
            ;;
    esac
}

# Confirmación final
final_confirmation() {
    log_warn "═══════════════════════════════════════════════════════════"
    log_warn "  ADVERTENCIA: Esta acción NO se puede deshacer"
    log_warn "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Se eliminarán los siguientes componentes:"
    [[ -f "$CRON_FILE" ]] && echo "  • Tarea cron programada"
    [[ -f "$LOGROTATE_FILE" ]] && echo "  • Configuración de rotación de logs"
    [[ -d "$INSTALL_DIR" ]] && echo "  • Scripts de auditoría"
    [[ -d "$CONFIG_DIR" ]] && echo "  • Archivos de configuración"
    [[ -d "$LOG_DIR" ]] && echo "  • Logs e informes históricos"
    [[ -d "$LIB_DIR" ]] && echo "  • Datos y estado"
    echo ""

    read -p "¿Está SEGURO de que desea desinstalar Security Audit? [y/N]: " final_confirm

    if [[ ! $final_confirm =~ ^[Yy]$ ]]; then
        log_info "Desinstalación cancelada por el usuario"
        exit 0
    fi

    echo ""
    log_warn "Iniciando desinstalación en 3 segundos... (Ctrl+C para cancelar)"
    sleep 3
}

# Realizar la desinstalación
perform_uninstall() {
    log_info "Iniciando desinstalación..."
    echo ""

    # Eliminar cron
    if [[ -f "$CRON_FILE" ]]; then
        rm -f "$CRON_FILE"
        log_success "Tarea cron eliminada"
    fi

    # Eliminar logrotate
    if [[ -f "$LOGROTATE_FILE" ]]; then
        rm -f "$LOGROTATE_FILE"
        log_success "Configuración de logrotate eliminada"
    fi

    # Eliminar directorios
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log_success "Directorio de instalación eliminado"
    fi

    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        log_success "Directorio de configuración eliminado"
    fi

    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        log_success "Directorio de logs eliminado"
    fi

    if [[ -d "$LIB_DIR" ]]; then
        rm -rf "$LIB_DIR"
        log_success "Directorio de datos eliminado"
    fi

    echo ""
    log_success "═══════════════════════════════════════════════════════════"
    log_success "  Desinstalación completada exitosamente"
    log_success "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Security Audit ha sido completamente desinstalado del sistema"
}

# Función principal
main() {
    show_banner
    check_root
    detect_installed_components
    calculate_sizes
    offer_backup
    final_confirmation
    perform_uninstall
}

# Ejecutar
main "$@"
