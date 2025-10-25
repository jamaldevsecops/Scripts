

DR_VALUE=$((1 * $daily_backup_retention))
WR_VALUE=$((7 * $weekly_backup_retention))

DR=$(date -d "$DR_VALUE days ago" +%Y-%m-%d)
WR=$(date -d "$WR_VALUE days ago" +%Y-%m-%d)
MR=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
YR=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')


DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS" | grep -v "(.* rows)")
for SRC_DB in ${DB_LIST[@]}
do
    #Daily backup retention 
    if [ "$daily_backup_required" == "yes" ]; then
        FILE_TO_DELETE=${SRC_DB}_${DR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    fi 
    #Weekly backup retention 
    if [ "$weekly_backup_required" == "yes" ] && [ "$WEEKEND" == "Friday" ]; then
        FILE_TO_DELETE=${SRC_DB}_${WR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    fi 
    #Monthly backup retention 
    if [ "$monthly_backup_required" == "yes" ] && [ "$day_of_month" -eq "$last_day_of_month" ]; then 
        FILE_TO_DELETE=${SRC_DB}_${MR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    fi 
    #Yearly backup retension 
    if [ "$yearly_backup_required" == "yes" ] && [ "$today" == "$last_day_of_year" ]; then 
        FILE_TO_DELETE=${SRC_DB}_${YR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    fi 
done 


#Calling the required function for daily backup retention 
if [ "$daily_backup_required" == "yes" ]; then 
    DR_VALUE=$((1 * $daily_backup_retention))
    DR=$(date -d "$DR_VALUE days ago" +%Y-%m-%d)
    DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS" | grep -v "(.* rows)")
    for SRC_DB in ${DB_LIST[@]}
    do 
        FILE_TO_DELETE=${SRC_DB}_${DR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    done
fi 
#Calling the required function for weekly backup retention 
if [ "$weekly_backup_required" == "yes" ] && [ "$WEEKEND" == "Friday" ]; then 
    WR_VALUE=$((7 * $weekly_backup_retention))
    WR=$(date -d "$WR_VALUE days ago" +%Y-%m-%d)
    DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS" | grep -v "(.* rows)")
    for SRC_DB in ${DB_LIST[@]}
    do 
        FILE_TO_DELETE=${SRC_DB}_${WR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    done 
fi
#Calling the required function for monthly backup retention 
if [ "$monthly_backup_required" == "yes" ] && [ "$day_of_month" -eq "$last_day_of_month" ]; then 
    MR=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
    DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS" | grep -v "(.* rows)")
    for SRC_DB in ${DB_LIST[@]}
    do 
        FILE_TO_DELETE=${SRC_DB}_${MR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    done
fi 
#Calling the required function for yearly backup retention 
if [ "$yearly_backup_required" == "yes" ] && [ "$today" == "$last_day_of_year" ]; then 
    YR=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')
    DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS" | grep -v "(.* rows)")
    for SRC_DB in ${DB_LIST[@]}
    do
        FILE_TO_DELETE=${SRC_DB}_${YR}.${EXTENTION}
        if [ -f "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE" ]; then
            rm -f "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
            echo "Deleted file: $BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
        else
            echo "File not found to delete: $BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/$FILE_TO_DELETE"
        fi
    done
fi
