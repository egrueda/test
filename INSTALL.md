# Guía de Instalación - Security Audit Script

Esta guía detalla el proceso completo de instalación y configuración del Security Audit Script.

## Tabla de Contenidos

1. [Requisitos del Sistema](#requisitos-del-sistema)
2. [Instalación Rápida](#instalación-rápida)
3. [Instalación Manual](#instalación-manual)
4. [Configuración](#configuración)
5. [Configuración de Email](#configuración-de-email)
6. [Verificación](#verificación)
7. [Solución de Problemas](#solución-de-problemas)

## Requisitos del Sistema

### Sistemas Operativos Soportados

- **Debian**: 10 (Buster), 11 (Bullseye), 12 (Bookworm)
- **Ubuntu**: 18.04+, 20.04+, 22.04+
- **RedHat Enterprise Linux**: 7, 8, 9
- **CentOS**: 7, 8
- **Rocky Linux**: 8, 9
- **AlmaLinux**: 8, 9

### Requisitos Mínimos

- **CPU**: 1 core
- **RAM**: 512 MB
- **Disco**: 100 MB de espacio libre
- **Acceso**: Root (sudo)
- **Red**: Conexión a Internet (para instalación y envío de emails)

### Dependencias Requeridas

El script de instalación instalará automáticamente las siguientes dependencias:

#### Debian/Ubuntu
```bash
- mailutils o bsd-mailx
- msmtp (opcional, para SMTP)
- net-tools (netstat)
- cron
- logrotate
- jq (para procesamiento JSON)
- curl/wget
```

#### RedHat/CentOS/Rocky/Alma
```bash
- mailx
- net-tools
- cronie
- logrotate
- jq
- curl/wget
```

### Dependencias Opcionales

Estas dependencias mejoran las capacidades del script:

- **rkhunter**: Detección avanzada de rootkits
- **lynis**: Auditorías de seguridad adicionales
- **fail2ban**: Análisis de IPs baneadas

## Instalación Rápida

### Método 1: Con Git

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/security-audit.git
cd security-audit

# Ejecutar instalador
sudo ./install.sh
```

### Método 2: Descarga Directa

```bash
# Descargar
wget https://github.com/tu-usuario/security-audit/archive/refs/heads/main.zip
unzip main.zip
cd security-audit-main

# Ejecutar instalador
sudo ./install.sh
```

### Proceso de Instalación Interactivo

El script de instalación te guiará a través de:

1. **Detección del sistema operativo**
2. **Instalación de dependencias**
3. **Creación de directorios**
4. **Copia de archivos**
5. **Configuración de permisos**
6. **Configuración de cron**
7. **Configuración de email** (interactiva)
8. **Prueba de funcionamiento**

Ejemplo de sesión de instalación:

```
╔═══════════════════════════════════════════════════════════════╗
║        Security Audit - Script de Auditoría de Seguridad     ║
║                         Versión 1.0.0                         ║
╚═══════════════════════════════════════════════════════════════╝

[INFO] Iniciando instalación de Security Audit...

[INFO] Detectando sistema operativo...
[OK] Sistema detectado: Ubuntu 22.04 (Debian-based)

[INFO] Verificando dependencias del sistema...
[OK] Todas las dependencias básicas están presentes

[INFO] Instalando dependencias necesarias...
[OK] Dependencias instaladas

[INFO] ¿Desea instalar dependencias opcionales? (rkhunter, lynis, fail2ban)
Responder [y/N]: y
[OK] Dependencias opcionales instaladas

[INFO] Creando estructura de directorios...
[OK] Directorios creados

[INFO] Copiando archivos del sistema...
[OK] Script principal copiado
[OK] Librerías copiadas
[OK] Templates copiados
[OK] Archivo de configuración creado (debes editarlo)

[INFO] Configurando permisos...
[OK] Permisos configurados

[INFO] Configurando tarea cron...
[INFO] ¿A qué hora deseas que se ejecute el análisis diario?
Hora (0-23) [6]: 6
Minuto (0-59) [0]: 0
[OK] Cron configurado para ejecutarse diariamente a las 6:0

[INFO] Configurando rotación de logs...
[OK] Logrotate configurado

[INFO]
════════════════════════════════════════════════════════════
             CONFIGURACIÓN DE EMAIL
════════════════════════════════════════════════════════════

Por favor, configura los parámetros de email para recibir los informes.

Email destinatario [root@localhost]: admin@example.com
Email remitente [security-audit@server.local]: security@server.local
Servidor SMTP [localhost]: smtp.gmail.com
Puerto SMTP [25]: 587
Usuario SMTP (vacío si no requiere auth): myemail@gmail.com
Contraseña SMTP: ****************
Usar TLS? [y/N]: y
[OK] Configuración de email actualizada

[INFO] ¿Deseas ejecutar una prueba manual del script? [Y/n]: y
[INFO] Ejecutando análisis de prueba...
[INFO] (Esto puede tomar unos minutos)

[OK] ¡Instalación completada exitosamente!
```

## Instalación Manual

Si prefieres instalar manualmente:

### 1. Crear Directorios

```bash
sudo mkdir -p /opt/security-audit/{lib,templates}
sudo mkdir -p /etc/security-audit
sudo mkdir -p /var/log/security-audit/reports
sudo mkdir -p /var/lib/security-audit
```

### 2. Copiar Archivos

```bash
# Script principal
sudo cp security-audit.sh /opt/security-audit/
sudo chmod 755 /opt/security-audit/security-audit.sh

# Librerías
sudo cp -r lib/* /opt/security-audit/lib/
sudo chmod 644 /opt/security-audit/lib/*.sh

# Templates
sudo cp -r templates/* /opt/security-audit/templates/
sudo chmod 644 /opt/security-audit/templates/*

# Configuración
sudo cp config/config.conf.example /etc/security-audit/config.conf
sudo chmod 600 /etc/security-audit/config.conf
```

### 3. Configurar Permisos

```bash
sudo chown -R root:root /opt/security-audit
sudo chown -R root:root /etc/security-audit
sudo chown -R root:root /var/log/security-audit
sudo chmod 750 /var/log/security-audit
```

### 4. Instalar Dependencias

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y mailutils msmtp net-tools cron logrotate jq curl
```

#### RedHat/CentOS/Rocky/Alma
```bash
sudo yum install -y mailx net-tools cronie logrotate jq curl
```

### 5. Configurar Cron

Crear `/etc/cron.d/security-audit`:

```bash
# Security Audit - Ejecución diaria
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Ejecutar todos los días a las 6:00
0 6 * * * root /opt/security-audit/security-audit.sh >> /var/log/security-audit/cron.log 2>&1
```

```bash
sudo chmod 644 /etc/cron.d/security-audit
```

### 6. Configurar Logrotate

Crear `/etc/logrotate.d/security-audit`:

```
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
```

## Configuración

### Archivo de Configuración Principal

Editar `/etc/security-audit/config.conf`:

```bash
sudo nano /etc/security-audit/config.conf
```

### Parámetros Esenciales

```bash
# Email destinatario (obligatorio)
EMAIL_TO="admin@example.com,security@example.com"

# Email remitente
EMAIL_FROM="security-audit@server.example.com"

# Servidor SMTP
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
SMTP_TLS="yes"
```

### Parámetros Opcionales

```bash
# Enviar solo si hay alertas
SEND_ONLY_ON_ALERTS="yes"

# Severidad mínima
MIN_SEVERITY_TO_SEND="HIGH"

# Horas de logs a analizar
LOG_ANALYSIS_HOURS="24"

# Umbrales
FAILED_SSH_THRESHOLD="10"
DISK_USAGE_THRESHOLD="80"
```

## Configuración de Email

### Gmail

1. **Habilitar verificación en dos pasos**:
   - Ir a https://myaccount.google.com/security
   - Activar "Verificación en dos pasos"

2. **Crear App Password**:
   - Ir a https://myaccount.google.com/apppasswords
   - Seleccionar "Correo" y tu dispositivo
   - Copiar la contraseña generada (16 caracteres)

3. **Configurar en config.conf**:
```bash
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="tu-email@gmail.com"
SMTP_PASSWORD="xxxx xxxx xxxx xxxx"  # App Password
SMTP_TLS="yes"
```

### Outlook/Hotmail

```bash
SMTP_HOST="smtp-mail.outlook.com"
SMTP_PORT="587"
SMTP_USER="tu-email@outlook.com"
SMTP_PASSWORD="tu-contraseña"
SMTP_TLS="yes"
```

### Yahoo

```bash
SMTP_HOST="smtp.mail.yahoo.com"
SMTP_PORT="587"
SMTP_USER="tu-email@yahoo.com"
SMTP_PASSWORD="app-password"
SMTP_TLS="yes"
```

### SendGrid

```bash
SMTP_HOST="smtp.sendgrid.net"
SMTP_PORT="587"
SMTP_USER="apikey"
SMTP_PASSWORD="tu-api-key"
SMTP_TLS="yes"
```

### Servidor SMTP Local

Si tienes postfix, sendmail u otro MTA local configurado:

```bash
SMTP_HOST="localhost"
SMTP_PORT="25"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_TLS="no"
```

### Configurar msmtp (Recomendado)

Crear `~/.msmtprc` o `/etc/msmtprc`:

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           security-audit@example.com
user           tu-email@gmail.com
password       tu-app-password

account default : gmail
```

Permisos:
```bash
sudo chmod 600 /etc/msmtprc
```

## Verificación

### 1. Verificar Instalación

```bash
# Verificar que el script existe y tiene permisos
ls -l /opt/security-audit/security-audit.sh

# Debería mostrar:
# -rwxr-xr-x 1 root root XXXXX ... /opt/security-audit/security-audit.sh
```

### 2. Verificar Configuración

```bash
# Verificar sintaxis del config
sudo cat /etc/security-audit/config.conf | grep -E "^[A-Z_]+="
```

### 3. Verificar Dependencias

```bash
sudo /opt/security-audit/security-audit.sh --check-deps
```

Debería mostrar:
```
Todas las dependencias OK
```

### 4. Ejecutar Prueba (Sin Email)

```bash
sudo /opt/security-audit/security-audit.sh --no-email
```

Verificar que se generó el informe:
```bash
ls -lh /var/log/security-audit/reports/
```

### 5. Probar Envío de Email

```bash
sudo /opt/security-audit/security-audit.sh --test-email
```

Verifica tu bandeja de entrada.

### 6. Ejecutar Análisis Completo

```bash
sudo /opt/security-audit/security-audit.sh
```

### 7. Verificar Cron

```bash
# Ver configuración de cron
cat /etc/cron.d/security-audit

# Ver logs de cron (Debian)
sudo grep security-audit /var/log/syslog

# Ver logs de cron (RedHat)
sudo grep security-audit /var/log/cron
```

## Solución de Problemas

### Email No Se Envía

**Problema**: No llega el email

**Soluciones**:

1. **Verificar configuración SMTP**:
```bash
sudo /opt/security-audit/security-audit.sh --test-email
```

2. **Verificar logs**:
```bash
sudo tail -50 /var/log/security-audit/security-audit.log | grep -i email
```

3. **Probar msmtp manualmente**:
```bash
echo "Test" | msmtp -a default tu-email@example.com
```

4. **Verificar puertos**:
```bash
# Puerto 587 abierto?
nc -zv smtp.gmail.com 587
```

5. **Para Gmail**: Asegúrate de usar App Password, no contraseña normal

### Script No Se Ejecuta

**Problema**: El script no hace nada

**Soluciones**:

1. **Verificar permisos**:
```bash
ls -l /opt/security-audit/security-audit.sh
# Debe tener: -rwxr-xr-x
```

2. **Ejecutar como root**:
```bash
sudo /opt/security-audit/security-audit.sh --debug
```

3. **Verificar lock file**:
```bash
# Si existe, el script ya está corriendo
ls -l /var/run/security-audit.lock

# Si no está corriendo, eliminarlo
sudo rm /var/run/security-audit.lock
```

### Cron No Ejecuta

**Problema**: El cron no se ejecuta

**Soluciones**:

1. **Verificar que cron está activo**:
```bash
# Debian
sudo systemctl status cron

# RedHat
sudo systemctl status crond
```

2. **Verificar archivo cron**:
```bash
cat /etc/cron.d/security-audit
```

3. **Ver logs de cron**:
```bash
# Debian
sudo tail -f /var/log/syslog | grep CRON

# RedHat
sudo tail -f /var/log/cron
```

4. **Verificar permisos**:
```bash
ls -l /etc/cron.d/security-audit
# Debe ser: -rw-r--r--
```

### No Se Generan Informes

**Problema**: No hay archivos en /var/log/security-audit/reports/

**Soluciones**:

1. **Verificar espacio en disco**:
```bash
df -h /var/log
```

2. **Verificar permisos del directorio**:
```bash
ls -ld /var/log/security-audit/reports
# Debe ser: drwxr-x--- root root
```

3. **Crear directorio manualmente**:
```bash
sudo mkdir -p /var/log/security-audit/reports
sudo chmod 750 /var/log/security-audit/reports
sudo chown root:root /var/log/security-audit/reports
```

4. **Ejecutar en modo debug**:
```bash
sudo /opt/security-audit/security-audit.sh --debug --no-email
```

### Errores de Dependencias

**Problema**: Faltan comandos

**Soluciones**:

1. **Verificar qué falta**:
```bash
sudo /opt/security-audit/security-audit.sh --check-deps
```

2. **Instalar manualmente** (Debian):
```bash
sudo apt-get install mailutils msmtp net-tools jq
```

3. **Instalar manualmente** (RedHat):
```bash
sudo yum install mailx net-tools jq
```

### Permisos Inseguros

**Problema**: Advertencia sobre permisos de config.conf

**Solución**:
```bash
sudo chmod 600 /etc/security-audit/config.conf
sudo chown root:root /etc/security-audit/config.conf
```

## Actualización

Para actualizar a una nueva versión:

```bash
cd security-audit
git pull

# Reinstalar (preserva configuración automáticamente)
sudo ./install.sh
```

**¿Qué sucede durante la actualización?**

1. **Backup automático**: El script detecta si existe `/etc/security-audit/config.conf` y automáticamente crea un backup con timestamp (ej: `config.conf.backup.20241105_120000`)

2. **Preservación de configuración**: Durante la instalación, se te preguntará:
   ```
   Se detectó una configuración existente.

   Configuración actual:
     Email destinatario: admin@example.com
     Email remitente:    security-audit@server.local
     Servidor SMTP:      smtp.gmail.com:587
     Usuario SMTP:       myemail@gmail.com
     TLS:                yes

   ¿Deseas mantener esta configuración? [Y/n]:
   ```

3. **Opciones**:
   - Presiona **Enter** o **Y**: Mantiene toda la configuración existente (recomendado)
   - Presiona **n**: Te permite reconfigurar todos los parámetros usando los valores anteriores como predeterminados

4. **Scripts actualizados**: Solo se actualizan los scripts en `/opt/security-audit/`, tu configuración en `/etc/security-audit/` permanece intacta

**Ver backups de configuración**:

```bash
ls -lh /etc/security-audit/config.conf.backup.*
```

**Restaurar configuración previa**:

```bash
# Ver diferencias
diff /etc/security-audit/config.conf /etc/security-audit/config.conf.backup.20241105_120000

# Restaurar si es necesario
sudo cp /etc/security-audit/config.conf.backup.20241105_120000 /etc/security-audit/config.conf
```

**Actualización manual de configuración**:

Si prefieres no usar el instalador interactivo:

```bash
# Actualizar solo los scripts
cd security-audit
sudo cp security-audit.sh /opt/security-audit/
sudo cp -r lib/* /opt/security-audit/lib/
sudo cp -r templates/* /opt/security-audit/templates/

# Tu configuración en /etc/security-audit/config.conf NO se modifica
```

## Desinstalación

Para desinstalar completamente:

```bash
# Eliminar cron
sudo rm /etc/cron.d/security-audit

# Eliminar logrotate
sudo rm /etc/logrotate.d/security-audit

# Eliminar archivos (CUIDADO: elimina logs e informes)
sudo rm -rf /opt/security-audit
sudo rm -rf /etc/security-audit
sudo rm -rf /var/log/security-audit
sudo rm -rf /var/lib/security-audit
```

Para mantener los informes históricos:
```bash
# Backup de informes
sudo cp -r /var/log/security-audit/reports ~/security-audit-reports-backup

# Luego desinstalar
```

## Soporte

Si tienes problemas:

1. Consulta la documentación completa en [README.md](README.md)
2. Revisa los logs: `/var/log/security-audit/security-audit.log`
3. Abre un issue en GitHub: https://github.com/tu-usuario/security-audit/issues
4. Email: soporte@example.com
