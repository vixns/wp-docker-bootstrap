#!/bin/bash

error () {
    echo $1
    exit 1
}

[ -d "wordpress" ] && error "Wordpress already installed."

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
[ -e docker-compose.yml ] && docker compose down -v
rm -rf .mc s3 wordpress docker-compose.yml .vixns-ci.yml Jenkinsfile
EOF
  chmod +x cleanup.sh
fi

rm -rf .git
git init -q
git checkout -q -b develop
git add .
git commit -m "Initial Import" 2>&1 >/dev/null
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
                *) echo "invalid option $REPLY, use 1 or 2";;
            esac
        done
    ;;
esac

case $WP_LANG in
    "fr")
        while [ $(echo -n "$DOCKER_REGISTRY" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hote du registry docker: (docker.vixns.net par defaut) " DOCKER_REGISTRY
            DOCKER_REGISTRY="${DOCKER_REGISTRY:=docker.vixns.net}"
        done
        while [ $(echo -n "$MYSQL_MARATHON_PATH" | wc -c) -lt 2 ]
        do
            read -p "Chemin du cluster mysql (exemple: mysql-master-common-test.marathon.vx): " MYSQL_MARATHON_PATH
        done
        while [ $(echo -n "$PROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hote de production: " PROD_FQDN
        done
        while [ $(echo -n "$PREPROD_FQDN" | wc -c) -lt 2 ]
        do
            read -p "Nom d'hote de pre-production: " PREPROD_FQDN
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
            read -p "Docker registry FQDN: (default: docker.vixns.net) " DOCKER_REGISTRY
            DOCKER_REGISTRY="${DOCKER_REGISTRY:=docker.vixns.net}"
        done
        while [ $(echo -n "$MYSQL_MARATHON_PATH" | wc -c) -lt 2 ]
        do
            read -p "Mysql cluster path (eg: mysql-master-common-test.marathon.vx): " MYSQL_MARATHON_PATH
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
  pma:
    image: phpmyadmin
    ports:
      - "\${PMA_PORT:-8008}:80"
    environment:
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=notaseriouspass
      - PHP_UPLOAD_MAX_FILESIZE=1G
      - PHP_MAX_INPUT_VARS=1G
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
      - "./config/php/www.conf:/usr/local/etc/php-fpm.d/www.conf:cached"
EOF

# create dproxy compatible compose file
echo "Create dproxy compatible compose file"
cat > docker-compose-dproxy.yml << EOF
version: '3'
services:
  minio:
    image: minio/minio
    command: server /data
    user: \${UID}
    volumes:
      - ./s3:/data
    networks:
      - default
      - proxy
    ports:
      - "9000"
    labels:
      - "traefik.frontend.rule=Host:minio-\${HOSTNAME}.\${DOMAIN}"
  app:
    depends_on:
      - minio
    build:
      context: .
      args:
        UID: \${UID}
    networks:
      - default
      - proxy
      - smtp
      - mysql
    ports:
      - "8080"
    env_file: ./.env
    volumes:
      - "./wordpress:/wordpress:cached"
      - "./config/php/www.conf:/usr/local/etc/php-fpm.d/www.conf:cached"
    labels:
      - "traefik.frontend.rule=Host:\${HOSTNAME}.\${DOMAIN}"

networks:
  default:
  mysql:
    external:
      name: mysql
  proxy:
    external:
      name: proxy
  smtp:
    external:
      name: smtp

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
define( 'S3_UPLOADS_BUCKET_URL', getenv('S3_UPLOADS_URL') . '/' . getenv('S3_UPLOADS_BUCKET')  );
define( 'WP_SENTRY_PHP_DSN', getenv('SENTRY_DSN'));
//define( 'WP_SENTRY_BROWSER_DSN', getenv('SENTRY_DSN'));
define( 'WP_SENTRY_VERSION', getenv('VERSION') );
define( 'WP_DEBUG', false );
define('DISALLOW_FILE_MODS',true);
define( 'WP_SITEURL', getenv('WP_URL') );
define( 'WP_HOME', getenv('WP_URL') );
define( 'WP_CACHE', true );
define( 'AUTOMATIC_UPDATER_DISABLED', true );
define( 'WP_AUTO_UPDATE_CORE', false );
#wp mail smtp config
define( 'WPMS_ON', true );
define( 'WPMS_SET_RETURN_PATH', true );
define( 'WPMS_MAILER', 'smtp' ); // Possible values: 'mail', 'smtpcom', 'sendinblue', 'mailgun', 'sendgrid', 'gmail', 'smtp'.
define( 'WPMS_SMTP_HOST', getenv('SMTP_HOST') );
define( 'WPMS_SMTP_PORT', getenv('SMTP_PORT') );
define( 'WPMS_SMTP_AUTH', getenv('SMTP_AUTH') === 'true') );
define( 'WPMS_SMTP_USER', getenv('SMTP_USER') );
define( 'WPMS_SMTP_PASS', getenv('SMTP_PASS') );

if ( ! defined( 'ABSPATH' ) )
  define( 'ABSPATH', dirname( __FILE__ ) . '/' );
require_once __DIR__ . '/wp-content/plugins/s3-uploads/vendor/autoload.php';
require_once( ABSPATH . 'wp-settings.php' );
EOF

echo "Starting wordpress"
mkdir -p s3 .mc
docker compose up -d --force-recreate
echo "Wait 5 sec for database initialisation"
sleep 5

echo "Install s3 uploads"
git clone --quiet https://github.com/humanmade/S3-Uploads.git wordpress/wp-content/plugins/s3-uploads
docker compose run --rm \
-v $(pwd)/wordpress:/wordpress \
-w /wordpress/wp-content/plugins/s3-uploads \
app -- /usr/local/bin/composer install -q

rm -rf wordpress/wp-content/plugins/s3-uploads/.git wordpress/wp-content/plugins/s3-uploads/.gitignore

echo "Configure wordpress"
./wp core install \
--title="Wordpress" \
--url="http://localhost:${HTTP_PORT}" \
--admin_user="${USER}" \
--admin_email="${USER}@local.dev" \
--admin_password="${USER}"

echo "Install sentry"
./wp plugin install wp-sentry-integration

echo "Activate sentry"
./wp plugin activate wp-sentry-integration

echo "Install Wordpress mail smtp"
./wp plugin install wp-mail-smtp

echo "Activate wp mail smtp"
./wp plugin activate wp-mail-smtp

# Create minio bucket
echo "Create minio bucket"
./scripts/mc alias s minio http://minio:9000 minioadmin minioadmin
./scripts/mc mb minio/wordpress
./scripts/mc policy set download minio/wordpress/uploads

echo "Activate s3-uploads"
./wp plugin activate s3-uploads

echo "create update script"
cat > update.sh << EOF
#!/bin/sh
if [ -e "/etc/proxysql/proxysql.cnf.tpl"  ]
then
  /etc/service/proxysql/run &
  wait 3
fi
wp core update-db
wp search-replace --recurse-objects --all-tables \$(wp option get siteurl) \${WP_URL}
EOF
chmod 755 update.sh

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

echo "set proxysql service"
echo > /etc/service/proxysql/run << EOF
#!/bin/sh

exec 2>&1
if [ ! -e "/etc/proxysql/proxysql.cnf.tpl" ]; then
  touch down
  sv down .
  exit 0
fi
mkdir -p /tmp/proxysql

cp /etc/proxysql/proxysql.cnf.tpl /etc/service/proxysql/proxysql.cnf

a=\$(ping -c 1 \$MYSQL1 | grep time= | awk '{print \$8}'| awk -F'=' '{print \$2 * 1000}')
b=\$(ping -c 1 \$MYSQL2 | grep time= | awk '{print \$8}'| awk -F'=' '{print \$2 * 1000}')
c=\$(ping -c 1 \$MYSQL3 | grep time= | awk '{print \$8}'| awk -F'=' '{print \$2 * 1000}')

if [ \$a -lt \$b -a \$a -lt \$c ]
then
  sed -e "s/\${MYSQL1}.*weight=1/\000/g" -i /etc/service/proxysql/proxysql.cnf
elif [ \$b -lt \$c -a \$b -lt \$a ]
then
  sed -e "s/\${MYSQL2}.*weight=1/\000/g" -i /etc/service/proxysql/proxysql.cnf
else
  sed -e "s/\${MYSQL3}.*weight=1/\000/g" -i /etc/service/proxysql/proxysql.cnf
fi

exec proxysql -c /etc/service/proxysql/proxysql.cnf -D /tmp/proxysql -f -e
EOF
chmod 755 /etc/service/proxysql/run

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
      SMTP_AUTH:
        secret:
          name: smtp
          key: auth
      SMTP_USER:
        secret:
          name: smtp
          key: user
      SMTP_PASS:
        secret:
          name: smtp
          key: pass
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
      S3_UPLOADS_URL:
        secret:
          name: s3
          key: url
      WP_URL: "https://${PROD_FQDN}"
      MYSQL1: node1-${MYSQL_MARATHON_PATH}
      MYSQL2: node2-${MYSQL_MARATHON_PATH}
      MYSQL3: node3-${MYSQL_MARATHON_PATH}
    volumes:
      - path: /etc/proxysql/proxysql.cnf.tpl
        type: secret
        secret:
          name: proxysql
          key: config
deploy:
  - name: update
    user: www-data
    onetime: true
    cmd: /update.sh
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
mv step2/install.sh install.sh
mv step2/README.md README.md
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
    echo "phpMyAdmin: http://localhost:${PMA_PORT}"
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
    ;;
esac
echo
echo "============================================================="

[ -e .develop ] || rm -f setup.sh
