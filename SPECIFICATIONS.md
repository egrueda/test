# Especificaciones Técnicas del Sistema de Auditoría de Seguridad

## 1. Objetivo del Proyecto

Desarrollar un script automatizado de análisis de seguridad que se ejecute diariamente en servidores Debian y RedHat, analizando logs del sistema y el estado de seguridad, generando informes detallados enviados por email.

## 2. Requisitos Funcionales

### 2.1 Compatibilidad de Sistemas Operativos
- **Debian**: Versiones 10, 11, 12 (Buster, Bullseye, Bookworm)
- **RedHat/CentOS/Rocky/AlmaLinux**: Versiones 7, 8, 9
- Detección automática del tipo de sistema operativo

### 2.2 Análisis de Logs de Seguridad

#### 2.2.1 Logs del Sistema
- `/var/log/auth.log` (Debian) o `/var/log/secure` (RedHat)
  - Intentos fallidos de autenticación SSH
  - Intentos fallidos de sudo
  - Autenticaciones exitosas sospechosas
  - Cambios en usuarios/grupos

- `/var/log/syslog` (Debian) o `/var/log/messages` (RedHat)
  - Errores críticos del sistema
  - Alertas de seguridad
  - Servicios que han fallado

- `/var/log/kern.log` o `/var/log/dmesg`
  - Errores de hardware
  - Alertas del kernel

- `/var/log/fail2ban.log` (si está instalado)
  - IPs baneadas
  - Patrones de ataque detectados

#### 2.2.2 Logs de Aplicaciones Web
- `/var/log/apache2/` o `/var/log/httpd/`
  - Códigos de error 4xx y 5xx
  - Intentos de acceso a rutas sospechosas
  - Ataques comunes (SQL injection, XSS)

- `/var/log/nginx/`
  - Similar al análisis de Apache

### 2.3 Análisis del Estado del Servidor

#### 2.3.1 Seguridad del Sistema
- Actualizaciones de seguridad disponibles
- Servicios expuestos en puertos públicos
- Firewall activo y configurado
- SELinux/AppArmor estado
- Permisos de archivos sensibles (/etc/passwd, /etc/shadow, etc.)
- Archivos SUID/SGID
- Verificación de integridad de archivos del sistema

#### 2.3.2 Usuarios y Accesos
- Usuarios con shell activa
- Usuarios sin contraseña
- Cuentas con UID 0 (además de root)
- Últimos logins
- Sesiones activas
- Claves SSH autorizadas inusuales

#### 2.3.3 Servicios y Procesos
- Servicios en ejecución
- Procesos con alto consumo de recursos (posible malware)
- Conexiones de red activas
- Puertos abiertos y servicios asociados

#### 2.3.4 Sistema de Archivos
- Uso de disco (particiones > 80% alerta)
- Archivos modificados recientemente en directorios sensibles
- Archivos ocultos sospechosos
- Scripts en /tmp con permisos de ejecución

#### 2.3.5 Recursos del Sistema
- Uso de CPU
- Uso de memoria
- Carga del sistema (load average)
- Procesos zombie

### 2.4 Sistema de Alertas y Prioridades

#### Niveles de Severidad
- **CRÍTICO**: Requiere acción inmediata
  - Múltiples intentos fallidos de login root
  - Servicios críticos caídos
  - Rootkit detectado
  - Partición del sistema llena

- **ALTO**: Requiere atención pronto
  - Actualizaciones de seguridad disponibles
  - Firewall desactivado
  - Usuarios sin contraseña
  - Puertos inesperados abiertos

- **MEDIO**: Debe revisarse
  - Errores frecuentes en logs
  - Uso elevado de recursos
  - Archivos SUID nuevos

- **BAJO**: Informativo
  - Estadísticas de uso
  - Logins normales
  - Estado general del sistema

### 2.5 Generación de Informes

#### 2.5.1 Formato del Informe
- **HTML**: Informe principal con formato visual
- **TXT**: Resumen en texto plano
- **JSON**: Datos estructurados para integración con otras herramientas

#### 2.5.2 Contenido del Informe
1. Resumen ejecutivo
   - Nivel de amenaza general
   - Número de alertas por severidad
   - Acciones recomendadas

2. Detalles del servidor
   - Hostname
   - IP
   - Sistema operativo
   - Uptime
   - Última actualización del sistema

3. Hallazgos de seguridad
   - Por categoría
   - Por severidad
   - Con detalles y evidencia

4. Estadísticas
   - Top 10 IPs que intentaron acceder
   - Servicios más atacados
   - Errores más frecuentes

5. Recomendaciones
   - Acciones correctivas específicas
   - Best practices

#### 2.5.3 Envío por Email
- Soporte para SMTP estándar
- Autenticación SMTP
- Soporte para TLS/SSL
- Email en formato HTML con fallback a texto plano
- Adjuntos opcionales (logs relevantes)
- Configuración de destinatarios múltiples
- Opción de enviar solo si hay alertas críticas/altas

### 2.6 Configuración

#### 2.6.1 Archivo de Configuración
Archivo: `/etc/security-audit/config.conf`

Parámetros configurables:
- Email del remitente y destinatarios
- Servidor SMTP (host, puerto, usuario, contraseña)
- Niveles de severidad a incluir en el email
- Rutas de logs personalizadas
- Umbrales de alertas (ej: número de intentos fallidos)
- Exclusiones (IPs, usuarios, servicios)
- Retención de informes históricos
- Zona horaria

### 2.7 Programación y Ejecución

- Integración con cron para ejecución diaria
- Hora configurable (por defecto 6:00 AM)
- Registro de ejecuciones en `/var/log/security-audit.log`
- Lock file para evitar ejecuciones simultáneas
- Timeout configurable
- Rotación automática de logs de la propia herramienta

## 3. Requisitos No Funcionales

### 3.1 Performance
- Tiempo de ejecución máximo: 5 minutos en sistemas estándar
- Uso de memoria máximo: 100 MB
- Impacto mínimo en el rendimiento del servidor

### 3.2 Seguridad
- Script debe ejecutarse como root (requiere acceso a logs)
- Contraseñas de email almacenadas de forma segura
- Permisos restrictivos en archivos de configuración (600)
- Validación de inputs
- Logs de auditoría de la herramienta

### 3.3 Mantenibilidad
- Código modular
- Comentarios en español
- Logging detallado
- Facilidad para agregar nuevos checks
- Configuración centralizada

### 3.4 Confiabilidad
- Manejo de errores robusto
- Continuar ejecución aunque un módulo falle
- Notificación de errores del script mismo
- Verificación de dependencias antes de ejecutar

## 4. Dependencias del Sistema

### 4.1 Dependencias Requeridas
- `bash` (versión 4.0+)
- `awk`
- `sed`
- `grep`
- Herramientas de email: `mailx` o `sendmail` o `msmtp`
- `cron`

### 4.2 Dependencias Opcionales
- `lynis` (para auditorías avanzadas)
- `rkhunter` (detección de rootkits)
- `fail2ban` (análisis de bans)
- `mailutils` o `mutt` (para emails avanzados)

### 4.3 Comandos del Sistema Utilizados
- `netstat` o `ss`
- `ps`
- `who`, `last`
- `df`, `du`
- `top` o `htop`
- `iptables` o `firewalld` o `ufw`
- `getenforce` (SELinux en RedHat)
- `aa-status` (AppArmor en Debian)
- `find`
- `systemctl` o `service`

## 5. Estructura de Archivos

```
/opt/security-audit/
├── security-audit.sh          # Script principal
├── lib/
│   ├── common.sh              # Funciones comunes
│   ├── log-analyzer.sh        # Análisis de logs
│   ├── system-check.sh        # Checks del sistema
│   ├── report-generator.sh    # Generación de informes
│   └── email-sender.sh        # Envío de emails
├── templates/
│   ├── report.html            # Plantilla HTML
│   └── report.txt             # Plantilla texto
└── README.md

/etc/security-audit/
├── config.conf                # Configuración principal
└── exclusions.conf            # Exclusiones

/var/log/
└── security-audit/
    ├── security-audit.log     # Log de la herramienta
    └── reports/               # Informes históricos
        ├── 2024-01-15.html
        ├── 2024-01-15.txt
        └── 2024-01-15.json
```

## 6. Casos de Uso

### 6.1 Instalación Inicial
1. Usuario descarga el script
2. Ejecuta install.sh como root
3. Configura email y SMTP en config.conf
4. Verifica funcionamiento con ejecución manual
5. Cron configura automáticamente la ejecución diaria

### 6.2 Ejecución Diaria Automática
1. Cron ejecuta el script a las 6:00 AM
2. Script analiza logs y sistema
3. Genera informe HTML, TXT y JSON
4. Envía email a destinatarios configurados
5. Guarda informe en /var/log/security-audit/reports/

### 6.3 Análisis Manual
1. Administrador ejecuta manualmente el script
2. Puede especificar parámetros en línea de comandos
3. Puede generar informe sin enviar email
4. Puede analizar período de tiempo específico

## 7. Métricas de Éxito

- Script se ejecuta sin errores en Debian y RedHat
- Detección de al menos 20 tipos diferentes de eventos de seguridad
- Email llega correctamente con formato HTML
- Tiempo de ejecución menor a 5 minutos
- Facilidad de instalación (menos de 5 minutos)
- Documentación completa

## 8. Fases de Desarrollo

### Fase 1: Core
- Estructura básica del script
- Detección de OS
- Análisis de auth.log/secure
- Generación de informe simple en TXT
- Envío de email básico

### Fase 2: Análisis Extendido
- Análisis de todos los logs especificados
- Checks de sistema completos
- Informe HTML con formato

### Fase 3: Alertas y Priorización
- Sistema de niveles de severidad
- Estadísticas avanzadas
- Top 10s y resúmenes

### Fase 4: Configuración y Optimización
- Sistema de configuración completo
- Exclusiones
- Optimización de performance
- Manejo de errores robusto

### Fase 5: Documentación y Despliegue
- Documentación completa
- Script de instalación
- Tests en diferentes distribuciones
- Guías de uso
