#!/bin/bash

error () {
    echo $1
    exit 1
}

[ -d "wordpress" ] && error "Wordpress already installed."

# is docker installed
which docker > /dev/null
[ $? -eq 0 ] || error "Please install docker first, see https://www.docker.com/products/docker-desktop"

# is docker-compose installed
which docker-compose > /dev/null
[ $? -eq 0 ] || error "Please install docker-compose, see https://docs.docker.com/compose/install/"

# is curl or wget installed
which curl > /dev/null || which wget > /dev/null
[ $? -eq 0 ] || error "Please install curl or wget."

# is netcat installed
which netcat > /dev/null
[ $? -eq 0 ] || error "Please install netcat."

# Cleanup git repository

if [ ! -e .develop ]
then
    echo "cleanup.sh" >> .gitignore
    echo "bootstrap.sh" >> .gitignore
fi

rm -rf .git
git init -q
git add .
git commit -m "Initial Import" 2>&1 >/dev/null

# Let's Roll

case $WP_LANG in
    "fr")
        INSTALLER_URL=https://fr.wordpress.org/latest-fr_FR.tar.gz
    ;;
    "en")
        INSTALLER_URL=https://wordpress.org/latest.tar.gz
    ;;
    *)
        PS3='Choose your language: '
        l=("Français" "English")
        select fav in "${l[@]}"; do
            case $fav in
                "English")
                    WP_LANG=en
                    INSTALLER_URL=https://wordpress.org/latest.tar.gz
                break
                ;;
                "Français")
                    WP_LANG=fr
                    INSTALLER_URL=https://fr.wordpress.org/latest-fr_FR.tar.gz
                break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
    ;;
esac

case $WP_LANG in
    "fr")
        while [ $(echo -n "$DOCKER_REGISTRY" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hote du registry docker: " DOCKER_REGISTRY
        done
        while [ $(echo -n "$PROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hote de production: " PROD_FQDN
        done
        while [ $(echo -n "$PREPROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hotede pre-production: " PREPROD_FQDN
        done
        while [ $(echo -n "$PREPROD_USER" | wc -c) -lt 2 ]
        do
            read -p "Nom d'utilisateur http basic de pre-production: " PREPROD_USER
        done
        while [ $(echo -n "$PREPROD_PASSWD" | wc -c) -lt 2 ]
        do
            read -p "Mot de passe http basic de pre-production : " PREPROD_PASSWD
        done
        ;;
    *) 
        while [ $(echo -n "$DOCKER_REGISTRY" | wc -c) -lt 2 ]
        do
            read -p "Docker registry FQDN: " DOCKER_REGISTRY
        done
        while [ $(echo -n "$PROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Production FQDN: " PROD_FQDN
        done
        while [ $(echo -n "$PREPROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Staging FQDN: " PREPROD_FQDN
        done
        while [ $(echo -n "$PREPROD_USER" | wc -c) -lt 2 ]
        do
            read -p "Staging http basic username: " PREPROD_USER
        done
        while [ $(echo -n "$PREPROD_PASSWD" | wc -c) -lt 2 ]
        do
            read -p "Staging http basic password : " PREPROD_PASSWD
        done
        ;;
esac


HTTP_PORT=8080
MH_PORT=8025
MINIO_PORT=9000
DB_PORT=3306

while true
do
    netcat -tz -w 1 localhost ${HTTP_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    HTTP_PORT=$(expr ${HTTP_PORT} + 1)
done
while true
do
    netcat -tz -w 1 localhost ${MH_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    MH_PORT=$(expr ${MH_PORT} + 1)
done
while true
do
    netcat -tz -w 1 localhost ${MINIO_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    MINIO_PORT=$(expr ${MINIO_PORT} + 1)
done
while true
do
    netcat -tz -w 1 localhost ${DB_PORT} 2> /dev/null
    [ "$?" -eq "1" ] && break
    DB_PORT=$(expr ${DB_PORT} + 1)
done

case $WP_LANG in
    "fr") echo "Téléchargement de Wordpress";;
    *) echo "Downloading Wordpress";;
esac

which curl > /dev/null
if [ $? -eq 0 ]
then
    curl -sL $INSTALLER_URL | tar zxf -
else
    wget -qO - $INSTALLER_URL | tar zxf -
fi

mkdir -p wordpress/wp-content/mu-plugins/
cat > wordpress/wp-content/mu-plugins/s3-endpoint.php << EOF
<?php
add_filter( 's3_uploads_s3_client_params', function ( \$params ) {
    \$params['endpoint'] = getenv('S3_ENDPOINT');
    \$params['use_path_style_endpoint'] = true;
    return \$params;
} );
EOF

# Creating .env file
echo "Create .env file"
echo "UID=$(id -u)" > .env
echo "WP_LANG=${WP_LANG}" >> .env
echo "DB_HOST=db" >> .env
echo "DB_PORT=${DB_PORT}" >> .env
echo "DB_NAME=wp" >> .env
echo "DB_USER=wpuser" >> .env
echo "DB_PASSWORD=wppass" >> .env
echo "WP_URL=http://localhost:${HTTP_PORT}" >> .env
echo "SMTP_HOST=mh" >> .env
echo "SMTP_PORT=1025" >> .env
echo "MH_PORT=${MH_PORT}" >> .env
echo "MINIO_PORT=${MINIO_PORT}" >> .env
echo "HTTP_PORT=${HTTP_PORT}" >> .env
echo "SENTRY_DSN=" >> .env
echo "S3_ENDPOINT=http://minio:${MINIO_PORT}" >> .env
echo "S3_UPLOADS_KEY=minioadmin" >> .env
echo "S3_UPLOADS_SECRET=minioadmin" >> .env
echo "S3_UPLOADS_BUCKET=wordpress" >> .env
echo "S3_UPLOADS_REGION=eu-west-1" >> .env

# create compose file
echo "Create compose file"
cat > docker-compose.yml << EOF
version: '3'
services:
  db:
    image: mariadb
    ports:
      - "\${DB_PORT:-3306}:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=notaseriouspass
      - MYSQL_DATABASE=\${DB_NAME}
      - MYSQL_USER=\${DB_USER}
      - MYSQL_PASSWORD=\${DB_PASSWORD}
  mh:
    image: mailhog/mailhog
    ports:
      - "\${MH_PORT:-8025}:8025"
  minio:
    image: minio/minio
    command: server /data
    user: \${UID}
    volumes:
      - ./s3:/data
    ports:
      - "\${MINIO_PORT:-9000}:9000"
  app:
    depends_on:
      - db
      - mh
      - minio
    build:
      context: .
      args:
        UID: \${UID}
    ports:
      - "\${HTTP_PORT:-8080}:8080"
    env_file: ./.env
    volumes:
      - "./wordpress:/wordpress:cached"
      - "./config/nginx/nginx.conf:/etc/nginx/conf.d/nginx.conf:cached"
      - "./config/php/www.conf:/usr/local/etc/php-fpm.d/www.conf:cached"
EOF

#create wp-config.php
echo "Create wordpress config file"
cat > wordpress/wp-config.php << EOF
<?php
define( 'DB_NAME', getenv('DB_NAME'));
define( 'DB_USER', getenv('DB_USER'));
define( 'DB_PASSWORD', getenv('DB_PASSWORD'));
define( 'DB_HOST', getenv('DB_HOST'));
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
EOF

#TODO: grab at runtime or use secrets
which curl > /dev/null
if [ $? -eq 0 ]
then
    curl -sL https://api.wordpress.org/secret-key/1.1/salt/ >> wordpress/wp-config.php 
else
    wget -qO - https://api.wordpress.org/secret-key/1.1/salt/ >> wordpress/wp-config.php 
fi

cat >> wordpress/wp-config.php << EOF
\$table_prefix = 'wp_';
define( 'S3_UPLOADS_KEY', getenv('S3_UPLOADS_KEY') );
define( 'S3_UPLOADS_SECRET', getenv('S3_UPLOADS_SECRET') );
define( 'S3_UPLOADS_BUCKET', getenv('S3_UPLOADS_BUCKET') );
define( 'S3_UPLOADS_REGION', getenv('S3_UPLOADS_REGION') );
define( 'WP_DEBUG', false );
define('DISALLOW_FILE_MODS',true);
define( 'WP_SITEURL', getenv('WP_URL') );
define( 'WP_HOME', getenv('WP_URL') );
define( 'WP_CACHE', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'WP_AUTO_UPDATE_CORE', false );
if ( ! defined( 'ABSPATH' ) )
  define( 'ABSPATH', dirname( __FILE__ ) . '/' );
require_once __DIR__ . '/wp-content/plugins/s3-uploads/vendor/autoload.php';
require_once( ABSPATH . 'wp-settings.php' );
EOF

echo "Starting wordpress"
mkdir -p s3 .mc
docker-compose up -d --force-recreate
echo "Wait 5 sec for database initialisation"
sleep 5

echo "Install s3 uploads"
git clone --quiet https://github.com/humanmade/S3-Uploads.git wordpress/wp-content/plugins/s3-uploads
docker-compose run --rm \
-v $(pwd)/wordpress:/wordpress \
-w /wordpress/wp-content/plugins/s3-uploads \
app -- /usr/local/bin/composer install -q

rm -rf wordpress/wp-content/plugins/s3-uploads/.git

echo "Configure wordpress"
./wp core install \
--title="Wordpress" \
--url="http://localhost:${HTTP_PORT}" \
--admin_user="${USER}" \
--admin_email="${USER}@local.dev" \
--admin_password="${USER}"

echo "Install sentry"
./wp plugin install wp-sentry-integration

# Create minio bucket
echo "Create minio bucket"
docker run --rm -u $(id -u) -v $(pwd)/.mc:/.mc \
--network $(pwd | awk -F'/' '{print $NF}')_default \
minio/mc alias s minio http://minio:9000 minioadmin minioadmin

docker run --rm -u $(id -u) -v $(pwd)/.mc:/.mc \
--network $(pwd | awk -F'/' '{print $NF}')_default \
minio/mc mb minio/wordpress

echo "Activate s3-uploads"
./wp plugin activate s3-uploads

echo "Create Vixns Continuous Deployment configuration"
cat > Jenkinsfile << EOF
properties([gitLabConnection('Gitlab')])
node {
  checkout scm
  gitlabCommitStatus {
    vixnsCi('.vixns-ci.yml');
  }
}
EOF

cat > .vixns-ci.yml << EOF
version: 1

global:
  project_name: $(pwd | awk -F'/' '{print $NF}')

docker:
  builds:
  - name: app
    registry: ${DOCKER_REGISTRY}
    env:
      HOME: /tmp
      DB_HOST:
        secret:
          name: db
          key: host
      DB_NAME:
        secret:
          name: db
          key: name
      DB_USER:
        secret:
          name: db
          key: user
      DB_PASSWORD:
        secret:
          name: db
          key: password
      SMTP_HOST:
        secret:
          name: smtp
          key: host
      SMTP_PORT:
        secret:
          name: smtp
          key: port
      VERSION: "%shortcommit%"
      SENTRY_DSN:
        secret:
          name: sentry
          key: dsn
      S3_ENDPOINT:
        secret:
          name: s3
          key: endpoint
      S3_UPLOADS_KEY:
        secret:
          name: s3
          key: key
      S3_UPLOADS_SECRET:
        secret:
          name: s3
          key: secret
      S3_UPLOADS_BUCKET:
        secret:
          name: s3
          key: bucket
      S3_UPLOADS_REGION:
        secret:
          name: s3
          key: region
      WP_URL: "https://${PROD_FQDN}"
    volumes:
      - path: /wordpress/wp-content/uploads
        size: 10G
        type: nas
deploy:
  - name: update
    user: www-data
    onetime: true
    cmd: 
      develop: wp core update-db
      master: >-
        wp core update-db &&
        wp search-replace
        https://${PREPROD_FQDN}
        https://${PROD_FQDN}
    cpu: 0.01
    mem: 200
    docker:
      build: app
    env:
      develop:
        WP_URL: "https://${PREPROD_FQDN}"

  - name: app
    user: www-data
    cpu:
      develop: 0.01
      master: 0.03
    mem:
      develop: 200
      master: 300
    docker:
      build: app
    env:
      develop:
        WP_URL: "https://${PREPROD_FQDN}"
    ports:
      - name: http
        number: 8080
        check:
          type: http
          path: /wp-config.php
        routing:
          develop:
            domains:
            - "${PREPROD_FQDN}"
            auth:
              user: "${PREPROD_USER}"
              password: "${PREPROD_PASSWD}"
          master:
            domains:
            - "${PROD_FQDN}"
EOF

echo "Commit base install"
git add .
git commit -m "Wordpress installed" 2>&1 >/dev/null

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
    ;;
esac
echo
echo "============================================================="

[ -e .develop ] || rm -f cleanup.sh bootstrap.sh
