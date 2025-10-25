#!/bin/bash

# Set source and destination variables
SRC_HOST="192.168.10.30"
SRC_PORT="5412"
SRC_USER="ops"
SRC_PASS="Dhaka@123"

# Exclude specific databases
EXCLUDE_DBS="postgres|root|ops"

base_dest="/backup_v2023"
# Retention Period 
daily_backup_retention=7
weekly_backup_retention=2
monthly_backup_retention=1
yearly_backup_retention=1

# Required Backup Policy 
daily_backup_required="yes" 
weekly_backup_required="yes" 
monthly_backup_required="yes" 
yearly_backup_required="yes" 

# Set recipient, subject, and message as variables
today=$(date +%Y-%m-%d)
yesterday=$(date --date="yesterday" +%Y-%m-%d)
hostname=$(hostname)
recipient="jamal.hossain@apsissolutions.com"
subject="[Databases Backup Summary Report of $hostname] - Date: $today"

# Initialize the report and file list variables
message="Backup Summary:"
todays_files=""

# Function to list all databases except the excluded ones
all_db_list(){
    DB_LIST=$(PGPASSWORD="$SRC_PASS" psql -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | tail -n +3 | grep -vE "$EXCLUDE_DBS)" | grep -v "(.* rows)")
}

# Function to perform daily backup and retention
daily_backup_and_retention() {
    # Create the destination directory if it does not exist
    daily_backup_dir="$base_dest/$hostname/daily_backup" 
    if [ ! -d "$daily_backup_dir" ]; then
        mkdir -p "$daily_backup_dir" && echo "created $daily_backup_dir directory."
    fi

    # Calling the required function for listing the databases
    all_db_list

    # Loop through each database for backup
    for SRC_DB in ${DB_LIST[@]}
    do 
        today_bkp_filename="${SRC_DB}_${today}.dump.gz"
        # Create backup for the specific database and update the report
        PGPASSWORD="$SRC_PASS" pg_dump -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_DB" --format=custom | gzip > "${daily_backup_dir}/${today_bkp_filename}" 2>/dev/null

        if [ $? -eq 0 ]; then
            message+="\n${SRC_DB}: Success"
            todays_files+=" ${daily_backup_dir}/$today_bkp_filename"
        else
            message+="\n${SRC_DB}: Failed"
        fi
    done

    # Delete old backup files if condition meets the daily backup retention
    dr_val=$((1 * $daily_backup_retention))
    dr=$(date -d "$dr_val days ago" +%Y-%m-%d)
    file_to_delete="${SRC_DB}_${dr}.dump.gz"

    if [ -f "$daily_backup_dir/$file_to_delete" ]; then
        rm -f "$daily_backup_dir/$file_to_delete"
        echo "Deleted file: $daily_backup_dir/$file_to_delete"
    else
        echo "File not found: $daily_backup_dir/$file_to_delete"
    fi

    message+="\n\nDatabase Backup Size of Today: "
    size_today="No backup file found for today"
    if [ -f "${daily_backup_dir}/${today_bkp_filename}" ]; then
        size_today=$(du -sh "${daily_backup_dir}/${today_bkp_filename}" | awk '{print $1}')
    fi
    message+="$size_today"

    message+="\nDatabase Backup Size of Yesterday: "
    size_yesterday="No backup file found for yesterday"
    if [ -f "${daily_backup_dir}/${SRC_DB}_${yesterday}.dump.gz}" ]; then
        size_yesterday=$(du -sh "${daily_backup_dir}/${SRC_DB}_${yesterday}.dump.gz}" | awk '{print $1}')
    fi
    message+="$size_yesterday"
}

weekly_backup_and_retention() {
    # Check if it is Friday and create a weekly backup directory if not exists
    if [ $(date +%A) == "Friday" ]; then
        weekly_backup_dir="$base_dest/$hostname/weekly_backup"
        if [ ! -d "$weekly_backup_dir" ]; then
            mkdir -p "$weekly_backup_dir" && echo "created $weekly_backup_dir directory."
        fi

        if [ "$daily_backup_required" != "yes" ]; then
            # Calling the required function for listing the databases
            all_db_list
            # Loop through each database for backup
            for SRC_DB in ${DB_LIST[@]}
            do 
                today_bkp_filename="${SRC_DB}_${today}.dump.gz"
                # Create backup for the specific database and update the report
                PGPASSWORD="$SRC_PASS" pg_dump -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_DB" --format=custom | gzip > "${weekly_backup_dir}/${today_bkp_filename}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    message+="\n${SRC_DB}: Success"
                    todays_files+=" ${weekly_backup_dir}/$today_bkp_filename"
                else
                    message+="\n${SRC_DB}: Failed"
                fi
            done 
        else 
            cp -r $todays_files "$weekly_backup_dir"
        fi 

        # Delete old backup files if condition meets the weekly backup retention
        wr_val=$((7 * $weekly_backup_retention))
        wr=$(date -d "$wr_val days ago" +%Y-%m-%d)
        file_to_delete=${SRC_DB}_${wr}.dump.gz

        if [ -f "$weekly_backup_dir/$file_to_delete" ]; then
            rm -f "$weekly_backup_dir/$file_to_delete"
            echo "Deleted file: $weekly_backup_dir/$file_to_delete"
        else
            echo "File not found: $weekly_backup_dir/$file_to_delete"
        fi

        message+="\n\nDatabase Backup Size of this Week: "
        size_today="No backup file found for this Week"
        if [ -f "${weekly_backup_dir}/${today_bkp_filename}" ]; then
            size_today=$(du -sh "${weekly_backup_dir}/${today_bkp_filename}" | awk '{print $1}')
        fi
        message+="$size_today"

        message+="\nDatabase Backup Size of Last Week: "
        size_last_week="No backup file found for Last Week"
        last_week=$(date -d "last week" +%Y-%m-%d)
        if [ -f "${weekly_backup_dir}/${SRC_DB}_${last_week}.dump.gz}" ]; then
            size_yesterday=$(du -sh "${weekly_backup_dir}/${SRC_DB}_${last_week}.dump.gz}" | awk '{print $1}')
        fi
        message+="$size_last_week"
    fi
    echo -e "$message" > weekly_backup_report.txt
}

monthly_backup_and_retention() {
    # Check if it is the last day of the month and create a monthly backup directory if not exists
    day_of_month=$(date +%d)
    last_day_of_month=$(date -d "$(date +'%Y-%m-01') + 1 month - 1 day" +'%d')

    if [ "$day_of_month" -eq "$last_day_of_month" ]; then
        monthly_backup_dir="$base_dest/$hostname/monthly_backup"
        if [ ! -d "$monthly_backup_dir" ]; then
            mkdir -p "$monthly_backup_dir" && echo "created $monthly_backup_dir directory."
        fi

        if [ "$monthly_backup_required" != "yes" ]; then
            # Calling the required function for listing the databases
            all_db_list
            # Loop through each database for backup
            for SRC_DB in ${DB_LIST[@]}
            do 
                today_bkp_filename="${SRC_DB}_${today}.dump.gz"
                # Create backup for the specific database and update the report
                PGPASSWORD="$SRC_PASS" pg_dump -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_DB" --format=custom | gzip > "${monthly_backup_dir}/${today_bkp_filename}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    message+="\n${SRC_DB}: Success"
                    todays_files+=" ${monthly_backup_dir}/$today_bkp_filename"
                else
                    message+="\n${SRC_DB}: Failed"
                fi
            done 
        else 
            cp -r $todays_files "$monthly_backup_dir"
        fi 

        # Delete old backup files if condition meets the monthly backup retention
        mr=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
        file_to_delete=${SRC_DB}_${mr}.dump.gz
        if [ -f "$monthly_backup_dir/$file_to_delete" ]; then
            rm -f "$monthly_backup_dir/$file_to_delete"
            echo "Deleted file: $monthly_backup_dir/$file_to_delete"
        else
            echo "File not found: $monthly_backup_dir/$file
