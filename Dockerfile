FROM nginx:alpine

# Instala envsubst (incluido en el paquete gettext)
RUN apk add --no-cache gettext

# Elimina la configuración por defecto de Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copia la plantilla de configuración
COPY nginx.conf.template /etc/nginx/conf.d/default.conf.template

# Expone el puerto 80
EXPOSE 80

# Realiza la sustitución de variables y ejecuta Nginx
CMD ["/bin/sh", "-c", "envsubst '$COS_ENDPOINT $COS_BUCKET' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
