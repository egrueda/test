#!/bin/bash

################################################################################
# Script de Instalación - Security Audit
#
# Instala y configura el sistema de auditoría de seguridad
#
# Uso: sudo ./install.sh
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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
║        Security Audit - Script de Auditoría de Seguridad     ║
║                         Versión 1.0.0                         ║
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

# Detectar sistema operativo
detect_os() {
    log_info "Detectando sistema operativo..."

    if [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        OS_NAME=$(lsb_release -si 2>/dev/null || echo "Debian")
        OS_VERSION=$(lsb_release -sr 2>/dev/null || cat /etc/debian_version)
        PACKAGE_MANAGER="apt-get"
        log_success "Sistema detectado: $OS_NAME $OS_VERSION (Debian-based)"
    elif [[ -f /etc/redhat-release ]]; then
        OS_TYPE="redhat"
        OS_NAME=$(cat /etc/redhat-release | awk '{print $1}')
        OS_VERSION=$(cat /etc/redhat-release | grep -oP '\d+' | head -1)

        if command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        else
            PACKAGE_MANAGER="yum"
        fi

        log_success "Sistema detectado: $OS_NAME $OS_VERSION (RedHat-based)"
    else
        die "Sistema operativo no soportado. Solo Debian y RedHat/CentOS son compatibles."
    fi

    export OS_TYPE OS_NAME OS_VERSION PACKAGE_MANAGER
}

# Verificar dependencias
check_dependencies() {
    log_info "Verificando dependencias del sistema..."

    local deps_ok=true
    local missing_deps=()

    # Dependencias básicas
    local required_commands="awk sed grep find ps df"

    for cmd in $required_commands; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
            deps_ok=false
        fi
    done

    # netstat o ss
    if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
        missing_deps+=("net-tools")
        deps_ok=false
    fi

    if [[ "$deps_ok" == false ]]; then
        log_warn "Faltan algunas dependencias básicas: ${missing_deps[*]}"
    else
        log_success "Todas las dependencias básicas están presentes"
    fi
}

# Instalar dependencias
install_dependencies() {
    log_info "Instalando dependencias necesarias..."

    case $PACKAGE_MANAGER in
        apt-get)
            apt-get update -qq
            apt-get install -y -qq \
                mailutils \
                msmtp \
                msmtp-mta \
                net-tools \
                bsd-mailx \
                cron \
                logrotate \
                jq \
                curl \
                wget \
                || log_warn "Algunas dependencias no se pudieron instalar"
            ;;
        dnf)
            dnf install -y -q \
                mailx \
                net-tools \
                cronie \
                logrotate \
                jq \
                curl \
                wget \
                || log_warn "Algunas dependencias no se pudieron instalar"
            ;;
        yum)
            yum install -y -q \
                mailx \
                net-tools \
                cronie \
                logrotate \
                jq \
                curl \
                wget \
                || log_warn "Algunas dependencias no se pudieron instalar"
            ;;
    esac

    log_success "Dependencias instaladas"
}

# Instalar dependencias opcionales
install_optional_dependencies() {
    log_info "¿Desea instalar dependencias opcionales? (rkhunter, lynis, fail2ban)"
    read -p "Responder [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case $PACKAGE_MANAGER in
            apt-get)
                apt-get install -y -qq rkhunter lynis fail2ban || log_warn "Algunas dependencias opcionales fallaron"
                ;;
            dnf|yum)
                $PACKAGE_MANAGER install -y -q rkhunter lynis fail2ban || log_warn "Algunas dependencias opcionales fallaron"
                ;;
        esac
        log_success "Dependencias opcionales instaladas"
    else
        log_info "Saltando dependencias opcionales"
    fi
}

# Crear directorios
create_directories() {
    log_info "Creando estructura de directorios..."

    # Directorio de instalación
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/templates"

    # Directorio de configuración
    mkdir -p "$CONFIG_DIR"

    # Directorio de logs
    mkdir -p "$LOG_DIR"
    mkdir -p "$LOG_DIR/reports"

    # Directorio de datos
    mkdir -p "$LIB_DIR"

    log_success "Directorios creados"
}

# Copiar archivos
copy_files() {
    log_info "Copiando archivos del sistema..."

    # Script principal
    if [[ -f "$SCRIPT_DIR/security-audit.sh" ]]; then
        cp "$SCRIPT_DIR/security-audit.sh" "$INSTALL_DIR/"
        chmod 755 "$INSTALL_DIR/security-audit.sh"
        log_success "Script principal copiado"
    else
        log_warn "security-audit.sh no encontrado en $SCRIPT_DIR"
    fi

    # Librerías
    if [[ -d "$SCRIPT_DIR/lib" ]]; then
        cp -r "$SCRIPT_DIR/lib/"* "$INSTALL_DIR/lib/" 2>/dev/null || log_warn "No se encontraron librerías"
        chmod 644 "$INSTALL_DIR/lib/"*.sh 2>/dev/null || true
        log_success "Librerías copiadas"
    else
        log_warn "Directorio lib no encontrado"
    fi

    # Templates
    if [[ -d "$SCRIPT_DIR/templates" ]]; then
        cp -r "$SCRIPT_DIR/templates/"* "$INSTALL_DIR/templates/" 2>/dev/null || log_warn "No se encontraron templates"
        chmod 644 "$INSTALL_DIR/templates/"* 2>/dev/null || true
        log_success "Templates copiados"
    else
        log_warn "Directorio templates no encontrado"
    fi

    # Archivo de configuración de ejemplo
    if [[ -f "$SCRIPT_DIR/config/config.conf.example" ]]; then
        if [[ ! -f "$CONFIG_DIR/config.conf" ]]; then
            # No hay config previa, crear nueva
            cp "$SCRIPT_DIR/config/config.conf.example" "$CONFIG_DIR/config.conf"
            chmod 600 "$CONFIG_DIR/config.conf"
            log_success "Archivo de configuración creado (debes editarlo)"
            export CONFIG_EXISTS=false
        else
            # Hay config previa, hacer backup y actualizar
            local timestamp=$(date +%Y%m%d_%H%M%S)
            cp "$CONFIG_DIR/config.conf" "$CONFIG_DIR/config.conf.backup.$timestamp"
            log_warn "Configuración existente detectada"
            log_info "Backup guardado: config.conf.backup.$timestamp"

            # Guardar el .example para referencia
            cp "$SCRIPT_DIR/config/config.conf.example" "$CONFIG_DIR/config.conf.example"

            # Marcar que existe config previa
            export CONFIG_EXISTS=true
        fi
    fi
}

# Configurar permisos
set_permissions() {
    log_info "Configurando permisos..."

    # Instalación
    chown -R root:root "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR/security-audit.sh"
    chmod 644 "$INSTALL_DIR/lib/"*.sh 2>/dev/null || true
    chmod 644 "$INSTALL_DIR/templates/"* 2>/dev/null || true

    # Configuración
    chown -R root:root "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    chmod 600 "$CONFIG_DIR/config.conf" 2>/dev/null || true

    # Logs
    chown -R root:root "$LOG_DIR"
    chmod 750 "$LOG_DIR"
    chmod 750 "$LOG_DIR/reports"

    # Lib
    chown -R root:root "$LIB_DIR"
    chmod 750 "$LIB_DIR"

    log_success "Permisos configurados"
}

# Configurar cron
configure_cron() {
    log_info "Configurando tarea cron..."

    local cron_file="/etc/cron.d/security-audit"

    # Preguntar hora de ejecución
    log_info "¿A qué hora deseas que se ejecute el análisis diario?"
    read -p "Hora (0-23) [6]: " cron_hour
    cron_hour=${cron_hour:-6}

    read -p "Minuto (0-59) [0]: " cron_minute
    cron_minute=${cron_minute:-0}

    # Crear archivo cron
    cat > "$cron_file" <<EOF
# Security Audit - Ejecución diaria
# Ejecuta el análisis de seguridad y envía informe por email

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Ejecutar todos los días a las ${cron_hour}:${cron_minute}
${cron_minute} ${cron_hour} * * * root ${INSTALL_DIR}/security-audit.sh >> ${LOG_DIR}/cron.log 2>&1
EOF

    chmod 644 "$cron_file"
    log_success "Cron configurado para ejecutarse diariamente a las ${cron_hour}:${cron_minute}"

    # Reiniciar cron
    case $OS_TYPE in
        debian)
            systemctl reload cron 2>/dev/null || service cron reload 2>/dev/null || true
            ;;
        redhat)
            systemctl reload crond 2>/dev/null || service crond reload 2>/dev/null || true
            ;;
    esac
}

# Configurar logrotate
configure_logrotate() {
    log_info "Configurando rotación de logs..."

    cat > /etc/logrotate.d/security-audit <<'EOF'
/var/log/security-audit/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    sharedscripts
}
EOF

    log_success "Logrotate configurado"
}

# Leer configuración existente
read_existing_config() {
    # Buscar el backup más reciente
    local backup_file=$(ls -t "$CONFIG_DIR"/config.conf.backup.* 2>/dev/null | head -1)

    local config_file
    if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
        config_file="$backup_file"
    elif [[ -f "$CONFIG_DIR/config.conf" ]]; then
        config_file="$CONFIG_DIR/config.conf"
    else
        return 1
    fi

    # Extraer valores (eliminando comillas y espacios)
    EXISTING_EMAIL_TO=$(grep "^EMAIL_TO=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_EMAIL_FROM=$(grep "^EMAIL_FROM=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_SMTP_HOST=$(grep "^SMTP_HOST=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_SMTP_PORT=$(grep "^SMTP_PORT=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_SMTP_USER=$(grep "^SMTP_USER=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_SMTP_PASSWORD=$(grep "^SMTP_PASSWORD=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')
    EXISTING_SMTP_TLS=$(grep "^SMTP_TLS=" "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^"//;s/"$//;s/^ *//;s/ *$//')

    # Verificar que al menos se leyó el email
    if [[ -n "$EXISTING_EMAIL_TO" ]]; then
        return 0
    fi

    return 1
}

# Configuración interactiva
interactive_config() {
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "             CONFIGURACIÓN DE EMAIL                         "
    log_info "════════════════════════════════════════════════════════════"
    log_info ""

    # Verificar si existe configuración previa
    local has_existing_config=false
    if [[ "${CONFIG_EXISTS:-false}" == "true" ]] && read_existing_config; then
        has_existing_config=true
        log_info "Se detectó una configuración existente."
        log_info ""
        log_info "Configuración actual:"
        log_info "  Email destinatario: ${EXISTING_EMAIL_TO}"
        log_info "  Email remitente:    ${EXISTING_EMAIL_FROM}"
        log_info "  Servidor SMTP:      ${EXISTING_SMTP_HOST}:${EXISTING_SMTP_PORT}"
        log_info "  Usuario SMTP:       ${EXISTING_SMTP_USER:-<sin configurar>}"
        log_info "  TLS:                ${EXISTING_SMTP_TLS}"
        log_info ""

        read -p "¿Deseas mantener esta configuración? [Y/n]: " keep_config
        if [[ ! $keep_config =~ ^[Nn]$ ]]; then
            log_success "Manteniendo configuración existente"
            return 0
        fi
        log_info ""
        log_info "Reconfigurando..."
    fi

    log_info "Por favor, configura los parámetros de email para recibir los informes."
    log_info "Presiona Enter para mantener el valor por defecto mostrado entre [corchetes]"
    log_info ""

    # Email destinatario
    local default_email_to="${EXISTING_EMAIL_TO:-root@localhost}"
    read -p "Email destinatario [$default_email_to]: " email_to
    email_to=${email_to:-$default_email_to}

    # Email remitente
    local default_from="${EXISTING_EMAIL_FROM:-security-audit@$(hostname -f 2>/dev/null || hostname)}"
    read -p "Email remitente [$default_from]: " email_from
    email_from=${email_from:-$default_from}

    # SMTP Host
    local default_smtp_host="${EXISTING_SMTP_HOST:-localhost}"
    read -p "Servidor SMTP [$default_smtp_host]: " smtp_host
    smtp_host=${smtp_host:-$default_smtp_host}

    # SMTP Port
    local default_smtp_port="${EXISTING_SMTP_PORT:-25}"
    read -p "Puerto SMTP [$default_smtp_port]: " smtp_port
    smtp_port=${smtp_port:-$default_smtp_port}

    # SMTP User
    local default_smtp_user="${EXISTING_SMTP_USER:-}"
    if [[ -n "$default_smtp_user" ]]; then
        read -p "Usuario SMTP [$default_smtp_user]: " smtp_user
        smtp_user=${smtp_user:-$default_smtp_user}
    else
        read -p "Usuario SMTP (vacío si no requiere auth): " smtp_user
    fi

    # SMTP Password
    if [[ -n "$smtp_user" ]]; then
        if [[ -n "${EXISTING_SMTP_PASSWORD:-}" ]] && [[ "$has_existing_config" == "true" ]]; then
            read -p "¿Mantener contraseña SMTP existente? [Y/n]: " keep_pass
            if [[ $keep_pass =~ ^[Nn]$ ]]; then
                read -sp "Nueva contraseña SMTP: " smtp_password
                echo
            else
                smtp_password="$EXISTING_SMTP_PASSWORD"
            fi
        else
            read -sp "Contraseña SMTP: " smtp_password
            echo
        fi
    else
        smtp_password=""
    fi

    # TLS
    local default_tls="${EXISTING_SMTP_TLS:-no}"
    local tls_prompt="n"
    [[ "$default_tls" == "yes" ]] && tls_prompt="y"
    read -p "Usar TLS? [${tls_prompt}/N]: " use_tls
    use_tls=${use_tls:-$tls_prompt}
    if [[ $use_tls =~ ^[Yy]$ ]]; then
        smtp_tls="yes"
    else
        smtp_tls="no"
    fi

    # Actualizar config.conf
    if [[ -f "$CONFIG_DIR/config.conf" ]]; then
        sed -i "s|^EMAIL_TO=.*|EMAIL_TO=\"$email_to\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^EMAIL_FROM=.*|EMAIL_FROM=\"$email_from\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^SMTP_HOST=.*|SMTP_HOST=\"$smtp_host\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^SMTP_PORT=.*|SMTP_PORT=\"$smtp_port\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^SMTP_USER=.*|SMTP_USER=\"$smtp_user\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^SMTP_PASSWORD=.*|SMTP_PASSWORD=\"$smtp_password\"|" "$CONFIG_DIR/config.conf"
        sed -i "s|^SMTP_TLS=.*|SMTP_TLS=\"$smtp_tls\"|" "$CONFIG_DIR/config.conf"

        log_success "Configuración de email actualizada"
    fi
}

# Test de instalación
test_installation() {
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "             VERIFICACIÓN DE INSTALACIÓN                    "
    log_info "════════════════════════════════════════════════════════════"
    log_info ""

    # Verificar script principal
    if [[ -x "$INSTALL_DIR/security-audit.sh" ]]; then
        log_success "Script principal: OK"
    else
        log_error "Script principal: FALLO"
    fi

    # Verificar configuración
    if [[ -f "$CONFIG_DIR/config.conf" ]]; then
        log_success "Configuración: OK"
    else
        log_warn "Configuración: No encontrada"
    fi

    # Verificar directorios
    if [[ -d "$LOG_DIR" ]] && [[ -d "$LOG_DIR/reports" ]]; then
        log_success "Directorios: OK"
    else
        log_error "Directorios: FALLO"
    fi

    # Verificar cron
    if [[ -f "/etc/cron.d/security-audit" ]]; then
        log_success "Cron: OK"
    else
        log_warn "Cron: No configurado"
    fi
}

# Ejecutar test manual
run_manual_test() {
    log_info ""
    read -p "¿Deseas ejecutar una prueba manual del script? [Y/n]: " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Ejecutando análisis de prueba..."
        log_info "(Esto puede tomar unos minutos)"
        log_info ""

        "$INSTALL_DIR/security-audit.sh" --no-email || log_error "El test falló"

        log_info ""
        log_info "Verifica el informe generado en: $LOG_DIR/reports/"
        ls -lh "$LOG_DIR/reports/" 2>/dev/null || true
    fi
}

# Mostrar resumen final
show_summary() {
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "           INSTALACIÓN COMPLETADA CON ÉXITO                 "
    log_info "════════════════════════════════════════════════════════════"
    log_info ""
    log_info "Ubicaciones importantes:"
    log_info "  • Script principal:   $INSTALL_DIR/security-audit.sh"
    log_info "  • Configuración:      $CONFIG_DIR/config.conf"
    log_info "  • Logs:               $LOG_DIR/"
    log_info "  • Informes:           $LOG_DIR/reports/"
    log_info "  • Cron:               /etc/cron.d/security-audit"
    log_info ""
    log_info "Próximos pasos:"
    log_info "  1. Edita la configuración si es necesario:"
    log_info "     nano $CONFIG_DIR/config.conf"
    log_info ""
    log_info "  2. Ejecuta manualmente para probar:"
    log_info "     $INSTALL_DIR/security-audit.sh --no-email"
    log_info ""
    log_info "  3. Prueba el envío de email:"
    log_info "     $INSTALL_DIR/security-audit.sh --test-email"
    log_info ""
    log_info "  4. El script se ejecutará automáticamente via cron"
    log_info ""
    log_info "Documentación completa en:"
    log_info "  https://github.com/tu-usuario/security-audit"
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
}

# Main
main() {
    show_banner

    log_info "Iniciando instalación de Security Audit..."
    log_info ""

    check_root
    detect_os
    check_dependencies
    install_dependencies
    install_optional_dependencies
    create_directories
    copy_files
    set_permissions
    configure_cron
    configure_logrotate
    interactive_config
    test_installation
    run_manual_test
    show_summary

    log_success ""
    log_success "¡Instalación completada exitosamente!"
}

# Ejecutar
main "$@"
