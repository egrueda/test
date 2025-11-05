# Guía de Desarrollo - Security Audit Script

Este documento describe cómo desarrollar, extender y contribuir al proyecto Security Audit Script.

## Tabla de Contenidos

1. [Estructura del Proyecto](#estructura-del-proyecto)
2. [Arquitectura](#arquitectura)
3. [Cómo Desarrollar](#cómo-desarrollar)
4. [Agregar Nuevos Checks](#agregar-nuevos-checks)
5. [Testing](#testing)
6. [Estándares de Código](#estándares-de-código)
7. [Contribuir](#contribuir)

## Estructura del Proyecto

```
security-audit/
├── security-audit.sh           # Script principal (orquestador)
├── install.sh                  # Script de instalación
├── lib/                        # Módulos/librerías
│   ├── common.sh              # Funciones comunes
│   ├── log-analyzer.sh        # Análisis de logs
│   ├── system-check.sh        # Verificaciones del sistema
│   ├── report-generator.sh    # Generación de informes
│   └── email-sender.sh        # Envío de emails
├── templates/                  # Plantillas de informes
│   ├── report.html            # Template HTML
│   └── report.txt             # Template texto
├── config/                     # Configuraciones de ejemplo
│   └── config.conf.example    # Configuración de ejemplo
├── docs/                       # Documentación adicional
├── tests/                      # Tests (futuros)
├── README.md                  # Documentación principal
├── INSTALL.md                 # Guía de instalación
├── SPECIFICATIONS.md          # Especificaciones técnicas
├── ARCHITECTURE.md            # Documentación de arquitectura
└── LICENSE                    # Licencia MIT

Cuando está instalado:
/opt/security-audit/           # Código instalado
/etc/security-audit/           # Configuración
/var/log/security-audit/       # Logs e informes
/var/lib/security-audit/       # Datos (baselines, etc.)
```

## Arquitectura

### Flujo de Ejecución

```
main() → Orquestador Principal
  ↓
  ├─→ load_config()          # Cargar configuración
  ├─→ check_dependencies()   # Verificar dependencias
  ├─→ detect_os()           # Detectar OS
  ├─→ init_directories()    # Inicializar directorios
  ├─→ load_libraries()      # Cargar módulos
  │
  ├─→ analyze_logs()        # lib/log-analyzer.sh
  │   ├─→ analyze_auth_logs()
  │   ├─→ analyze_syslog()
  │   ├─→ analyze_kernel_log()
  │   ├─→ analyze_web_logs()
  │   └─→ analyze_fail2ban_logs()
  │
  ├─→ check_system()        # lib/system-check.sh
  │   ├─→ check_security_updates()
  │   ├─→ check_firewall()
  │   ├─→ check_users_and_permissions()
  │   ├─→ check_suid_files()
  │   ├─→ check_services()
  │   ├─→ check_network()
  │   ├─→ check_filesystem()
  │   ├─→ check_resources()
  │   └─→ check_rootkit_indicators()
  │
  ├─→ generate_reports()    # lib/report-generator.sh
  │   ├─→ generate_html_report()
  │   ├─→ generate_text_report()
  │   └─→ generate_json_report()
  │
  ├─→ send_email()          # lib/email-sender.sh
  │
  └─→ cleanup()             # Limpieza
```

### Comunicación Entre Módulos

Los módulos se comunican mediante:

1. **Variables de entorno globales**
   - `OS_TYPE`, `OS_VERSION`, `PACKAGE_MANAGER`
   - `TEMP_DIR`, `LOG_FILE`
   - Configuración cargada desde `config.conf`

2. **Archivos JSON temporales**
   - `$FINDINGS_FILE` - Hallazgos de seguridad
   - `$STATS_FILE` - Estadísticas
   - `$SYSTEM_INFO_FILE` - Información del sistema

3. **Funciones compartidas** (en `lib/common.sh`)
   - `log_info()`, `log_error()`, etc.
   - `add_finding()` - Agregar hallazgo
   - `add_stat()` - Agregar estadística

## Cómo Desarrollar

### Configurar Entorno de Desarrollo

1. **Clonar el repositorio**:
```bash
git clone https://github.com/tu-usuario/security-audit.git
cd security-audit
```

2. **Crear rama de desarrollo**:
```bash
git checkout -b feature/mi-nueva-funcionalidad
```

3. **Configurar pre-commit hooks** (opcional):
```bash
# Instalar shellcheck para linting
sudo apt-get install shellcheck

# Crear hook de pre-commit
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
# Ejecutar shellcheck en archivos .sh modificados
for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do
    shellcheck "$file" || exit 1
done
EOF

chmod +x .git/hooks/pre-commit
```

### Desarrollar Localmente

Para probar cambios sin instalar:

```bash
# Ejecutar desde el directorio del proyecto
sudo ./security-audit.sh --no-email --debug

# Especificar config personalizado
sudo CONFIG_FILE=./config/config.conf.example ./security-audit.sh
```

### Debugging

```bash
# Activar modo debug
sudo ./security-audit.sh --debug

# Ver logs en tiempo real
tail -f /var/log/security-audit/security-audit.log

# Bash debug
bash -x ./security-audit.sh --no-email
```

## Agregar Nuevos Checks

### Ejemplo: Agregar Check de Docker

1. **Crear función en `lib/system-check.sh`**:

```bash
# Verificar seguridad de Docker
check_docker_security() {
    log_info "Verificando seguridad de Docker..."

    # Verificar si Docker está instalado
    if ! command -v docker &> /dev/null; then
        log_debug "Docker no está instalado"
        return 0
    fi

    # Verificar que el daemon de Docker esté corriendo
    if ! systemctl is-active --quiet docker; then
        add_finding "MEDIUM" "Docker" \
            "Docker instalado pero daemon no está corriendo" \
            "El servicio Docker está instalado pero no activo" \
            "Estado: $(systemctl status docker --no-pager 2>&1 | head -5)" \
            "Iniciar el servicio Docker o desinstalarlo si no se usa"
        return 0
    fi

    # Verificar usuarios en el grupo docker
    local docker_users=$(getent group docker | cut -d: -f4)
    if [[ -n "$docker_users" ]]; then
        add_finding "HIGH" "Docker" \
            "Usuarios en grupo docker tienen privilegios de root" \
            "Los siguientes usuarios pueden ejecutar contenedores con privilegios de root: $docker_users" \
            "Usuarios en grupo docker: $docker_users" \
            "Revisa que solo usuarios autorizados estén en el grupo docker. Considera usar rootless Docker."
    fi

    # Verificar sockets expuestos
    if netstat -ln | grep -q ":2375 "; then
        add_finding "CRITICAL" "Docker" \
            "API de Docker expuesta sin TLS" \
            "El socket de Docker está expuesto en el puerto 2375 sin encriptación" \
            "Puerto 2375 abierto sin TLS" \
            "Deshabilitar acceso remoto a Docker o configurar TLS en el puerto 2376"
    fi

    # Verificar contenedores en modo privilegiado
    local privileged_containers=$(docker ps --filter "status=running" --format "{{.Names}}" --filter "privileged=true" 2>/dev/null)
    if [[ -n "$privileged_containers" ]]; then
        add_finding "HIGH" "Docker" \
            "Contenedores corriendo en modo privilegiado" \
            "Los siguientes contenedores tienen modo privilegiado: $privileged_containers" \
            "Contenedores privilegiados: $privileged_containers" \
            "Evita usar --privileged. Usa capabilities específicas en su lugar."
    fi

    log_info "Verificación de Docker completada"
}
```

2. **Llamar la función desde `check_system()`**:

```bash
check_system() {
    collect_system_info
    check_security_updates
    check_firewall
    # ... otros checks ...
    check_docker_security    # ← Agregar aquí
    check_rootkit_indicators
}
```

3. **Agregar configuración** en `config/config.conf.example`:

```bash
# Verificar seguridad de Docker (yes/no)
CHECK_DOCKER="yes"
```

4. **Documentar** en `SPECIFICATIONS.md` y `README.md`

### Estructura de add_finding()

```bash
add_finding SEVERITY CATEGORY TITLE DESCRIPTION EVIDENCE RECOMMENDATION
```

Parámetros:
- **SEVERITY**: CRITICAL, HIGH, MEDIUM, LOW
- **CATEGORY**: Categoría del hallazgo (ej: "Authentication", "Firewall", "Docker")
- **TITLE**: Título corto del hallazgo
- **DESCRIPTION**: Descripción detallada
- **EVIDENCE**: Evidencia (logs, output de comandos)
- **RECOMMENDATION**: Qué hacer para corregirlo

### Ejemplo de add_stat()

```bash
# Agregar estadística
add_stat "docker_containers_running" "5"
add_stat "docker_images_count" "12"
```

## Testing

### Tests Manuales

```bash
# Test completo
sudo ./security-audit.sh --no-email

# Test solo análisis de logs
sudo bash -c 'source lib/common.sh && source lib/log-analyzer.sh && analyze_logs'

# Test generación de informe
sudo bash -c 'source lib/report-generator.sh && generate_html_report'
```

### Tests en Contenedores

Crear `tests/docker-compose.yml`:

```yaml
version: '3'
services:
  debian11:
    image: debian:11
    volumes:
      - ..:/security-audit
    command: /bin/bash -c "cd /security-audit && ./install.sh"

  rocky9:
    image: rockylinux:9
    volumes:
      - ..:/security-audit
    command: /bin/bash -c "cd /security-audit && ./install.sh"
```

Ejecutar:
```bash
cd tests
docker-compose up
```

### Tests de Integración (Futuro)

Estructura para tests con bats (Bash Automated Testing System):

```bash
# tests/test_installation.bats
#!/usr/bin/env bats

@test "script principal existe y es ejecutable" {
    [ -x "/opt/security-audit/security-audit.sh" ]
}

@test "directorio de configuración existe" {
    [ -d "/etc/security-audit" ]
}

@test "puede ejecutarse sin errores" {
    run /opt/security-audit/security-audit.sh --check-deps
    [ "$status" -eq 0 ]
}
```

## Estándares de Código

### Shell Script Best Practices

1. **Usar ShellCheck**:
```bash
shellcheck security-audit.sh
```

2. **Set options estrictas**:
```bash
set -euo pipefail
```

3. **Usar variables con comillas**:
```bash
# Bien
if [[ "$var" == "value" ]]; then

# Mal
if [ $var == "value" ]; then
```

4. **Funciones descriptivas**:
```bash
# Bien
check_firewall_status() {
    # código
}

# Mal
check_fw() {
    # código
}
```

5. **Logging consistente**:
```bash
log_info "Mensaje informativo"
log_warn "Mensaje de advertencia"
log_error "Mensaje de error"
log_debug "Mensaje de debug (solo con --debug)"
```

6. **Manejo de errores**:
```bash
# Capturar errores pero continuar
analyze_web_logs || log_error "Error al analizar logs web"

# Error fatal
[[ -f "$critical_file" ]] || die "Archivo crítico no encontrado"
```

7. **Comentarios en español**:
```bash
# Verificar si el firewall está activo
check_firewall_status

# Iterar sobre cada línea del log
while IFS= read -r line; do
    # procesar línea
done < "$log_file"
```

### Formato de Código

- **Indentación**: 4 espacios
- **Longitud de línea**: Máximo 100 caracteres
- **Nombres de variables**: snake_case
- **Nombres de constantes**: UPPER_CASE
- **Nombres de funciones**: snake_case

### Variables Globales

Exportar solo las necesarias:
```bash
export OS_TYPE OS_VERSION PACKAGE_MANAGER
export FINDINGS_FILE STATS_FILE SYSTEM_INFO_FILE
```

## Contribuir

### Proceso de Contribución

1. **Fork** el repositorio
2. **Crear** rama de feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Desarrollar** siguiendo los estándares
4. **Probar** en Debian y RedHat
5. **Commit** con mensajes descriptivos
6. **Push** a tu fork
7. **Crear** Pull Request

### Mensaje de Commit

Formato:
```
tipo(alcance): descripción corta

Descripción más detallada si es necesario.

- Cambio 1
- Cambio 2
```

Tipos:
- `feat`: Nueva funcionalidad
- `fix`: Corrección de bug
- `docs`: Cambios en documentación
- `style`: Formato, no afecta lógica
- `refactor`: Refactorización
- `test`: Tests
- `chore`: Mantenimiento

Ejemplos:
```
feat(log-analyzer): agregar análisis de logs de nginx

fix(email-sender): corregir envío con msmtp en RedHat

docs(README): actualizar instrucciones de instalación
```

### Checklist de PR

- [ ] Código sigue los estándares del proyecto
- [ ] ShellCheck pasa sin errores
- [ ] Probado en Debian 11+
- [ ] Probado en Rocky Linux 9+
- [ ] Documentación actualizada
- [ ] Sin secretos o información sensible en el código
- [ ] Funciona con `set -euo pipefail`

## Roadmap

Ver issues en GitHub para features planificadas:
- Dashboard web
- API REST
- Machine learning para detección de anomalías
- Soporte para más distribuciones
- Sistema de plugins
- Tests automatizados completos

## Recursos

- [ShellCheck](https://www.shellcheck.net/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)

## Soporte

- GitHub Issues: https://github.com/tu-usuario/security-audit/issues
- Documentación: Ver README.md, SPECIFICATIONS.md, ARCHITECTURE.md
- Email: dev@example.com
