#!/bin/sh
[ -e docker-compose.yml ] && docker-compose down -v
rm -rf .mc s3 wordpress docker-compose.yml .vixns-ci.yml Jenkinsfile