# Configuración de Email para Security Audit

Este documento describe cómo configurar el envío de emails para el script de Security Audit.

## Opción 1: msmtp (RECOMENDADO)

msmtp es una herramienta ligera y fácil de configurar para enviar emails vía SMTP.

### Instalación

```bash
# Debian/Ubuntu
apt-get install msmtp msmtp-mta

# RedHat/CentOS/Rocky
yum install msmtp
```

### Configuración

Crear el archivo `/etc/msmtprc`:

```bash
nano /etc/msmtprc
```

#### Para Gmail

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp.gmail.com
port           587
from           tu-email@gmail.com
user           tu-email@gmail.com
password       xxxx-xxxx-xxxx-xxxx
```

**IMPORTANTE para Gmail**: Debes crear una "App Password" (no uses tu contraseña normal):

1. Habilitar verificación en dos pasos: https://myaccount.google.com/security
2. Crear App Password: https://myaccount.google.com/apppasswords
3. Seleccionar "Correo" y tu dispositivo
4. Copiar la contraseña de 16 caracteres generada

#### Para Outlook/Hotmail

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp-mail.outlook.com
port           587
from           tu-email@outlook.com
user           tu-email@outlook.com
password       tu-contraseña
```

#### Para Yahoo

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp.mail.yahoo.com
port           587
from           tu-email@yahoo.com
user           tu-email@yahoo.com
password       tu-app-password
```

#### Para un servidor SMTP corporativo

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp.tuempresa.com
port           587
from           alertas@tuempresa.com
user           usuario-smtp
password       contraseña-smtp
```

### Permisos

```bash
chmod 600 /etc/msmtprc
chown root:root /etc/msmtprc
```

### Crear directorio de logs

```bash
touch /var/log/msmtp.log
chmod 640 /var/log/msmtp.log
```

### Prueba manual

```bash
echo "Test" | msmtp -a default tu-email@example.com
```

Si funciona, verás el email en tu bandeja de entrada.

### Verificar configuración

```bash
# Ver configuración (sin mostrar contraseña)
msmtp -P

# Debería mostrar algo como:
# account default
#   host smtp.gmail.com
#   ...
```

## Opción 2: Postfix (MTA Local)

Si prefieres un servidor de email local:

### Instalación

```bash
# Debian/Ubuntu
apt-get install postfix mailutils

# Durante la instalación, selecciona "Internet Site"
# Ingresa tu dominio (ej: example.com)
```

### Configuración básica

```bash
# Reconfigurar si es necesario
dpkg-reconfigure postfix
```

Editar `/etc/postfix/main.cf`:

```
# Para usar relay SMTP (Gmail, Outlook, etc.)
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

Crear archivo de credenciales `/etc/postfix/sasl_passwd`:

```
[smtp.gmail.com]:587 tu-email@gmail.com:tu-app-password
```

Proteger y generar hash:

```bash
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
systemctl restart postfix
```

### Prueba

```bash
echo "Test" | mail -s "Test Subject" tu-email@example.com
```

## Opción 3: Sendmail

```bash
# Instalar
apt-get install sendmail mailutils

# Configurar
sendmailconfig

# Probar
echo "Test" | mail -s "Test" tu-email@example.com
```

## Opción 4: Exim4

```bash
# Instalar
apt-get install exim4

# Configurar
dpkg-reconfigure exim4-config

# Seleccionar "mail sent by smarthost; received via SMTP or fetchmail"
# Configurar SMTP relay

# Probar
echo "Test" | mail -s "Test" tu-email@example.com
```

## Actualizar config.conf

Después de configurar el método de envío, actualiza `/etc/security-audit/config.conf`:

```bash
# Email destinatario
EMAIL_TO="admin@example.com"

# Email remitente
EMAIL_FROM="security-audit@$(hostname -f)"

# Si usas msmtp o MTA local, estos parámetros se ignoran
SMTP_HOST="localhost"
SMTP_PORT="25"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_TLS="no"
```

## Probar desde Security Audit

```bash
/opt/security-audit/security-audit.sh --test-email
```

## Troubleshooting

### Error: "account default not found"

- **Causa**: msmtp está instalado pero no configurado
- **Solución**: Crear `/etc/msmtprc` como se indica arriba

### Error: "cannot connect to smtp.gmail.com"

- **Causa**: Firewall bloqueando puerto 587
- **Solución**: Verificar con `telnet smtp.gmail.com 587`

### Error: "authentication failed"

- **Causa Gmail**: No estás usando App Password
- **Solución**: Crear App Password en https://myaccount.google.com/apppasswords

### Error: "permission denied"

- **Causa**: Permisos incorrectos en `/etc/msmtprc`
- **Solución**: `chmod 600 /etc/msmtprc`

### Los emails llegan a spam

- Configura SPF, DKIM y DMARC en tu dominio
- Usa un dominio verificado en el campo "from"
- Considera usar un servicio SMTP profesional (SendGrid, Mailgun, etc.)

### Ver logs de msmtp

```bash
tail -f /var/log/msmtp.log
```

### Ver logs de Postfix

```bash
tail -f /var/log/mail.log
```

## Servicios SMTP Profesionales

Para producción, considera usar un servicio profesional:

### SendGrid

```
host           smtp.sendgrid.net
port           587
user           apikey
password       TU-API-KEY
```

### Mailgun

```
host           smtp.mailgun.org
port           587
user           postmaster@tu-dominio.mailgun.org
password       TU-PASSWORD
```

### Amazon SES

```
host           email-smtp.us-east-1.amazonaws.com
port           587
user           TU-SMTP-USERNAME
password       TU-SMTP-PASSWORD
```

## Mejores Prácticas

1. **Nunca** comitees contraseñas a repositorios Git
2. Usa App Passwords en lugar de contraseñas principales
3. Configura permisos restrictivos: `chmod 600 /etc/msmtprc`
4. Monitorea los logs regularmente
5. Prueba el envío de emails después de cada cambio
6. Configura múltiples destinatarios para alertas críticas
7. Usa TLS siempre que sea posible
8. Rota contraseñas regularmente

## Configuración Avanzada

### Múltiples cuentas en msmtp

```
# Cuenta para alertas normales
account        default
host           smtp.gmail.com
port           587
from           alertas@example.com
user           alertas@example.com
password       password1

# Cuenta para alertas críticas
account        critical
host           smtp.gmail.com
port           587
from           criticas@example.com
user           criticas@example.com
password       password2
```

Usar cuenta específica:

```bash
echo "Alert" | msmtp -a critical admin@example.com
```

### Reenvío local con Postfix

Para mantener copias locales de todos los emails:

```bash
# En /etc/postfix/main.cf
always_bcc = archivo@localhost

# Crear buzón
useradd -m archivo
```

## Soporte

Si sigues teniendo problemas:

1. Revisa `/var/log/security-audit/security-audit.log`
2. Revisa `/var/log/msmtp.log` o `/var/log/mail.log`
3. Ejecuta `security-audit.sh --test-email` con modo debug
4. Abre un issue en GitHub con los logs (¡sin contraseñas!)
