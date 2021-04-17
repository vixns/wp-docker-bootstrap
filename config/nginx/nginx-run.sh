#!/bin/sh
sed -e "s#__S3_URL__#${S3_UPLOADS_URL}/${S3_UPLOADS_BUCKET}#g" /etc/service/nginx/nginx.conf > /etc/nginx/conf.d/nginx.conf
exec /usr/sbin/nginx -g "daemon off;"