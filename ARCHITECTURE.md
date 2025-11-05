# Arquitectura del Sistema de Auditoría de Seguridad

## 1. Visión General

El sistema está diseñado con una arquitectura modular basada en scripts Bash, donde cada módulo tiene una responsabilidad específica. La comunicación entre módulos se realiza mediante variables de entorno y archivos temporales.

```
┌─────────────────────────────────────────────────────────────┐
│                    security-audit.sh                        │
│                   (Orquestador Principal)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
         ┌──────────────────┐  ┌──────────────────┐
         │  Configuración   │  │   Validación     │
         │   config.conf    │  │  Dependencias    │
         └──────────────────┘  └──────────────────┘
                    │
        ┌───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│   Log    │  │  System  │  │  Report  │  │  Email   │
│ Analyzer │  │  Check   │  │Generator │  │  Sender  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
      │              │              │            │
      └──────┬───────┴──────┬───────┘            │
             ▼              ▼                     ▼
      ┌──────────────────────────┐      ┌─────────────┐
      │  Archivos Temporales     │      │    SMTP     │
      │  - findings.json         │      │   Server    │
      │  - stats.json            │      └─────────────┘
      │  - system-info.json      │
      └──────────────────────────┘
             │
             ▼
      ┌──────────────────────────┐
      │  Informes Generados      │
      │  - report.html           │
      │  - report.txt            │
      │  - report.json           │
      └──────────────────────────┘
```

## 2. Componentes del Sistema

### 2.1 Script Principal (security-audit.sh)

**Responsabilidad**: Orquestar la ejecución de todos los módulos

**Funciones principales**:
- Cargar configuración
- Validar dependencias del sistema
- Inicializar variables y directorios temporales
- Ejecutar módulos en secuencia
- Manejar errores globales
- Generar logs de ejecución
- Limpiar archivos temporales

**Flujo de ejecución**:
```bash
1. Verificar ejecución como root
2. Cargar /etc/security-audit/config.conf
3. Crear lock file (/var/run/security-audit.lock)
4. Inicializar logging
5. Detectar tipo de OS
6. Validar dependencias
7. Ejecutar módulo de análisis de logs
8. Ejecutar módulo de checks del sistema
9. Ejecutar módulo de generación de informes
10. Ejecutar módulo de envío de email
11. Limpiar archivos temporales
12. Remover lock file
13. Exit con código de estado
```

### 2.2 Módulo de Funciones Comunes (lib/common.sh)

**Responsabilidad**: Proporcionar funciones compartidas entre módulos

**Funciones principales**:
```bash
# Logging
log_info()     # Registrar información
log_warn()     # Registrar advertencias
log_error()    # Registrar errores
log_debug()    # Registrar debug (si está habilitado)

# Detección de OS
detect_os()             # Detectar Debian vs RedHat
get_package_manager()   # apt vs yum/dnf
get_auth_log_path()     # auth.log vs secure
get_syslog_path()       # syslog vs messages

# Utilidades
check_command()         # Verificar si comando existe
run_with_timeout()      # Ejecutar comando con timeout
sanitize_input()        # Sanitizar entrada
get_timestamp()         # Obtener timestamp formateado
create_temp_file()      # Crear archivo temporal seguro
add_finding()           # Agregar hallazgo al reporte
add_stat()              # Agregar estadística

# Colores para output
color_red()
color_green()
color_yellow()
color_reset()
```

**Variables globales exportadas**:
```bash
OS_TYPE                 # "debian" o "redhat"
OS_VERSION              # Versión del OS
TEMP_DIR                # Directorio temporal para esta ejecución
FINDINGS_FILE           # archivo JSON con hallazgos
STATS_FILE              # Archivo JSON con estadísticas
SYSTEM_INFO_FILE        # Archivo JSON con info del sistema
```

### 2.3 Módulo de Análisis de Logs (lib/log-analyzer.sh)

**Responsabilidad**: Analizar logs del sistema en busca de eventos de seguridad

**Estructura**:
```bash
analyze_logs() {
    analyze_auth_logs
    analyze_syslog
    analyze_kernel_log
    analyze_web_logs
    analyze_fail2ban_logs
}
```

**Funciones específicas**:

#### analyze_auth_logs()
```bash
# Buscar:
- Intentos fallidos SSH (Failed password)
- Intentos de acceso root
- Intentos de sudo fallidos
- Autenticaciones exitosas desde IPs inusuales
- Usuarios nuevos creados
- Cambios en grupos
- Sesiones inusuales (horarios raros)

# Output: Agrega findings con severidad CRITICAL/HIGH/MEDIUM
```

#### analyze_syslog()
```bash
# Buscar:
- Errores críticos (error, critical, alert)
- Servicios que fallaron
- Reinicios inesperados
- Mensajes de seguridad
- Cambios en configuración del sistema

# Output: Agrega findings con severidad apropiada
```

#### analyze_kernel_log()
```bash
# Buscar:
- Errores de hardware
- OOM killer activado
- Errores de disco
- Segmentation faults
- Mensajes de seguridad del kernel

# Output: Agrega findings con severidad apropiada
```

#### analyze_web_logs()
```bash
# Buscar (si existen):
- Códigos 4xx y 5xx frecuentes
- Intentos de SQL injection (OR 1=1, UNION SELECT)
- Intentos de XSS (<script>, javascript:)
- Path traversal (../)
- Acceso a archivos sensibles (.env, .git, config)
- User agents sospechosos
- Top IPs con más errores

# Output: Agrega findings y estadísticas
```

#### analyze_fail2ban_logs()
```bash
# Buscar (si fail2ban está instalado):
- IPs baneadas en las últimas 24h
- Servicios más atacados
- Patrones de ataque
- Configuración de fail2ban

# Output: Agrega findings y estadísticas
```

**Técnicas de análisis**:
- Usar `awk` y `sed` para parseo eficiente
- Analizar solo últimas 24 horas por defecto
- Contar ocurrencias y detectar patrones
- Extraer IPs, usuarios, y servicios
- Correlacionar eventos relacionados

### 2.4 Módulo de Verificación del Sistema (lib/system-check.sh)

**Responsabilidad**: Analizar el estado actual del servidor

**Estructura**:
```bash
check_system() {
    collect_system_info
    check_security_updates
    check_firewall
    check_selinux_apparmor
    check_users_and_permissions
    check_suid_files
    check_services
    check_network
    check_filesystem
    check_resources
    check_rootkit_indicators
}
```

**Funciones específicas**:

#### collect_system_info()
```bash
# Recopilar:
- Hostname
- IPs del servidor
- OS y versión
- Kernel version
- Uptime
- Última actualización del sistema
- Arquitectura

# Output: Guarda en SYSTEM_INFO_FILE (JSON)
```

#### check_security_updates()
```bash
# Debian: apt-get -s upgrade | grep "^Inst.*security"
# RedHat: yum list updates --security

# Output: Lista de actualizaciones de seguridad disponibles
# Severidad: HIGH si hay actualizaciones críticas
```

#### check_firewall()
```bash
# Verificar:
- iptables/firewalld/ufw activo
- Reglas configuradas
- Puertos permitidos
- Default policy

# Output: Severidad HIGH si firewall desactivado
```

#### check_selinux_apparmor()
```bash
# RedHat: getenforce
# Debian: aa-status

# Output: Severidad MEDIUM si está en modo permissive/disabled
```

#### check_users_and_permissions()
```bash
# Verificar:
- Usuarios con UID 0 además de root
- Usuarios sin contraseña (/etc/shadow)
- Usuarios con shell (/bin/bash, /bin/sh)
- Últimos logins (last)
- Sesiones activas (who, w)
- Claves SSH autorizadas
- Permisos de /etc/passwd, /etc/shadow
- Archivos .rhosts

# Output: Severidad CRITICAL si usuario sin password o UID 0 extra
```

#### check_suid_files()
```bash
# find / -perm -4000 -type f 2>/dev/null

# Comparar con baseline conocido de archivos SUID legítimos
# Alertar sobre archivos SUID inusuales

# Output: Severidad MEDIUM para SUID nuevos/sospechosos
```

#### check_services()
```bash
# systemctl list-units --type=service --state=running
# o service --status-all

# Verificar:
- Servicios inesperados en ejecución
- Servicios críticos caídos
- Servicios escuchando en 0.0.0.0

# Output: Findings para servicios sospechosos
```

#### check_network()
```bash
# netstat -tulpn o ss -tulpn

# Verificar:
- Puertos abiertos y servicios asociados
- Conexiones establecidas sospechosas
- Servicios escuchando en interfaces públicas

# Output: Lista de puertos abiertos, alertar sobre inesperados
```

#### check_filesystem()
```bash
# df -h
# Verificar particiones > 80%

# find /tmp /var/tmp -type f -executable -mtime -1
# Scripts en /tmp ejecutables recientes

# find /home /root -type f -name ".*" -mtime -7
# Archivos ocultos modificados recientemente

# Output: Severidad HIGH si partición sistema > 90%
```

#### check_resources()
```bash
# Verificar:
- uptime (load average)
- free -m (uso memoria)
- top -b -n 1 (procesos top CPU)
- Procesos zombie

# Output: Severidad MEDIUM si load > número de CPUs
```

#### check_rootkit_indicators()
```bash
# Verificar indicadores básicos:
- Comandos del sistema con checksums diferentes
- Directorios ocultos en /dev
- Procesos ocultos (comparar ps vs /proc)
- Módulos del kernel sospechosos (lsmod)
- Archivos en /tmp con nombres aleatorios

# Si rkhunter está instalado: ejecutar rkhunter --check

# Output: Severidad CRITICAL si se detectan indicadores
```

### 2.5 Módulo de Generación de Informes (lib/report-generator.sh)

**Responsabilidad**: Generar informes en múltiples formatos

**Funciones principales**:

#### generate_reports()
```bash
generate_html_report
generate_text_report
generate_json_report
```

#### generate_html_report()
```bash
# Usar template HTML
# Reemplazar variables:
# {{HOSTNAME}}, {{DATE}}, {{THREAT_LEVEL}}
# {{CRITICAL_COUNT}}, {{HIGH_COUNT}}, etc.
# {{FINDINGS_TABLE}}, {{STATS_SECTION}}

# Incluir:
- CSS inline para email compatibility
- Gráficos usando caracteres Unicode o Canvas
- Colores basados en severidad
- Secciones colapsables
- Tabla de contenidos

# Output: /var/log/security-audit/reports/YYYY-MM-DD.html
```

#### generate_text_report()
```bash
# Formato simple texto plano
# Usar caracteres ASCII para tablas
# 80 columnas máximo
# Secciones claramente delimitadas

# Output: /var/log/security-audit/reports/YYYY-MM-DD.txt
```

#### generate_json_report()
```bash
# Estructura JSON:
{
  "report_info": {
    "date": "2024-01-15",
    "hostname": "server01",
    "threat_level": "HIGH"
  },
  "system_info": { ... },
  "findings": [
    {
      "severity": "CRITICAL",
      "category": "Authentication",
      "title": "Multiple failed SSH attempts",
      "description": "...",
      "evidence": "...",
      "recommendation": "..."
    }
  ],
  "statistics": { ... }
}

# Output: /var/log/security-audit/reports/YYYY-MM-DD.json
```

#### calculate_threat_level()
```bash
# Basado en número y severidad de findings:
# CRITICAL: Si hay 1+ findings CRITICAL
# HIGH: Si hay 3+ findings HIGH
# MEDIUM: Si hay 5+ findings MEDIUM
# LOW: Otherwise

# Output: Variable global THREAT_LEVEL
```

### 2.6 Módulo de Envío de Email (lib/email-sender.sh)

**Responsabilidad**: Enviar informes por email

**Funciones principales**:

#### send_email()
```bash
# Decidir si enviar basado en configuración:
# - SEND_ONLY_ON_ALERTS (solo si hay alertas HIGH/CRITICAL)
# - ALWAYS_SEND (siempre)

# Determinar método de envío:
# 1. msmtp (preferido)
# 2. mailx con SMTP
# 3. sendmail

# Preparar email:
# - Subject con [THREAT_LEVEL] y hostname
# - Body HTML con Content-Type multipart/alternative
# - Fallback texto plano
# - Attachments opcionales

# Enviar a destinatarios configurados
# Logging de éxito/fallo
```

#### send_via_msmtp()
```bash
# Configurar msmtp temporalmente o usar ~/.msmtprc
# Enviar con formato correcto
```

#### send_via_mailx()
```bash
# mailx con opciones SMTP
# Incluir autenticación si es necesaria
```

#### send_via_sendmail()
```bash
# Envío local via sendmail
# Útil si hay MTA local configurado
```

## 3. Flujo de Datos

### 3.1 Datos Temporales

Durante la ejecución, el sistema mantiene archivos JSON temporales:

**findings.json**:
```json
[
  {
    "timestamp": "2024-01-15T06:15:23",
    "severity": "HIGH",
    "category": "Authentication",
    "title": "Multiple SSH failures",
    "description": "15 failed SSH attempts from IP 192.168.1.100",
    "evidence": "Jan 15 06:10:15 server sshd[1234]: Failed password for root...",
    "recommendation": "Consider banning this IP with fail2ban",
    "source_module": "log-analyzer"
  }
]
```

**stats.json**:
```json
{
  "top_failed_ips": [
    {"ip": "192.168.1.100", "count": 15},
    {"ip": "10.0.0.50", "count": 8}
  ],
  "top_failed_users": [
    {"user": "root", "count": 20},
    {"user": "admin", "count": 12}
  ],
  "services_attacked": {
    "ssh": 35,
    "http": 12
  },
  "total_errors": 150,
  "total_warnings": 45
}
```

**system-info.json**:
```json
{
  "hostname": "server01.example.com",
  "ip_addresses": ["192.168.1.10", "10.0.0.5"],
  "os": "Debian GNU/Linux 11 (bullseye)",
  "kernel": "5.10.0-21-amd64",
  "uptime": "45 days, 3:21",
  "last_update": "2024-01-10",
  "cpu_count": 4,
  "memory_total": "8GB",
  "disk_usage": {
    "/": "65%",
    "/home": "45%"
  }
}
```

### 3.2 Persistencia de Datos

**Informes históricos**:
- `/var/log/security-audit/reports/YYYY-MM-DD.{html,txt,json}`
- Retención configurable (por defecto 90 días)
- Rotación automática

**Logs de la herramienta**:
- `/var/log/security-audit/security-audit.log`
- Rotación con logrotate
- Formato: `[YYYY-MM-DD HH:MM:SS] [LEVEL] mensaje`

## 4. Manejo de Errores

### 4.1 Estrategia General

- **Fail-safe**: Si un módulo falla, continuar con los siguientes
- **Logging detallado**: Todos los errores se registran
- **Notificación**: Incluir errores del script en el informe
- **Exit codes**: Usar exit codes estándar

### 4.2 Tipos de Errores

| Error | Acción | Exit Code |
|-------|--------|-----------|
| No se puede leer config | Abortar | 1 |
| Falta dependencia crítica | Abortar | 2 |
| No ejecutado como root | Abortar | 3 |
| Lock file existe | Abortar silenciosamente | 0 |
| Módulo falla | Continuar, registrar error | - |
| No se puede enviar email | Registrar error, continuar | - |
| No se puede escribir informe | Intentar /tmp, sino error crítico | 4 |

### 4.3 Timeouts

- Cada comando crítico con timeout configurable
- Default: 30 segundos por comando
- Total script timeout: 10 minutos

## 5. Seguridad del Sistema

### 5.1 Permisos de Archivos

```
/opt/security-audit/security-audit.sh         755 (root:root)
/opt/security-audit/lib/*.sh                  644 (root:root)
/etc/security-audit/config.conf               600 (root:root)
/var/log/security-audit/                      750 (root:root)
/var/log/security-audit/reports/              750 (root:root)
```

### 5.2 Validación de Inputs

- Sanitizar todos los inputs del archivo de configuración
- Validar formato de emails
- Validar rutas de archivos (no permitir ..)
- Validar comandos antes de ejecutar
- Escapar variables en comandos

### 5.3 Secretos

- Contraseñas SMTP en config.conf (modo 600)
- Opción de usar variables de entorno
- No imprimir secretos en logs
- Limpiar variables sensibles después de uso

## 6. Performance y Optimización

### 6.1 Estrategias de Optimización

- Analizar solo últimas 24 horas de logs (configurable)
- Usar `grep -F` para búsquedas literales (más rápido)
- Limitar resultados con `head -n`
- Paralelización con background jobs donde sea posible
- Cache de comandos costosos

### 6.2 Recursos Limitados

```bash
# Limitar memoria del script
ulimit -v 102400  # 100MB

# Limitar CPU time
ulimit -t 300     # 5 minutos

# Limitar número de procesos
ulimit -u 50
```

## 7. Extensibilidad

### 7.1 Agregar Nuevos Checks

Para agregar un nuevo check de seguridad:

1. Crear función en `lib/system-check.sh`:
```bash
check_mi_nuevo_check() {
    log_info "Ejecutando mi nuevo check..."

    # Lógica del check

    if [[ condicion_problema ]]; then
        add_finding "HIGH" "Mi Categoría" \
            "Título del hallazgo" \
            "Descripción detallada" \
            "Evidencia: $detalle" \
            "Recomendación: hacer X"
    fi
}
```

2. Llamar la función desde `check_system()` en el orden apropiado

3. Documentar el nuevo check en SPECIFICATIONS.md

### 7.2 Agregar Nuevos Formatos de Informe

1. Crear función en `lib/report-generator.sh`:
```bash
generate_xml_report() {
    # Generar XML
}
```

2. Llamar desde `generate_reports()`

### 7.3 Plugins

Posibilidad futura de sistema de plugins:
```
/opt/security-audit/plugins/
├── plugin-name.sh
└── plugin-name.conf
```

Cada plugin implementa interfaz estándar:
```bash
plugin_init()
plugin_analyze()
plugin_report()
```

## 8. Testing

### 8.1 Tipos de Tests

- **Unit tests**: Funciones individuales (usando bats o similar)
- **Integration tests**: Módulos completos
- **System tests**: Script completo en VMs Debian y RedHat
- **Performance tests**: Tiempo de ejecución, uso de memoria

### 8.2 Ambientes de Test

- Docker containers con Debian 10, 11, 12
- Docker containers con Rocky Linux 8, 9
- Scripts de generación de logs de prueba
- Simulación de condiciones de error

## 9. Deployment

### 9.1 Proceso de Instalación

```bash
# install.sh hace:
1. Verificar SO soportado
2. Instalar dependencias (apt/yum)
3. Crear directorios
4. Copiar archivos con permisos correctos
5. Crear config.conf template
6. Configurar cron job
7. Ejecutar primera vez en modo test
```

### 9.2 Configuración Cron

```cron
# /etc/cron.d/security-audit
0 6 * * * root /opt/security-audit/security-audit.sh >> /var/log/security-audit/cron.log 2>&1
```

### 9.3 Actualización

```bash
# update.sh hace:
1. Backup de config actual
2. Descargar nueva versión
3. Reemplazar scripts
4. Mantener configuración
5. Verificar integridad
```

## 10. Monitoreo del Sistema

### 10.1 Monitorear la Herramienta

- Verificar que cron ejecuta correctamente
- Monitorear `/var/log/security-audit/security-audit.log`
- Alertar si no se recibe email diario
- Verificar espacio en disco para informes

### 10.2 Health Check

Script separado `health-check.sh`:
```bash
# Verificar:
- Última ejecución exitosa (< 25 horas)
- Tamaño del log no excesivo
- Espacio en disco suficiente
- Permisos correctos
- Config válida
```

## 11. Diagramas de Secuencia

### 11.1 Ejecución Normal

```
┌──────┐     ┌──────┐     ┌──────────┐     ┌────────┐     ┌───────┐
│ Cron │     │ Main │     │  Log     │     │ System │     │Report │
│      │     │Script│     │ Analyzer │     │ Check  │     │  Gen  │
└──┬───┘     └───┬──┘     └────┬─────┘     └───┬────┘     └───┬───┘
   │             │              │                │              │
   ├─Execute────>│              │                │              │
   │             ├─Load Config──┤                │              │
   │             │              │                │              │
   │             ├─Analyze Logs─>                │              │
   │             │<─Findings────┤                │              │
   │             │              │                │              │
   │             ├─Check System─────────────────>│              │
   │             │<─Findings─────────────────────┤              │
   │             │              │                │              │
   │             ├─Generate Report──────────────────────────────>
   │             │<─Report Files────────────────────────────────┤
   │             │              │                │              │
   │             ├─Send Email───┤                │              │
   │<─Complete───┤              │                │              │
   │             │              │                │              │
```

### 11.2 Manejo de Error en Módulo

```
┌──────┐     ┌──────────┐     ┌────────┐
│ Main │     │  Module  │     │  Log   │
│Script│     │          │     │        │
└──┬───┘     └────┬─────┘     └───┬────┘
   │              │                │
   ├─Execute─────>│                │
   │              ├─Error occurs   │
   │              ├─Log Error─────>│
   │<─Continue────┤                │
   │              │                │
   ├─Execute Next Module           │
   │              │                │
   ├─Include Error in Report       │
   │              │                │
```

## 12. Consideraciones Futuras

### 12.1 Mejoras Potenciales

- **Machine Learning**: Detectar anomalías basado en patrones históricos
- **API REST**: Exponer datos vía API
- **Dashboard Web**: Visualización interactiva de informes
- **Integración SIEM**: Exportar a Splunk, ELK, etc.
- **Agente centralizado**: Múltiples servidores reportando a central
- **Base de datos**: Almacenar históricos en DB para análisis
- **Correlación avanzada**: Correlacionar eventos entre múltiples logs
- **Firma digital**: Firmar informes para no-repudiación

### 12.2 Escalabilidad

- Soporte para análisis distribuido
- Cola de trabajos para servidores muy cargados
- Compresión de informes históricos
- Análisis incremental (solo nuevos eventos)

### 12.3 Integración con Otras Herramientas

- Osquery: Queries de seguridad avanzadas
- Wazuh: HIDS completo
- TheHive: Gestión de incidentes
- MISP: Threat intelligence
- Grafana: Visualización de métricas
