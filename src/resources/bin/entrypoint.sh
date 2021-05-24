#!/usr/bin/env bash

set -e

NOW=$(date "+%Y-%m-%d_%H-%M-%S")

# Init for download dumps
mkdir -p tmp

# Downloading dumps
aws s3 sync s3://${BACKUP_BUCKET_NAME} ./tmp

# Init for select dump
mkdir -p restore

# Selecting dump to restore
cp tmp/${APP_NAME}_${RESTORE_DATETIME}.sql restore

# Setup pgdump
touch /root/.pgpass

# Build placeholder string
STRING="*:*:*:"
STRING+=${DB_USERNAME}
STRING+=":"
STRING+="@@DB_PASSWORD@@"

# Overwrite placeholder string
echo "${STRING}" > /root/.pgpass

# Overwrite unclean db password
echo ${DB_PASSWORD} > unclean.txt

# Cleanup db password colon and & operator
sed -i -e 's/:/\\\\:/g' unclean.txt
sed -i -e 's/&/\\&/g' unclean.txt

# Find and replace db password placeholder with real cleaned db password
sed -i -E "s|@@DB_PASSWORD@@|$(cat unclean.txt)|g" /root/.pgpass

# Setting permission
chmod 600 /root/.pgpass

# Create schema if not exists
psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USERNAME} -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USERNAME} -c "CREATE DATABASE ${DB_NAME}"

# Restore scheme
psql -h ${DB_HOST} -p ${DB_PORT} -d ${DB_NAME} -U ${DB_USERNAME} -f restore/${APP_NAME}_${RESTORE_DATETIME}.sql