# Automatización de Restablecimiento de Servicios Basada en Tickets de Soporte

Este repositorio contiene **scripts y configuraciones ejemplo** utilizados en el proyecto académico:
**“Automatización de restablecimiento de servicios basada en tickets de soporte”**.

> **Propósito:** demostrar la **replicabilidad** del enfoque: a partir de correos electrónicos entrantes (tickets),
se disparan scripts en servidores Linux que restablecen servicios críticos (Apache, Tomcat, reinicio del SO) de forma
controlada, segura y auditable, usando herramientas open‑source.

---

## Arquitectura (resumen)

Flujo de extremo a extremo:

```
[Remitente autorizado]
        |
        v  (IMAP/POP3)
   [Servidor de correo remoto]
        |
        v  (fetch)
      Fetchmail  ──►  Postfix (MTA local - Server Linux)  ──►  Procmail (MDA/filtro)  ──►  Scripts bash
        ^                                                      |                 |
        |                                                      └──► Logs         └──► Notificación (Postfix)
      Crontab (Monitoreo del Servicio)


```

- **Fetchmail**: recupera el correo de una cuenta IMAP/POP3 y lo entrega al MTA local.
- **Postfix**: recibe el mensaje localmente y lo entrega a **Procmail**.
- **Procmail**: filtra por *From/Subject* y ejecuta el **script** correspondiente.
- **Scripts Bash**: realizan las acciones (reinicio de Apache/Tomcat/servidor) y envían un **correo de confirmación**.
- **Crontab**: asegura que **Fetchmail** permanezca activo (watchdog minuto a minuto).

> **Nota:** Este repo usa *placeholders* (datos ficticios) para credenciales y dominios. Reemplácelos en su entorno.

---

## 📁 Estructura del repositorio

```
.
├─ config/
│  ├─ .fetchmailrc        # Ejemplo de configuración (sin credenciales reales)
│  └─ .procmailrc         # Reglas de filtrado y disparo de scripts
|  └─ .crontab            # Watchdog con crontab (opcional)
├─ scripts/
│  ├─ apache_reboot.sh    # Reinicio de Apache + notificación
│  ├─ tomcat_reboot.sh    # Reinicio de Tomcat + notificación
│  └─ server_reboot.sh    # Reinicio controlado del sistema + notificación
└─ README.md
```

> **Permisos recomendados:**
>
> ```bash
> chmod 600 /ruta/.fetchmailrc
> chmod 600 /ruta/.procmailrc
> chmod +x scripts/*.sh
> ```

---

## Requisitos 

- Bash
- Postfix (MTA local) configurado para **enviar** correos salientes (p. ej., relé SMTP).
- Fetchmail
- Procmail
- `mail`/`mailx` o equivalente para enviar notificaciones desde los scripts.
- Usuario con privilegios para reiniciar servicios (Apache/Tomcat) y/o el sistema.

---

## Seguridad 

- Limite remitentes y asuntos en `config/.procmailrc` a **listas autorizadas**.
- Asegure permisos de archivos (600) y ejecute los scripts con el usuario mínimo necesario.
- Registre logs en rutas protegidas (`/var/log/...`) y rote con `logrotate` si es necesario.

---

## Cómo replicar (entorno de pruebas)

> **Advertencia:** los pasos siguientes son para un entorno **de laboratorio**. No use en producción sin revisión de seguridad.

1) **Instalar dependencias** (ejemplos, varían por distro):
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y fetchmail procmail postfix bsd-mailx

# RHEL/CentOS/Oracle
sudo yum install -y fetchmail procmail postfix mailx
```

2) **Configurar Postfix** para salida SMTP (si usa relé):
- Edite `/etc/postfix/main.cf` (ejemplo):
```
inet_protocols = ipv4
relayhost = [smtp.acme.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_use_tls = yes
smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
```
- Cree `/etc/postfix/sasl_passwd`:
```
[smtp.acme.com]:587    USUARIO_SMTP:PASSWORD_SMTP
```
- Proteja y compile:
```bash
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix  # o 'service postfix restart'
```

3) **Configurar Fetchmail** (`~/.fetchmailrc` o `/etc/fetchmailrc`):
```bash
set daemon 300
set logfile /var/log/fetchmail.log

poll imap.acme.com with proto IMAP
  user 'CUENTA_CORREO_SERVIDOR'@acme.com  there with password 'PASSWORD_AQUI' is root here
  ssl
  mda "/usr/bin/procmail -d %T"
```
> Ajuste `imap.acme.com`, usuario y **NO** use la contraseña real en este repo. En el servidor, ponga la válida y:
> ```bash
> chmod 600 ~/.fetchmailrc
> ```
> Para ejecutar en segundo plano:
> ```bash
> fetchmail -d 300
> ```

4) **Configurar Procmail** (`~/.procmailrc` o `/etc/procmailrc`):
```procmail
SHELL=/bin/bash
LOGFILE=/var/log/procmail.log
MAILDIR=/var/mail/acme
DEFAULT=$MAILDIR/
ORGMAIL=$MAILDIR/
LOGABSTRACT=all

:0
* ^From:.*persona1@outlook.com.es
* ^Subject:.*Restart\.Apache
{
    LOG="Correo de Persona 1, instrucción: Reiniciar Apache. Ejecutando script...\n"
    :0
    | /sbin/apache_reboot.sh remitente@acme.com
}

:0
* ^From:.*persona2@outlook.com.es
* ^Subject:.*Restart\.Tomcat
{
    LOG="Correo de Persona 2, instrucción: Reiniciar Tomcat. Ejecutando script...\n"
    :0
    | /sbin/tomcat_reboot.sh remitente@acme.com
}

:0
* ^From:.*persona3@yahoo.com
* ^Subject:.*Restart\.Server
{
    LOG="Correo de Persona 3, instrucción: Reiniciar Servidor. Ejecutando script...\n"
    :0
    | /sbin/server_reboot.sh remitente@acme.com
}

:0
$DEFAULT
```

5) **Instalar los scripts** (ver carpeta `scripts/`) y dar permisos:
```bash
sudo cp scripts/*.sh /sbin/
sudo chmod +x /sbin/apache_reboot.sh /sbin/tomcat_reboot.sh /sbin/server_reboot.sh
```

6) **Watchdog opcional con cron** (si no usa systemd service):
```bash
# Como root (crontab -e)
* * * * * pgrep -f '/usr/bin/fetchmail -d' > /dev/null 2>&1 || /usr/bin/fetchmail -d 300
```

7) **Probar el flujo**:
- Enviar un correo **desde una cuenta autorizada** con el **asunto esperado** (p. ej., `Restart.Apache`).
- Verificar logs:
```bash
tail -f /var/log/fetchmail.log
tail -f /var/log/procmail.log
journalctl -u postfix -f   # o tail -f /var/log/maillog
```

---

## Scripts incluidos 

- `scripts/apache_reboot.sh`: reinicia Apache y envía confirmación al e‑mail recibido como 1er argumento.
- `scripts/tomcat_reboot.sh`: detiene e inicia Tomcat (vía `catalina.sh`) y notifica resultado.
- `scripts/server_reboot.sh`: realiza `shutdown -r now` de forma controlada y notifica.

> Todos escriben logs y envían correo con `mail -s ... $EMAIL`.

---

## Citar este repositorio

Si utiliza estas configuraciones como referencia, cite el artículo y/o este repositorio de la siguiente manera:

> Barros da Silva Cunha, J., Ayala Frasnelli, N. L., Ruiz Díaz Medina, A. D.  
> “Automatización de restablecimiento de servicios basada en tickets de soporte”, 2024.  
> Repositorio: *GitHub – Automatización de Restablecimiento de Servicios*.

---

## Descargo de responsabilidad

Este material se proporciona **con fines académicos** y de **replicabilidad**.  
Úselo bajo su propio riesgo. Revise políticas de seguridad antes de emplearlo en producción.

---

## Contacto

- Autor: **José Barros da Silva Cunha**
- ORCID: *https://orcid.org/0009-0002-5994-4535*
- E‑mail académico: `josebarrosdasilva@outlook.es`

---

¡Gracias por su interés! Si encuentra mejoras, por favor envíe un *issue* o *pull request*.
