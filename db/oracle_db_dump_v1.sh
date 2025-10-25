#!/bin/bash
#Mention Database Credentials 
DB_USER=apsisipdc
DB_PASS=Dhaka123456
DB_PORT=
DB_HOST=ORCL

# Specify source and destination directories
SRC_BASE_DIR="/oracle_db_dump"
DST_BASE_DIR="/backup_v2023"
BKP_TYPE=db_backup

#Backup Retention Period 
DAILY_BACKUP_RETENTION=7
WEEKLY_BACKUP_RETENTION=2
MONTHLY_BACKUP_RETENTION=1

#================================================================DONT-TOUCH-HERE=======================================================#

#Host Name for Backup Identification 
SERVER_NAME=$(hostname)
DST_DIR=$DST_BASE_DIR/$SERVER_NAME
TIMESTAMP=$(date +%Y-%m-%d)
DAILY=$DST_DIR/$BKP_TYPE/daily/$TODAY
WEEKLY=$DST_DIR/$BKP_TYPE/weekly
MONTHLY=$DST_DIR/$BKP_TYPE/monthly

YESTERDAY=$(date --date="yesterday" +\%Y%m%d)
TODAY=$(date +\%Y-\%m-\%d)
WEEKEND=$(date +%A)
LAST_DAY_OF_MONTH=$(date -d "$(date +%Y-%m-01 -d 'next month') -1 day" +%Y-%m-%d)

DAILY_RETENTION_DATE=$(date -d "(1 * $DAILY_BACKUP_RETENTION) days ago" +%Y-%m-%d)
WEEKLY_RETENTION_DATE=$(date -d "(7 * $WEEKLY_BACKUP_RETENTION) days ago" +%Y-%m-%d)
MONTHLY_RETENTION_DATE=$(date -d "$MONTHLY_BACKUP_RETENTION days ago" +%Y-%m-%d)

echo "Crete Directories for App/DB Backup on Destination."
if [ ! -d "$DST_DIR" ];then
mkdir "$DST_DIR"
fi
if [ ! -d "$DST_DIR/$BKP_TYPE" ];then
mkdir "$DST_DIR/$BKP_TYPE"
fi
echo "Create Directory for Daily Backup."
if [ ! -d "$DST_DIR/$BKP_TYPE/daily" ];then
mkdir "$DST_DIR/$BKP_TYPE/daily"
fi
echo "Create Directory for Weekly Backup"
if [ ! -d "$DST_DIR/$BKP_TYPE/weekly" ];then
mkdir "$DST_DIR/$BKP_TYPE/weekly"
fi
echo "Create Directory for Monthly Backup"
if [ ! -d "$DST_DIR/$BKP_TYPE/monthly" ];then
mkdir "$DST_DIR/$BKP_TYPE/monthly"
fi
echo "Create Directory for Today."
if [ ! -d "$DST_DIR/$BKP_TYPE/daily/$TODAY" ];then
mkdir "$DST_DIR/$BKP_TYPE/daily/$TODAY"
fi

#------------------------------------------------------Daily Backup----------------------------------------------------------------#
# Set Oracle environment variables
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export PATH=$ORACLE_HOME/bin:$PATH

# Get the List of All Schemas
schemas=($(sqlplus -S $DB_USER/$DB_PASS@$DB_HOST <<EOF
set heading off feedback off pagesize 0
select username from dba_users where username not in ('SYS','SYSTEM');
exit;
EOF
))
#"Loop through each schema and perform backup"
for schema in "${schemas[@]}"; do
    # Export schema
    expdp $DB_USER/$DB_PASS@$DB_HOST directory=dump_dir dumpfile=${schema}_${TIMESTAMP}.dmp compression=all schemas=${schema}
    # Create a tarball for the schema backup
    tar -czvf ${DAILY}/$TODAY/${schema}_${TIMESTAMP}.tar.gz ${SRC_BASE_DIR}/${schema}_${TIMESTAMP}.dmp

    # Clean up
    cd ${SRC_BASE_DIR}/
    #rm -f *.dmp
done
#-----------------------------------------------------Weekly Backup---------------------------------------------------------------#
if [[ "$WEEKEND" == "Friday" ]];then
cp -rp "$DAILY" "$WEEKLY/"
fi
#-----------------------------------------------------Monthly Backup--------------------------------------------------------------#
if [[ "$TODAY" ==  "$LAST_DAY_OF_MONTH" ]];then
cp -rp "$DAILY" "$MONTHLY/"
fi

#-----------------------------------------------------Daily Backup Deletion--------------------------------------------------------#
if [ -d "$DAILY/$DAILY_RETENTION_DATE" ];then
rm -rf $DAILY/$DAILY_RETENTION_DATE
fi
#-----------------------------------------------------Weekly Backup Deletion-------------------------------------------------------#
if [ -d "$WEEKLY/$WEEKLY_RETENTION_DATE" ];then
rm -rf "$WEEKLY/$WEEKLY_RETENTION_DATE"
fi
#----------------------------------------------------Monthly Backup Deletion------------------------------------------------------#
if [[ "$TODAY" ==  "$LAST_DAY_OF_MONTH" ]];then
rm -rf $MONTHLY/$MONTHLY_RETENTION_DATE
fi
#END
