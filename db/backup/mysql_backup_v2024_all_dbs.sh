#!/bin/bash
# Set source and destination variables
SRC_HOST="192.168.20.201"
SRC_PORT="3357"
SRC_USER="ops"
SRC_PASS="F&D%3X]>k6IdT<jA"

# Exclude specific databases
EXCLUDE_DBS="information_schema|mysql|performance_schema|sys"

#Destination base directory 
BASE_DEST="/backup"

#Retention Period 
daily_backup_retention=7
weekly_backup_retention=2
monthly_backup_retention=1
yearly_backup_retention=1

# Required Backup Policy 
daily_backup_required="yes" 
weekly_backup_required="yes" 
monthly_backup_required="yes" 
yearly_backup_required="yes" 

DAILY_BACKUP_NAME=daily_backup
WEEKLY_BACKUP_NAME=weekly_backup
MONTHLY_BACKUP_NAME=monthly_backup
YEARLY_BACKUP_NAME=yearly_backup

# Set recipient, subject, and message as variables
recipient="jamal.hossain@apsissolutions.com"
subject="[Databases Backup Summary Report of $HOSTNAME] - Date: $today"

EXTENTION=sql.gz


#--------------------------------------------------------------------------------------------------------------------------------#
#Variables for greping dates
HOSTNAME=$(hostname)
today=$(date +%Y-%m-%d)
WEEKEND=$(date +%A)
yesterday=$(date --date="yesterday" +%Y-%m-%d)
day_of_month=$(date +%d)
last_day_of_month=$(date -d "$(date +'%Y-%m-01') + 1 month - 1 day" +'%d')
last_day_of_year=$(date -d "$(date +'%Y-12-31')" +'%Y-%m-%d')

#Variables for retention operation 
DR_VALUE=$((1 * $daily_backup_retention))
WR_VALUE=$((7 * $weekly_backup_retention))
DR=$(date -d "$DR_VALUE days ago" +%Y-%m-%d)
WR=$(date -d "$WR_VALUE days ago" +%Y-%m-%d)
MR=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
YR=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')

# Initialize the report and file list variables
message="Backup Summery:"
todays_files=""
#----------------------------------------------------------------------------------------------------------------------#
create_daily_bkp_dir(){
    if [ ! -d "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME" ]; then
        mkdir -p "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME" && echo "The directory '$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME' created"
    fi
}

create_weekly_bkp_dir(){
    if [ ! -d "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME" ]; then
        mkdir -p "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME" && echo "The directory '$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME' created"
    fi
}

create_monthly_bkp_dir(){
    if [ ! -d "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME" ]; then
            mkdir -p "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME" && echo "The directory '$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME' created"
    fi
}

create_yearly_bkp_dir(){
    if [ ! -d "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME" ]; then
        mkdir -p "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME" && echo "The directory '$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME' created"
    fi
}

take_bkup(){
    DB_LIST=$(mysql -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER" --password="$SRC_PASS" -e "SHOW DATABASES;" | tail -n +2 | grep -vE "^($EXCLUDE_DBS)$")
    for SRC_DB in ${DB_LIST[@]}
    do 
        BKP_FILENAME="${SRC_DB}_${today}.${EXTENTION}"
        mysqldump --skip-lock-tables --skip-add-locks -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER" --password="$SRC_PASS" -R "$SRC_DB" | gzip > "/tmp/${BKP_FILENAME}" 2>/dev/null
        if [ $? -eq 0 ]; then
            message+="\n${SRC_DB}: Success"
            todays_files+=" /tmp/${BKP_FILENAME}"
        else
            message+="\n${SRC_DB}: Failed"
        fi
    done
}
#---------------------------------------------------------------------------------------------------------------------------#
#Calling the required function for daily backup 
if [ "$daily_backup_required" == "yes" ]; then
    create_daily_bkp_dir
    echo "Initializing new daily backup..."
    take_bkup
    mv $todays_files "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/" 
else 
    echo "Daily backup is disabled"
fi
echo
echo
echo
#Calling the required function for weekly backup 
    if [ "$WEEKEND" == "Friday" ] && [ "$daily_backup_required" == "yes" ]; then
        create_weekly_bkp_dir 
        echo "Copying files from daily backup to weekly backup"
        cp -r "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/" 
    elif [ "$WEEKEND" == "Friday" ] && [ "$weekly_backup_required" == "yes" ]; then
        create_weekly_bkp_dir 
        echo "No daily backup found for today. Initializing new weekly backup..."
        take_bkup
        mv $todays_files "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/"
    else 
        echo "Today is not weekend or weekly backup is disabled"
    fi
echo
echo
echo
#Calling the required function for monthly backup 
    if [ "$day_of_month" -eq "$last_day_of_month" ] && [ "$daily_backup_required" == "yes" ]; then
        create_monthly_bkp_dir
        echo "Copying files from daily backup to monthly backup"
        cp -r "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/"
    elif [ "$day_of_month" -eq "$last_day_of_month" ] && [ "$weekly_backup_required" == "yes" ]; then
        create_monthly_bkp_dir   
        echo "Copying files from weekly backup to monthly backup" 
        cp -r "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/"
    elif [ "$day_of_month" -eq "$last_day_of_month" ] && [ "$monthly_backup_required" == "yes" ]; then
        create_monthly_bkp_dir
        echo "No daily, weekly backup found for today. Initiating new monthly backup..."
        take_bkup
        mv $todays_files "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME"
    else 
        echo "Today is not the last day of this month or monthly backup is disabled"
    fi
echo
echo
echo
#Calling the required function for yearly backup 
    if [ "$today" == "$last_day_of_year" ] && [ "$daily_backup_required" == "yes" ]; then 
        create_yearly_bkp_dir
        echo "Copying files from daily backup to yearly backup"
        cp -r "$BASE_DEST/$HOSTNAME/$DAILY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/" 
    elif [ "$today" == "$last_day_of_year" ] && [ "$weekly_backup_required" == "yes" ]; then 
        create_yearly_bkp_dir
        echo "Copying files from weekly backup to yearly backup"
         cp -r "$BASE_DEST/$HOSTNAME/$WEEKLY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/"
    elif [ "$today" == "$last_day_of_year" ] && [ "$monthly_backup_required" == "yes" ]; then 
        create_yearly_bkp_dir
        echo "Copying files from monthly backup to yearly backup"
        cp -r "$BASE_DEST/$HOSTNAME/$MONTHLY_BACKUP_NAME/$BKP_FILENAME" "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/"
    elif [ "$today" == "$last_day_of_year" ] && [ "$yearly_backup_required" == "yes" ]; then
        create_yearly_bkp_dir
        echo "No daily, weekly, monthly backup found for today. Initiating new yearly backup..."
        take_bkup
        mv $todays_files "$BASE_DEST/$HOSTNAME/$YEARLY_BACKUP_NAME/"
    else 
        echo "Today is not the last day of this year or yearly backup is disabled"

    fi 
echo
echo
echo
#---------------------------------------------Retention Operation--------------------------------------------------------- 
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


#message+="\n\nList of all Database daily backups: "
#size_total=$(du -sh *.${EXTENTION})
#message+="\n$size_total"



# Send email
echo -e "$message" | mail -s "$subject" "$recipient"