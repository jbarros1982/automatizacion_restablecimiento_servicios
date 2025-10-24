#!/bin/bash
LOG="/var/log/server-reboot.log"
EMAIL="notificaciones@dominioempresa.com.py"

/sbin/shutdown -r now "Reinicio solicitado por correo"

mail -s "Reinicio del servidor en proceso" "$EMAIL" <<< "El servidor está reiniciándose según solicitud."

echo "Reinicio ejecutado: $(date)" >> $LOG
