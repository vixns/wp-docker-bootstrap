#!/bin/sh

. "$(dirname $0)/realpath.sh"

ROOT_DIR="$(dirname $(realpath $0))/../"
CUR_DIR=$(pwd)
cd $ROOT_DIR
docker compose exec -T db sh -c "mysqldump -uroot -p\${MYSQL_ROOT_PASSWORD} --max_allowed_packet=512M --default-character-set=utf8mb4 --single-transaction --routines --complete-insert --add-drop-table --quick --quote-names \${MYSQL_DATABASE}" | gzip -9 > export.sql.gz
cd $CUR_DIR
