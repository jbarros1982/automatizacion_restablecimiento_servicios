#!/bin/bash
LOG="/var/log/proceso-apache.log"
EMAIL="notificaciones@dominioempresa.com.py"

echo "Reiniciando Apache HTTPD..." | tee -a $LOG
systemctl restart httpd

if systemctl is-active --quiet httpd; then
    echo "Apache reiniciado correctamente." | tee -a $LOG
    mail -s "Apache reiniciado" "$EMAIL" <<< "$(cat $LOG)"
else
    echo "Error al reiniciar Apache." | tee -a $LOG
    mail -s "Error reiniciando Apache" "$EMAIL" <<< "$(cat $LOG)"
fi
