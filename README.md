# Security Audit - Sistema de Auditoría de Seguridad Automatizado

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![OS](https://img.shields.io/badge/os-Debian%20%7C%20RedHat-green.svg)]()
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)]()

Sistema automatizado de análisis de seguridad para servidores Linux (Debian/RedHat) que analiza logs del sistema, verifica el estado de seguridad y genera informes detallados enviados por email diariamente.

## Características Principales

- **Análisis completo de logs de seguridad**
  - Autenticación SSH (intentos fallidos, accesos root)
  - Logs del sistema (errores críticos, servicios caídos)
  - Logs del kernel (errores hardware, OOM)
  - Logs de aplicaciones web (Apache/Nginx)
  - Fail2ban (IPs baneadas, patrones de ataque)

- **Verificación del estado del servidor**
  - Actualizaciones de seguridad disponibles
  - Estado del firewall (iptables/firewalld/ufw)
  - SELinux/AppArmor
  - Usuarios y permisos (UID 0, usuarios sin password)
  - Archivos SUID/SGID sospechosos
  - Servicios en ejecución
  - Puertos abiertos y conexiones de red
  - Uso de recursos (CPU, memoria, disco)
  - Indicadores básicos de rootkits

- **Sistema de alertas por severidad**
  - CRÍTICO: Requiere acción inmediata
  - ALTO: Requiere atención pronto
  - MEDIO: Debe revisarse
  - BAJO: Informativo

- **Informes multi-formato**
  - HTML con formato visual profesional
  - TXT para lectura en terminal
  - JSON para integración con otras herramientas

- **Envío automático por email**
  - Soporte SMTP con autenticación
  - TLS/SSL
  - Múltiples destinatarios
  - Envío condicional (solo con alertas críticas/altas)

- **Compatible con Debian y RedHat**
  - Detección automática del tipo de sistema
  - Soporte para Debian 10, 11, 12
  - Soporte para RHEL/CentOS/Rocky/AlmaLinux 7, 8, 9

## Capturas de Pantalla

### Informe HTML
```
┌─────────────────────────────────────────────────────────────┐
│ INFORME DE SEGURIDAD - SERVER01.EXAMPLE.COM                │
│ Fecha: 2024-01-15 06:00:00 | Nivel de Amenaza: ALTO        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 📊 RESUMEN                                                  │
│   Crítico: 2 | Alto: 5 | Medio: 8 | Bajo: 15               │
│                                                             │
│ 🚨 HALLAZGOS CRÍTICOS                                       │
│   • 25 intentos fallidos de acceso SSH como root           │
│     desde IP 192.168.1.100                                  │
│   • Firewall desactivado                                    │
│                                                             │
│ ⚠️  HALLAZGOS ALTOS                                         │
│   • 15 actualizaciones de seguridad disponibles             │
│   • Usuario 'test' sin contraseña                           │
│   • Puerto 3306 (MySQL) expuesto públicamente               │
│                                                             │
│ 📈 ESTADÍSTICAS                                             │
│   Top IPs atacantes:                                        │
│     192.168.1.100: 25 intentos                              │
│     10.0.0.50: 8 intentos                                   │
│                                                             │
│ 💡 RECOMENDACIONES                                          │
│   1. Banear IP 192.168.1.100 inmediatamente                 │
│   2. Activar firewall                                       │
│   3. Aplicar actualizaciones de seguridad                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Instalación Rápida

### Requisitos Previos

- Sistema operativo: Debian 10+ o RHEL/CentOS/Rocky 7+
- Acceso root
- Conexión a Internet (para instalación de dependencias)

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/security-audit.git
cd security-audit

# Ejecutar script de instalación como root
sudo ./install.sh

# Configurar email (IMPORTANTE - ver EMAIL_SETUP.md)
sudo nano /etc/security-audit/config.conf

# Probar envío de email
sudo /opt/security-audit/security-audit.sh --test-email

# Ejecutar primera vez manualmente para verificar
sudo /opt/security-audit/security-audit.sh --no-email
```

**Documentación**:
- [INSTALL.md](INSTALL.md) - Guía detallada de instalación
- **[EMAIL_SETUP.md](EMAIL_SETUP.md) - Configuración de email (msmtp, Postfix, Gmail, etc.)**

## Desinstalación

Para desinstalar Security Audit del sistema:

```bash
sudo ./uninstall.sh
```

El script de desinstalación:
- Detecta automáticamente los componentes instalados
- Muestra el espacio en disco a liberar
- Ofrece crear un backup antes de eliminar (configuración, logs, informes)
- Pide confirmación antes de proceder
- Elimina de forma segura todos los componentes:
  - Scripts y ejecutables
  - Configuración
  - Logs e informes
  - Tareas cron
  - Configuración de logrotate

También puedes desinstalar manualmente. Consulta [INSTALL.md](INSTALL.md) para más detalles.

## Configuración

El archivo de configuración principal está en `/etc/security-audit/config.conf`:

```bash
# Configuración de Email
EMAIL_TO="admin@example.com,security@example.com"
EMAIL_FROM="security-audit@server.example.com"
EMAIL_SUBJECT_PREFIX="[Security Audit]"

# Configuración SMTP
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
SMTP_TLS="yes"

# Opciones de envío
SEND_ONLY_ON_ALERTS="yes"  # yes/no
MIN_SEVERITY_TO_SEND="HIGH" # CRITICAL/HIGH/MEDIUM/LOW

# Período de análisis de logs
LOG_ANALYSIS_HOURS="24"  # Analizar últimas 24 horas

# Umbrales de alertas
FAILED_SSH_THRESHOLD="10"  # Alertar si > 10 intentos fallidos
DISK_USAGE_THRESHOLD="80"  # Alertar si disco > 80%

# Directorios
REPORT_DIR="/var/log/security-audit/reports"
TEMP_DIR="/tmp/security-audit"
LOG_FILE="/var/log/security-audit/security-audit.log"

# Retención de informes (días)
REPORT_RETENTION_DAYS="90"

# Debug mode
DEBUG="no"
```

## Uso

### Ejecución Manual

```bash
# Ejecución normal
sudo /opt/security-audit/security-audit.sh

# Modo debug
sudo /opt/security-audit/security-audit.sh --debug

# Generar informe sin enviar email
sudo /opt/security-audit/security-audit.sh --no-email

# Analizar período específico (últimas 48 horas)
sudo /opt/security-audit/security-audit.sh --hours 48

# Solo generar informe HTML
sudo /opt/security-audit/security-audit.sh --format html

# Ver ayuda
sudo /opt/security-audit/security-audit.sh --help
```

### Ejecución Automática (Cron)

El script se instala automáticamente en cron para ejecutarse diariamente a las 6:00 AM:

```bash
# Ver configuración de cron
cat /etc/cron.d/security-audit

# Editar hora de ejecución
sudo crontab -e
```

### Ver Informes Históricos

```bash
# Listar informes
ls -lh /var/log/security-audit/reports/

# Ver último informe HTML
cat /var/log/security-audit/reports/$(ls -t /var/log/security-audit/reports/*.html | head -1)

# Ver último informe TXT
cat /var/log/security-audit/reports/$(ls -t /var/log/security-audit/reports/*.txt | head -1)

# Analizar JSON con jq
cat /var/log/security-audit/reports/2024-01-15.json | jq '.findings[] | select(.severity=="CRITICAL")'
```

### Ver Logs de la Herramienta

```bash
# Ver últimas ejecuciones
tail -f /var/log/security-audit/security-audit.log

# Buscar errores
grep ERROR /var/log/security-audit/security-audit.log
```

## Arquitectura del Sistema

```
/opt/security-audit/
├── security-audit.sh          # Script principal
├── lib/
│   ├── common.sh              # Funciones comunes
│   ├── log-analyzer.sh        # Análisis de logs
│   ├── system-check.sh        # Verificaciones del sistema
│   ├── report-generator.sh    # Generación de informes
│   └── email-sender.sh        # Envío de emails
├── templates/
│   ├── report.html            # Plantilla HTML
│   └── report.txt             # Plantilla texto
└── README.md

/etc/security-audit/
├── config.conf                # Configuración principal
└── exclusions.conf            # Exclusiones (IPs, usuarios, etc.)

/var/log/security-audit/
├── security-audit.log         # Log de la herramienta
└── reports/                   # Informes históricos
    ├── 2024-01-15.html
    ├── 2024-01-15.txt
    └── 2024-01-15.json
```

Ver [ARCHITECTURE.md](ARCHITECTURE.md) para detalles completos de la arquitectura.

## Qué Detecta

### Análisis de Logs

| Categoría | Detecciones |
|-----------|-------------|
| **Autenticación** | Intentos fallidos SSH, acceso root, sudo fallido, sesiones inusuales |
| **Sistema** | Servicios caídos, errores críticos, reinicios inesperados |
| **Kernel** | Errores hardware, OOM killer, segfaults |
| **Web** | SQL injection, XSS, path traversal, códigos 4xx/5xx |
| **Network** | IPs baneadas por fail2ban, patrones de ataque |

### Verificaciones del Sistema

| Categoría | Verificaciones |
|-----------|----------------|
| **Actualizaciones** | Actualizaciones de seguridad disponibles |
| **Firewall** | Estado activo, reglas configuradas |
| **SELinux/AppArmor** | Estado enforcing/enabled |
| **Usuarios** | UID 0 extra, sin password, últimos logins |
| **Permisos** | Archivos SUID/SGID sospechosos, permisos sensibles |
| **Servicios** | Servicios en ejecución, puertos abiertos |
| **Red** | Conexiones establecidas, puertos inesperados |
| **Disco** | Uso de particiones, archivos en /tmp ejecutables |
| **Recursos** | Load average, memoria, CPU, procesos zombie |
| **Rootkits** | Indicadores básicos, verificación con rkhunter |

## Niveles de Severidad

| Nivel | Descripción | Ejemplos | Acción |
|-------|-------------|----------|--------|
| **CRÍTICO** | Amenaza inmediata | Múltiples intentos de acceso root, rootkit detectado, sistema lleno | Acción inmediata |
| **ALTO** | Requiere atención pronto | Firewall desactivado, usuario sin password, actualizaciones críticas | Atender en horas |
| **MEDIO** | Debe revisarse | Uso elevado de disco, errores frecuentes, SUID nuevos | Revisar en días |
| **BAJO** | Informativo | Estadísticas normales, logins regulares | Información |

## Exclusiones

Puedes excluir ciertos elementos del análisis editando `/etc/security-audit/exclusions.conf`:

```bash
# IPs a excluir del análisis de intentos fallidos
EXCLUDE_IPS="192.168.1.5,10.0.0.10"

# Usuarios a excluir del análisis
EXCLUDE_USERS="backup,monitoring"

# Servicios a excluir
EXCLUDE_SERVICES="my-custom-service"

# Puertos a excluir del análisis de puertos abiertos
EXCLUDE_PORTS="8080,9000"

# Archivos SUID conocidos (paths completos)
KNOWN_SUID_FILES="/usr/bin/custom-tool,/opt/app/binary"
```

## Solución de Problemas

### El email no se envía

**IMPORTANTE**: Ver [EMAIL_SETUP.md](EMAIL_SETUP.md) para una guía completa de configuración de email con múltiples opciones (msmtp, Postfix, Sendmail, etc.)

```bash
# Verificar configuración SMTP y obtener diagnóstico detallado
sudo /opt/security-audit/security-audit.sh --test-email

# Verificar que msmtp/mailx está instalado
which msmtp mailx sendmail

# Verificar logs
grep "email" /var/log/security-audit/security-audit.log

# Probar envío manual con msmtp
echo "Test" | msmtp -a default your-email@example.com

# Ver logs de msmtp
tail -f /var/log/msmtp.log
```

**Errores comunes**:

- **"account default not found"**: msmtp no está configurado. Crear `/etc/msmtprc` (ver EMAIL_SETUP.md)
- **"authentication failed"** con Gmail: Usar App Password en lugar de contraseña normal
- **Email llega a spam**: Configurar SPF/DKIM en tu dominio

Ver documentación completa: [EMAIL_SETUP.md](EMAIL_SETUP.md)

### El script no se ejecuta en cron

```bash
# Verificar que cron está activo
systemctl status cron   # Debian
systemctl status crond  # RedHat

# Verificar configuración
cat /etc/cron.d/security-audit

# Ver logs de cron
grep security-audit /var/log/syslog  # Debian
grep security-audit /var/log/cron    # RedHat
```

### El script falla

```bash
# Ejecutar en modo debug
sudo /opt/security-audit/security-audit.sh --debug

# Verificar permisos
sudo ls -la /opt/security-audit/
sudo ls -la /etc/security-audit/

# Verificar dependencias
sudo /opt/security-audit/security-audit.sh --check-deps

# Ver log completo
sudo tail -100 /var/log/security-audit/security-audit.log
```

### No se generan informes

```bash
# Verificar espacio en disco
df -h /var/log

# Verificar permisos del directorio
sudo ls -la /var/log/security-audit/

# Crear manualmente si no existe
sudo mkdir -p /var/log/security-audit/reports
sudo chmod 750 /var/log/security-audit/reports
```

## Seguridad

### Permisos

El script maneja información sensible. Asegúrate de que los permisos sean restrictivos:

```bash
# Verificar permisos
sudo chmod 600 /etc/security-audit/config.conf
sudo chmod 755 /opt/security-audit/security-audit.sh
sudo chmod 750 /var/log/security-audit/
```

### Contraseñas

- Nunca commitees config.conf con contraseñas a repositorios
- Usa app passwords en lugar de contraseñas principales (Gmail)
- Considera usar variables de entorno para secretos
- Rota contraseñas regularmente

### Acceso

- Solo root debe poder ejecutar el script
- Solo root debe poder leer los informes (contienen información sensible)
- Limita acceso SSH al servidor que ejecuta el script

## Performance

### Recursos Utilizados

- **CPU**: < 5% durante ejecución
- **Memoria**: < 100 MB
- **Tiempo de ejecución**: 2-5 minutos (depende del tamaño de logs)
- **Espacio en disco**: ~10MB por informe

### Optimización

```bash
# Reducir período de análisis
LOG_ANALYSIS_HOURS="12"  # en config.conf

# Limitar tamaño de logs analizados
# Configurar logrotate para logs del sistema

# Excluir logs no necesarios
ANALYZE_WEB_LOGS="no"
```

## Integración con Otras Herramientas

### Splunk/ELK

Puedes enviar los informes JSON a Splunk o ELK:

```bash
# Agregar al final del script
curl -X POST "http://your-logstash:5000" \
  -H "Content-Type: application/json" \
  -d @/var/log/security-audit/reports/$(date +%Y-%m-%d).json
```

### Slack/Discord

Enviar notificaciones a Slack:

```bash
# En lib/email-sender.sh, agregar
send_slack_notification() {
    SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$MENSAJE\"}" \
      $SLACK_WEBHOOK
}
```

### Grafana

Visualizar métricas en Grafana importando los JSON reports a una base de datos.

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

### Guidelines

- Mantén el código compatible con bash 4.0+
- Agrega comentarios en español
- Prueba en Debian y RedHat antes de hacer PR
- Actualiza la documentación si es necesario

## Roadmap

### Versión 1.0 (Actual)
- [x] Análisis básico de logs
- [x] Checks del sistema
- [x] Informes HTML/TXT/JSON
- [x] Envío por email

### Versión 1.1 (Próximamente)
- [ ] Dashboard web interactivo
- [ ] Detección de anomalías con ML básico
- [ ] Soporte para más distribuciones (Ubuntu, openSUSE)
- [ ] Plugins para análisis personalizados

### Versión 2.0 (Futuro)
- [ ] Agente centralizado multi-servidor
- [ ] API REST
- [ ] Integración con SIEM
- [ ] Base de datos para históricos
- [ ] Correlación avanzada de eventos

## FAQ

**P: ¿Funciona en Ubuntu?**
R: Sí, Ubuntu está basado en Debian. Debería funcionar sin problemas.

**P: ¿Puedo ejecutarlo cada hora?**
R: Sí, pero puede generar muchos informes. Ajusta el cron según necesites.

**P: ¿Funciona con systemd-journald?**
R: Sí, también analiza journalctl además de archivos en /var/log.

**P: ¿Requiere conexión a Internet?**
R: Solo para enviar emails. El análisis funciona offline.

**P: ¿Afecta el rendimiento del servidor?**
R: Impacto mínimo. Usa nice para reducir prioridad si es necesario.

**P: ¿Es compatible con Docker?**
R: Sí, pero necesitas montar /var/log del host.

**P: ¿Funciona con SELinux en modo enforcing?**
R: Sí, el script respeta las políticas de SELinux.

## Licencia

MIT License - Ver [LICENSE](LICENSE) para detalles.

## Soporte

- **Issues**: https://github.com/tu-usuario/security-audit/issues
- **Documentación**: https://github.com/tu-usuario/security-audit/wiki
- **Email**: soporte@example.com

## Autores

- Desarrollador Principal - [@tu-usuario](https://github.com/tu-usuario)

## Agradecimientos

- Comunidad de seguridad de Linux
- Proyectos de código abierto: Lynis, rkhunter, fail2ban
- Todos los contribuidores

## Disclaimer

Esta herramienta se proporciona "tal cual" sin garantías. El análisis automatizado no reemplaza una auditoría de seguridad profesional. Úsala como parte de una estrategia de seguridad más amplia.

---

**⚠️ IMPORTANTE**: Esta herramienta requiere acceso root y analiza información sensible del sistema. Úsala responsablemente y protege adecuadamente los informes generados.
