#!/bin/bash

error () {
    echo $1
    exit 1
}

case $WP_LANG in
    "fr")
    ;;
    "en")
    ;;
    *)
        PS3='Choose your language: '
        l=("Français" "English")
        select fav in "${l[@]}"; do
            case $fav in
                "English")
                    WP_LANG=en
                break
                ;;
                "Français")
                    WP_LANG=fr
                break
                    ;;
                *) echo "invalid option $REPLY, use 1 or 2";;
            esac
        done
    ;;
esac

# is docker installed
which docker > /dev/null
[ $? -eq 0 ] || error "Please install docker first, see https://www.docker.com/products/docker-desktop"

# is curl or wget installed
which curl > /dev/null || which wget > /dev/null
[ $? -eq 0 ] || error "Please install curl or wget."

# is nc installed
which nc > /dev/null
[ $? -eq 0 ] || error "Please install netcat."

# Cleanup git repository

if [ ! -e .develop ]
then
    echo "cleanup.sh" >> .gitignore
    echo "setup.sh" >> .gitignore
else
    cat > cleanup.sh << EOF
#!/bin/sh
[ -e docker compose.yml ] && docker-compose down -v
rm -rf .mc s3 wordpress docker compose.yml .vixns-ci.yml Jenkinsfile
EOF
  chmod +x cleanup.sh
fi

cat > .git/hooks/pre-commit << EOF
#!/bin/sh
which curl > /dev/null
if [ \$? -eq 0 ]
then
curlf() {
  OUTPUT_FILE=\$(mktemp)
  HTTP_CODE=\$(curl --silent --output \$OUTPUT_FILE --write-out "%{http_code}" "\$@")
  if [ "\${HTTP_CODE}" != "200" ] ; then
    >&2 cat \$OUTPUT_FILE
    rm \$OUTPUT_FILE
    exit 22
  fi
  cat \$OUTPUT_FILE
  rm \$OUTPUT_FILE
}
curlf https://deploy.vixns.net/verify --data-binary @.vixns-ci.yml
else
wget -q -o - https://deploy.vixns.net/verify --post-file .vixns-ci.yml
fi

EOF
chmod +x .git/hooks/pre-commit

# Let's Roll

HTTP_PORT=8080
PMA_PORT=8008
MH_PORT=8025
MINIO_PORT=9000
DB_PORT=3306

while true
do
    nc -tz -w 1 localhost ${HTTP_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    HTTP_PORT=$(expr ${HTTP_PORT} + 1)
done
while true
do
    nc -tz -w 1 localhost ${PMA_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    PMA_PORT=$(expr ${PMA_PORT} + 1)
done
while true
do
    nc -tz -w 1 localhost ${MH_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    MH_PORT=$(expr ${MH_PORT} + 1)
done
while true
do
    nc -tz -w 1 localhost ${MINIO_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    MINIO_PORT=$(expr ${MINIO_PORT} + 1)
done
while true
do
    nc -tz -w 1 localhost ${DB_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    DB_PORT=$(expr ${DB_PORT} + 1)
done

# Creating .env file
echo "Create .env file"
echo "UID=$(id -u)" > .env
echo "WP_LANG=${WP_LANG}" >> .env
echo "DB_HOST=db" >> .env
echo "DB_PORT=${DB_PORT}" >> .env
echo "DB_NAME=wp" >> .env
echo "DB_USER=wpuser" >> .env
echo "DB_PASSWORD=wppass" >> .env
echo "PMA_PORT=${PMA_PORT}" >> .env
echo "WP_URL=http://localhost:${HTTP_PORT}" >> .env
echo "SMTP_HOST=mh" >> .env
echo "SMTP_PORT=1025" >> .env
echo "SMTP_AUTH=false" >> .env
echo "SMTP_USER=''" >> .env
echo "SMTP_PASS=''" >> .env
echo "MH_PORT=${MH_PORT}" >> .env
echo "MINIO_PORT=${MINIO_PORT}" >> .env
echo "S3_UPLOADS_URL=http://localhost:${MINIO_PORT}" >> .env
echo "HTTP_PORT=${HTTP_PORT}" >> .env
echo "SENTRY_DSN=" >> .env
echo "VERSION=dev" >> .env
echo "S3_ENDPOINT=http://minio:9000" >> .env
echo "S3_UPLOADS_KEY=minioadmin" >> .env
echo "S3_UPLOADS_SECRET=minioadmin" >> .env
echo "S3_UPLOADS_BUCKET=wordpress" >> .env
echo "S3_UPLOADS_REGION=eu-west-1" >> .env

echo "Starting wordpress"
mkdir -p s3 .mc
docker-compose up -d --force-recreate
echo "Wait 5 sec for database initialisation"
sleep 5

echo "Configure wordpress"
./wp core install \
--title="Wordpress" \
--url="http://localhost:${HTTP_PORT}" \
--admin_user="${USER}" \
--admin_email="${USER}@local.dev" \
--admin_password="${USER}"

# Create minio bucket
echo "Create minio bucket"
./scripts/mc alias s minio http://minio:9000 minioadmin minioadmin
./scripts/mc mb minio/wordpress
./scripts/mc policy set download minio/wordpress/uploads

echo "============================================================="
echo
case $WP_LANG in
    "fr") 
    echo "Installation de Wordpress terminée."
    echo
    echo "Home : http://localhost:${HTTP_PORT}"
    echo "Admin: http://localhost:${HTTP_PORT}/wp-admin"
    echo "Utilisateur: $USER"
    echo "Mot de passe: $USER"
    echo
    echo "Mailhog: http://localhost:${MH_PORT}"
    echo "Minio: http://localhost:${MINIO_PORT}"
    echo "Utilisateur minio: minioadmin"
    echo "Mot de passe minio: minioadmin"
    echo
    echo "Mysql port: ${DB_PORT}"
    echo "phpMyAdmin: http://localhost:${PMA_PORT}"
    echo 
    echo "N'oubliez pas d'importer la base de données !"
    ;;
    *) 
    echo "Wordpress successfully installed."
    echo "Home : http://localhost:${HTTP_PORT}"
    echo "Admin: http://localhost:${HTTP_PORT}/wp-admin"
    echo "User: $USER"
    echo "Password: $USER"
    echo
    echo "Mailhog: http://localhost:${MH_PORT}"
    echo "Minio: http://localhost:${MINIO_PORT}"
    echo "Minio user: minioadmin"
    echo "Minio password: minioadmin"
    echo
    echo "Mysql port: ${DB_PORT}"
    echo "phpMyAdmin: http://localhost:${PMA_PORT}"
    echo 
    echo "Don't forget to import database !"
    ;;
esac
echo
echo "============================================================="

#[ -e .develop ] || rm -f setup.sh
