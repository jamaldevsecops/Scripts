#!/bin/bash
# Set source and destination variables
SRC_HOST="192.168.10.18"
SRC_PORT="5432"
SRC_DB="zunoks360"
SRC_USER="backup"
SRC_PASS="mN>ta8%s6ug}"

base_dest="/backup_v2023"
#Retention Period 
daily_backup_retention=7
weekly_backup_retention=2
monthly_backup_retention=1
yearly_backup_retention=1

# Set recipient, subject, and message as variables
today=$(date +%Y-%m-%d)
yesterday=$(date --date="yesterday" +%Y-%m-%d)
hostname=$(hostname)
recipient="report.infra@apsissolutions.com"
subject="[Databases Backup Summary Report of $hostname] - Date: $today"

# Initialize the report and file list variables
message="Backup Summery:"
todays_files=""
#----------------------------------------------------------------------------------------------------------------------#
daily_backup_and_retention() {
    #Create the destination directory if it does not exist"
    daily_backup_dir="$base_dest/$hostname/daily_backup" 
    if [ ! -d "$daily_backup_dir" ]; then
        mkdir -p "$daily_backup_dir" && echo "created $daily_backup_dir directory."
    fi

    # Create backup for the specific the database and update the report
    backup_filename="${SRC_DB}_${today}.dump.gz"

    PGPASSWORD="$SRC_PASS" pg_dump -h "$SRC_HOST" -p "$SRC_PORT" -U "$SRC_USER" -d "$SRC_DB" -F c | gzip > "${daily_backup_dir}/${backup_filename}" 2>/dev/null
    if [ $? -eq 0 ]; then
        message+="\n${SRC_DB}: Success"
        todays_files+=" ${daily_backup_dir}/$backup_filename"
    else
        message+="\n${SRC_DB}: Failed"
    fi

    # Delete old backup files if condition meets the daily backup retention
    dr_val=$((1 * $daily_backup_retention))
    dr=$(date -d "$dr_val days ago" +%Y-%m-%d)
    file_to_delete=${SRC_DB}_${dr}.sql.gz

    if [ -f "$daily_backup_dir/$file_to_delete" ]; then
        rm -f "$daily_backup_dir/$file_to_delete"
        echo "Deleted file: $daily_backup_dir/$file_to_delete"
    else
        echo "File not found: $daily_backup_dir/$file_to_delete"
    fi
}



weekly_backup_and_retention() {
    # Check if it is Friday and create a weekly backup directory if not exists
    if [ $(date +%A) == "Friday" ]; then
        weekly_backup_dir="$base_dest/$hostname/weekly_backup"
        if [ ! -d "$weekly_backup_dir" ]; then
            mkdir -p "$weekly_backup_dir" && echo "created $weekly_backup_dir directory."
        fi
        # Copy today's backed up files to the weekly backup directory
        cp -r $todays_files "$weekly_backup_dir"
    fi

    # Delete old backup files if condition meets the weekly backup retention
    wr_val=$((7 * $weekly_backup_retention))
    wr=$(date -d "$wr_val days ago" +%Y-%m-%d)
    file_to_delete=${SRC_DB}_${wr}.sql.gz

    if [ -f "$weekly_backup_dir/$file_to_delete" ]; then
        rm -f "$weekly_backup_dir/$file_to_delete"
        echo "Deleted file: $weekly_backup_dir/$file_to_delete"
    else
        echo "File not found: $weekly_backup_dir/$file_to_delete"
    fi
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
        # Copy today's backed up files to the monthly backup directory
        cp -r $todays_files "$monthly_backup_dir"
    fi

    # Delete old backup files if condition meets the monthly backup retention
    mr=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')

    file_to_delete=${SRC_DB}_${mr}.sql.gz
    if [ -f "$monthly_backup_dir/$file_to_delete" ]; then
        rm -f "$monthly_backup_dir/$file_to_delete"
        echo "Deleted file: $monthly_backup_dir/$file_to_delete"
    else
        echo "File not found: $monthly_backup_dir/$file_to_delete"
    fi
}

yearly_backup_and_retention() {
    # Check if it is the last day of the year and create a yearly backup directory if not exists
    last_day_of_year=$(date -d "$(date +'%Y-12-31')" +'%Y-%m-%d')

    if [ "$today" == "$last_day_of_year" ]; then
        yearly_backup_dir="$base_dest/$hostname/yearly_backup"
        if [ ! -d "$yearly_backup_dir" ]; then
            mkdir -p "$yearly_backup_dir" && echo "created $yearly_backup_dir directory."
        fi
        # Copy today's backed up files to the yearly backup directory
        cp -r $todays_files "$yearly_backup_dir"
    fi

    # Delete old backup files if condition meets the yearly backup retention
    yr=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')
    file_to_delete=${SRC_DB}_${yr}.sql.gz

    if [ -f "$yearly_backup_dir/$file_to_delete" ]; then
        rm -f "$yearly_backup_dir/$file_to_delete"
        echo "Deleted file: $yearly_backup_dir/$file_to_delete"
    else
        echo "File not found: $yearly_backup_dir/$file_to_delete"
    fi
}
#---------------------------------------------------------------------------------------------------------------------------#
#Calling the required function for backup 
daily_backup_and_retention
weekly_backup_and_retention
monthly_backup_and_retention
yearly_backup_and_retention


cd "$daily_backup_dir" 
message+="\n\nDatabase Backup Size of Today: "
size_today="No backup file found for today"
if [ -f "${SRC_DB}_${today}.sql.gz" ]; then
    size_today=$(du -sh "${SRC_DB}_${today}.sql.gz" | awk '{print $1}')
fi
message+="$size_today"

message+="\nDatabase Backup Size of Yesterday: "
size_yesterday="No backup file found for yesterday"
if [ -f "${SRC_DB}_${yesterday}.sql.gz" ]; then
    size_yesterday=$(du -sh "${SRC_DB}_${yesterday}.sql.gz" | awk '{print $1}')
fi
message+="$size_yesterday"

message+="\n\nList of all Database daily backups: "
size_total=$(du -sh *.sql.gz)
message+="\n$size_total"



# Send email
echo -e "$message" | mail -s "$subject" "$recipient"