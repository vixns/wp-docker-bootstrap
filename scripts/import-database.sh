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
	gunzip -c $1 | docker-compose exec -T db sh -c "mysql -uroot -p\${MYSQL_ROOT_PASSWORD} \${MYSQL_DATABASE}"
else
	cat | docker-compose exec -T db sh -c "mysql -uroot -p\${MYSQL_ROOT_PASSWORD} \${MYSQL_DATABASE}"
fi
cd $CUR_DIR
