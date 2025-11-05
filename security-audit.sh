#!/bin/bash

################################################################################
# Security Audit Script
#
# Script de auditoría de seguridad automatizado para servidores Debian/RedHat
# Analiza logs del sistema y el estado de seguridad, generando informes por email
#
# Autor: Security Team
# Versión: 1.0.0
# Licencia: MIT
################################################################################

set -euo pipefail

# Constantes
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly LOCK_FILE="/var/run/security-audit.lock"

# Configuración por defecto
CONFIG_FILE="${CONFIG_FILE:-/etc/security-audit/config.conf}"
INSTALL_DIR="${SCRIPT_DIR}"

# Variables globales
DEBUG=false
NO_EMAIL=false
ANALYSIS_HOURS=24
FORMAT="all"
EXIT_CODE=0

################################################################################
# Funciones de utilidad
################################################################################

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local log_line="[${timestamp}] [${level}] ${message}"

    # Imprimir a stderr
    echo "$log_line" >&2

    # Intentar escribir al archivo de log si existe el directorio
    if [[ -n "${LOG_FILE:-}" ]]; then
        local log_dir=$(dirname "$LOG_FILE")
        if [[ -d "$log_dir" ]] || mkdir -p "$log_dir" 2>/dev/null; then
            echo "$log_line" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { [[ "$DEBUG" == true ]] && log "DEBUG" "$@" || true; }

# Función de error que termina el script
die() {
    log_error "$@"
    cleanup
    exit 1
}

# Mostrar uso
usage() {
    cat <<EOF
Security Audit Script v${VERSION}

Uso: ${SCRIPT_NAME} [opciones]

Opciones:
    -h, --help              Mostrar esta ayuda
    -v, --version           Mostrar versión
    -d, --debug             Modo debug (verbose)
    -c, --config FILE       Archivo de configuración (default: /etc/security-audit/config.conf)
    --no-email              No enviar email, solo generar informe
    --hours N               Analizar últimas N horas de logs (default: 24)
    --format FORMAT         Formato del informe: html, txt, json, all (default: all)
    --test-email            Probar envío de email
    --check-deps            Verificar dependencias

Ejemplos:
    ${SCRIPT_NAME}                          # Ejecución normal
    ${SCRIPT_NAME} --debug                  # Con debug
    ${SCRIPT_NAME} --no-email --hours 48    # Sin email, 48 horas
    ${SCRIPT_NAME} --format html            # Solo HTML

EOF
    exit 0
}

# Mostrar versión
show_version() {
    echo "Security Audit Script v${VERSION}"
    exit 0
}

# Verificar que se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Este script debe ejecutarse como root"
    fi
}

# Crear lock file para evitar ejecuciones simultáneas
create_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "El script ya está en ejecución (PID: $pid). Saliendo..."
            exit 0
        else
            log_warn "Lock file existe pero el proceso no. Eliminando lock antiguo."
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    log_debug "Lock file creado: $LOCK_FILE"
}

# Limpiar al salir
cleanup() {
    log_debug "Limpiando archivos temporales..."

    # Remover lock file
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log_debug "Lock file removido"
    fi

    # Limpiar directorio temporal si existe
    if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_debug "Directorio temporal removido: $TEMP_DIR"
    fi
}

# Cargar configuración
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Si no existe config, usar valores por defecto
        log_warn "Archivo de configuración no encontrado: $CONFIG_FILE"
        log_warn "Usando configuración por defecto"
        set_default_config
        return
    fi

    log_info "Cargando configuración desde: $CONFIG_FILE"

    # Verificar permisos del archivo de configuración
    local perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %Lp "$CONFIG_FILE")
    if [[ "$perms" != "600" ]]; then
        log_warn "El archivo de configuración tiene permisos inseguros: $perms (debería ser 600)"
    fi

    # Source del archivo de configuración
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    log_debug "Configuración cargada correctamente"
}

# Configuración por defecto
set_default_config() {
    # Email
    EMAIL_TO="${EMAIL_TO:-root@localhost}"
    EMAIL_FROM="${EMAIL_FROM:-security-audit@$(hostname)}"
    EMAIL_SUBJECT_PREFIX="${EMAIL_SUBJECT_PREFIX:-[Security Audit]}"

    # SMTP
    SMTP_HOST="${SMTP_HOST:-localhost}"
    SMTP_PORT="${SMTP_PORT:-25}"
    SMTP_USER="${SMTP_USER:-}"
    SMTP_PASSWORD="${SMTP_PASSWORD:-}"
    SMTP_TLS="${SMTP_TLS:-no}"

    # Opciones
    SEND_ONLY_ON_ALERTS="${SEND_ONLY_ON_ALERTS:-no}"
    MIN_SEVERITY_TO_SEND="${MIN_SEVERITY_TO_SEND:-HIGH}"
    LOG_ANALYSIS_HOURS="${LOG_ANALYSIS_HOURS:-24}"

    # Umbrales
    FAILED_SSH_THRESHOLD="${FAILED_SSH_THRESHOLD:-10}"
    DISK_USAGE_THRESHOLD="${DISK_USAGE_THRESHOLD:-80}"
    LOAD_AVERAGE_THRESHOLD="${LOAD_AVERAGE_THRESHOLD:-}"  # Vacío = número de CPUs

    # Directorios
    REPORT_DIR="${REPORT_DIR:-/var/log/security-audit/reports}"
    TEMP_DIR="${TEMP_DIR:-/tmp/security-audit-$$}"
    LOG_FILE="${LOG_FILE:-/var/log/security-audit/security-audit.log}"

    # Retención
    REPORT_RETENTION_DAYS="${REPORT_RETENTION_DAYS:-90}"

    # Análisis
    ANALYZE_WEB_LOGS="${ANALYZE_WEB_LOGS:-yes}"
    ANALYZE_FAIL2BAN="${ANALYZE_FAIL2BAN:-yes}"
    CHECK_ROOTKIT="${CHECK_ROOTKIT:-yes}"
}

# Verificar dependencias
check_dependencies() {
    log_info "Verificando dependencias..."

    local missing_deps=()
    local optional_deps=()

    # Dependencias requeridas
    local required_commands="awk sed grep find ps df"

    for cmd in $required_commands; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Dependencias opcionales
    if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
        optional_deps+=("netstat o ss (para análisis de red)")
    fi

    if ! command -v mailx &> /dev/null && ! command -v msmtp &> /dev/null && ! command -v sendmail &> /dev/null; then
        optional_deps+=("mailx/msmtp/sendmail (para envío de emails)")
    fi

    if ! command -v rkhunter &> /dev/null && [[ "${CHECK_ROOTKIT:-no}" == "yes" ]]; then
        optional_deps+=("rkhunter (para detección de rootkits)")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Faltan dependencias requeridas: ${missing_deps[*]}"
        die "Instala las dependencias faltantes e intenta nuevamente"
    fi

    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warn "Dependencias opcionales faltantes: ${optional_deps[*]}"
    fi

    log_info "Todas las dependencias requeridas están disponibles"
}

# Detectar tipo de OS
detect_os() {
    log_info "Detectando sistema operativo..."

    if [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        OS_VERSION=$(cat /etc/debian_version)
        PACKAGE_MANAGER="apt"
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="redhat"
        OS_VERSION=$(cat /etc/redhat-release)
        PACKAGE_MANAGER="yum"

        # Detectar dnf si está disponible
        if command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        fi
    else
        log_warn "Sistema operativo no reconocido"
        OS_TYPE="unknown"
        OS_VERSION="unknown"
        PACKAGE_MANAGER="unknown"
    fi

    log_info "OS detectado: $OS_TYPE ($OS_VERSION)"
    log_debug "Package manager: $PACKAGE_MANAGER"

    # Exportar variables globales
    export OS_TYPE OS_VERSION PACKAGE_MANAGER
}

# Inicializar directorios
init_directories() {
    log_info "Inicializando directorios..."

    # Crear directorio de informes si no existe
    if [[ ! -d "$REPORT_DIR" ]]; then
        mkdir -p "$REPORT_DIR"
        chmod 750 "$REPORT_DIR"
        log_debug "Creado directorio de informes: $REPORT_DIR"
    fi

    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    chmod 700 "$TEMP_DIR"
    log_debug "Creado directorio temporal: $TEMP_DIR"

    # Crear directorio de logs si no existe
    local log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
        chmod 750 "$log_dir"
        log_debug "Creado directorio de logs: $log_dir"
    fi

    # Archivos temporales para datos
    export FINDINGS_FILE="$TEMP_DIR/findings.json"
    export STATS_FILE="$TEMP_DIR/stats.json"
    export SYSTEM_INFO_FILE="$TEMP_DIR/system-info.json"

    # Inicializar archivos JSON
    echo "[]" > "$FINDINGS_FILE"
    echo "{}" > "$STATS_FILE"
    echo "{}" > "$SYSTEM_INFO_FILE"

    log_debug "Archivos temporales inicializados"
}

# Cargar librerías
load_libraries() {
    log_info "Cargando librerías..."

    local lib_dir="$INSTALL_DIR/lib"

    if [[ ! -d "$lib_dir" ]]; then
        log_warn "Directorio de librerías no encontrado: $lib_dir"
        log_warn "Ejecutando en modo standalone (funcionalidad limitada)"
        return
    fi

    # Cargar cada librería
    for lib in "$lib_dir"/*.sh; do
        if [[ -f "$lib" ]]; then
            log_debug "Cargando librería: $(basename "$lib")"
            # shellcheck source=/dev/null
            source "$lib"
        fi
    done

    log_info "Librerías cargadas correctamente"
}

# Ejecutar análisis
run_analysis() {
    log_info "Iniciando análisis de seguridad..."
    local start_time=$(date +%s)

    # Si las funciones de las librerías están disponibles, usarlas
    if declare -F analyze_logs_main &> /dev/null; then
        log_info "Analizando logs del sistema..."
        analyze_logs_main || log_error "Error al analizar logs"
    else
        log_info "Módulo de análisis de logs no disponible, saltando..."
    fi

    if declare -F check_system_main &> /dev/null; then
        log_info "Verificando estado del sistema..."
        check_system_main || log_error "Error al verificar sistema"
    else
        log_info "Módulo de verificación del sistema no disponible, saltando..."
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Análisis completado en ${duration} segundos"
}

# Generar informes
generate_reports() {
    log_info "Generando informes..."

    if declare -F generate_reports_main &> /dev/null; then
        generate_reports_main || log_error "Error al generar informes"
    else
        log_info "Módulo de generación de informes no disponible, generando informe básico..."
        generate_basic_report
    fi
}

# Generar informe básico si no hay librerías
generate_basic_report() {
    local report_date=$(date +%Y-%m-%d)
    local report_file="$REPORT_DIR/${report_date}.txt"

    log_info "Generando informe básico en: $report_file"

    cat > "$report_file" <<EOF
=============================================================================
INFORME DE SEGURIDAD - $(hostname)
=============================================================================
Fecha: $(date '+%Y-%m-%d %H:%M:%S')
Sistema: $(uname -a)
Uptime: $(uptime)

NOTA: Este es un informe básico generado sin las librerías completas.
Para obtener análisis completo, asegúrate de que las librerías estén instaladas.

Sistema de archivos:
$(df -h)

Memoria:
$(free -h)

Últimos logins:
$(last -n 10)

Procesos en ejecución:
$(ps aux --sort=-%mem | head -20)

=============================================================================
EOF

    log_info "Informe básico generado: $report_file"
}

# Enviar email
send_report_email() {
    if [[ "$NO_EMAIL" == true ]]; then
        log_info "Envío de email deshabilitado (--no-email)"
        return
    fi

    log_info "Enviando informe por email..."

    if declare -F send_email_main &> /dev/null; then
        send_email_main || log_error "Error al enviar email"
    else
        log_info "Módulo de envío de email no disponible, usando método básico..."
        send_basic_email
    fi
}

# Envío básico de email
send_basic_email() {
    local report_date=$(date +%Y-%m-%d)
    local report_file="$REPORT_DIR/${report_date}.txt"

    if [[ ! -f "$report_file" ]]; then
        log_error "Informe no encontrado: $report_file"
        return 1
    fi

    local subject="${EMAIL_SUBJECT_PREFIX} $(hostname) - $report_date"

    if command -v mailx &> /dev/null; then
        mailx -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO" < "$report_file"
        log_info "Email enviado via mailx"
    elif command -v mail &> /dev/null; then
        mail -s "$subject" "$EMAIL_TO" < "$report_file"
        log_info "Email enviado via mail"
    else
        log_error "No hay herramienta de email disponible (mailx, mail)"
        return 1
    fi
}

# Limpiar informes antiguos
cleanup_old_reports() {
    log_info "Limpiando informes antiguos (> ${REPORT_RETENTION_DAYS} días)..."

    if [[ ! -d "$REPORT_DIR" ]]; then
        log_debug "Directorio de informes no existe"
        return
    fi

    local count=$(find "$REPORT_DIR" -type f -mtime +${REPORT_RETENTION_DAYS} 2>/dev/null | wc -l)

    if [[ $count -gt 0 ]]; then
        find "$REPORT_DIR" -type f -mtime +${REPORT_RETENTION_DAYS} -delete
        log_info "Eliminados $count informes antiguos"
    else
        log_debug "No hay informes antiguos para eliminar"
    fi
}

# Test de email
test_email() {
    log_info "Probando envío de email..."

    local subject="${EMAIL_SUBJECT_PREFIX} Test - $(hostname)"
    local body="Este es un email de prueba desde Security Audit Script.\nFecha: $(date)\nHostname: $(hostname)"

    if command -v mailx &> /dev/null; then
        echo -e "$body" | mailx -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO"
        log_info "Email de prueba enviado via mailx a: $EMAIL_TO"
    elif command -v mail &> /dev/null; then
        echo -e "$body" | mail -s "$subject" "$EMAIL_TO"
        log_info "Email de prueba enviado via mail a: $EMAIL_TO"
    else
        log_error "No hay herramienta de email disponible"
        exit 1
    fi

    echo "Email de prueba enviado a: $EMAIL_TO"
    echo "Verifica tu bandeja de entrada."
    exit 0
}

################################################################################
# Main
################################################################################

main() {
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--version)
                show_version
                ;;
            -d|--debug)
                DEBUG=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --no-email)
                NO_EMAIL=true
                shift
                ;;
            --hours)
                ANALYSIS_HOURS="$2"
                shift 2
                ;;
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --test-email)
                load_config
                test_email
                ;;
            --check-deps)
                check_dependencies
                echo "Todas las dependencias OK"
                exit 0
                ;;
            *)
                echo "Opción desconocida: $1"
                usage
                ;;
        esac
    done

    # Registrar trap para cleanup
    trap cleanup EXIT INT TERM

    # Inicio
    log_info "==================================================================="
    log_info "Security Audit Script v${VERSION} - Iniciando"
    log_info "==================================================================="
    log_info "Hostname: $(hostname)"
    log_info "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"

    # Verificaciones iniciales
    check_root
    create_lock
    load_config
    check_dependencies
    detect_os
    init_directories

    # Exportar variables para las librerías
    export DEBUG NO_EMAIL ANALYSIS_HOURS FORMAT
    export EMAIL_TO EMAIL_FROM EMAIL_SUBJECT_PREFIX
    export SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASSWORD SMTP_TLS
    export SEND_ONLY_ON_ALERTS MIN_SEVERITY_TO_SEND
    export LOG_ANALYSIS_HOURS FAILED_SSH_THRESHOLD DISK_USAGE_THRESHOLD
    export REPORT_DIR TEMP_DIR LOG_FILE
    export ANALYZE_WEB_LOGS ANALYZE_FAIL2BAN CHECK_ROOTKIT

    # Cargar librerías
    load_libraries

    # Ejecutar análisis
    run_analysis

    # Generar informes
    generate_reports

    # Enviar email
    send_report_email

    # Limpiar informes antiguos
    cleanup_old_reports

    # Fin
    log_info "==================================================================="
    log_info "Security Audit Script completado exitosamente"
    log_info "==================================================================="

    exit $EXIT_CODE
}

# Ejecutar main
main "$@"
