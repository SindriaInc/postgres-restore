#!/usr/bin/env bash

set -e

BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' #No Color
NOW=$(date "+%Y-%m-%d_%H-%M-%S")


echo -e "${BLUE}Fetching backups...${NC}"

# Init for download dumps
mkdir -p tmp

# Downloading dumps
aws s3 sync s3://${BACKUP_BUCKET_NAME} ./tmp

echo #
echo -e "${BLUE}Selecting backup to restore...${NC}"

# Init for select dump
mkdir -p restore

# Selecting dump to restore
cp tmp/${APP_NAME}_${RESTORE_DATETIME}.sql restore

echo #
echo -e "${BLUE}Setting up client...${NC}"

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

echo #
echo -e "${BLUE}Checking if schema exists...${NC}"

# Create schema if not exists
#psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '<your db name>'" | grep -q 1 | psql -U postgres -c "CREATE DATABASE <your db name>"

psql -U ${DB_USERNAME} -h ${DB_HOST} -p ${DB_PORT} -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || echo -e "${YELLOW}Creating schema ${DB_NAME}...${NC}"; psql -U ${DB_USERNAME} -h ${DB_HOST} -p ${DB_PORT} -tc "CREATE DATABASE $DB_NAME"


echo #
echo -e "${BLUE}Restoring backup...${NC}"

# Restore scheme
psql -U ${DB_USERNAME} -h ${DB_HOST} -p ${DB_PORT} -d ${DB_NAME} -f restore/${APP_NAME}_${RESTORE_DATETIME}.sql

echo #
echo -e "${BLUE}Done.${NC}"