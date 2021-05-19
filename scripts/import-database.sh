#!/bin/sh

. "$(dirname $0)/realpath.sh"

ROOT_DIR="$(dirname $(realpath $0))/../"
CUR_DIR=$(pwd)
cd $ROOT_DIR
if [ -t 0 ]
then
	if [ -z "$1" ]
	then
		echo "usage: $0 dump.sql.gz"
		exit 1
	fi
	ext="${1##*.}"
	if [ "$ext" = "gz" ]
	then
		gunzip -c $1 | docker-compose exec -T db sh -c "mysql -uroot -p\${MYSQL_ROOT_PASSWORD} \${MYSQL_DATABASE}"
	else
		cat $1 | docker-compose exec -T db sh -c "mysql -uroot -p\${MYSQL_ROOT_PASSWORD} \${MYSQL_DATABASE}"
	fi
else
	cat | docker-compose exec -T db sh -c "mysql -uroot -p\${MYSQL_ROOT_PASSWORD} \${MYSQL_DATABASE}"
fi

OLDURL=$(echo 'SELECT option_value FROM wp_options WHERE option_name="siteurl"' | docker-compose exec -T app wp db query --skip-column-names)
. ./.env
./wp search-replace --recurse-objects --all-tables $OLDURL $WP_URL
cd $CUR_DIR
