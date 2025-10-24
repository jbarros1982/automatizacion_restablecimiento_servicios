#!/bin/bash
LOG="/var/log/proceso-tomcat.log"
EMAIL="notificaciones@dominioempresa.com.py"

echo "Reiniciando Tomcat..." | tee -a $LOG
systemctl restart tomcat

if systemctl is-active --quiet tomcat; then
    echo "Tomcat reiniciado correctamente." | tee -a $LOG
    mail -s "Tomcat reiniciado" "$EMAIL" <<< "$(cat $LOG)"
else
    echo "Error al reiniciar Tomcat." | tee -a $LOG
    mail -s "Error reiniciando Tomcat" "$EMAIL" <<< "$(cat $LOG)"
fi
