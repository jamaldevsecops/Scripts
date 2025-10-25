#!/bin/bash
# Set source variables
SRC_HOST="192.168.20.32"
SRC_USER=ops
SRC_PASS="F&D%3X]>k6IdT<jA"
SRC_PORT=3306

base_dest="/backup_v2023"

# Retention Period
daily_backup_retention=7
weekly_backup_retention=2
monthly_backup_retention=1
yearly_backup_retention=1

# Set recipient, subject, and message as variables
today=$(date +%Y-%m-%d)
hostname=$(hostname)
recipient="infra@apsissolutions.com"
subject="[Database Backup Summary Report of $hostname] - Date: $today"

# ---------------------------------------------------DON'T TOUCH---------------------------------------------------#
# Create the destination directory if it does not exist
daily_backup_dir="$base_dest/$hostname/daily_backup"
if [ ! -d "$daily_backup_dir" ]; then
    mkdir -p "$daily_backup_dir" && echo "Created $daily_backup_dir directory."
fi

# Initialize the report and file list variables
message="Backup Summary:"
todays_files=""

# Take Daily Backup
databases=$(mysql --user="$SRC_USER" --password="$SRC_PASS" --host="$SRC_HOST" --port="$SRC_PORT" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
for db in $databases; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != _* ]]; then
        echo "Dumping database: $db"
        backup_format="${daily_backup_dir}/${db}_${today}.sql"
        mysqldump --column-statistics=0 --skip-lock-tables --skip-add-locks --user="$SRC_USER" --password="$SRC_PASS" --host="$SRC_HOST" --port="$SRC_PORT" --databases "$db" >"${backup_format}"
        if [ $? -eq 0 ]; then
            message+="\n${db}: Success"
            todays_files+="$backup_format"
        else
            message+="\n${db}: Failed"
        fi
        gzip "$backup_format"
    fi
done

# Check if it is Friday and create a weekly backup directory if not exists
if [ "$(date +%A)" == "Friday" ]; then
    weekly_backup_dir="$base_dest/$hostname/weekly_backup"
    if [ ! -d "$weekly_backup_dir" ]; then
        mkdir -p "$weekly_backup_dir" && echo "Created $weekly_backup_dir directory."
    fi
    # Copy today's backed up files to the weekly backup directory
    cp "$daily_backup_dir"/*.gz "$weekly_backup_dir/"
fi

# Check if it is the last day of the month and create a monthly backup directory if not exists
day_of_month=$(date +%d)
last_day_of_month=$(date -d "$(date +'%Y-%m-01') + 1 month - 1 day" +'%d')

if [ "$day_of_month" -eq "$last_day_of_month" ]; then
    monthly_backup_dir="$base_dest/$hostname/monthly_backup"
    if [ ! -d "$monthly_backup_dir" ]; then
        mkdir -p "$monthly_backup_dir" && echo "Created $monthly_backup_dir directory."
    fi
    # Copy today's backed up files to the monthly backup directory
    cp -rp "$todays_files" "$monthly_backup_dir"
fi

# Check if it is the last day of the year and create a yearly backup directory if not exists
last_day_of_year=$(date -d "$(date +'%Y-12-31')" +'%Y-%m-%d')

if [ "$today" == "$last_day_of_year" ]; then
    yearly_backup_dir="$base_dest/$hostname/yearly_backup"
    if [ ! -d "$yearly_backup_dir" ]; then
        mkdir -p "$yearly_backup_dir" && echo "Created $yearly_backup_dir directory."
    fi
    # Copy today's backed up files to the yearly backup directory
    cp -rp "$todays_files" "$yearly_backup_dir"
fi

# Delete old backup files if the condition meets the daily backup retention
dr_val=$((1 * $daily_backup_retention))
dr=$(date -d "$dr_val days ago" +%Y-%m-%d)
for dir_name in "$daily_backup_dir"/*; do
    [ -f "$dir_name" ] && [ "$(basename "$dir_name" .gz)" -lt "$dr" ] && rm -f "$dir_name"
done

# Delete old backup files if the condition meets the weekly backup retention
wr_val=$((7 * $weekly_backup_retention))
wr=$(date -d "$wr_val days ago" +%Y-%m-%d)
for dir_name in "$weekly_backup_dir"/*; do
    [ -f "$dir_name" ] && [ "$(basename "$dir_name" .gz)" -lt "$wr" ] && rm -f "$dir_name"
done

# Delete old backup files if the condition meets the monthly backup retention
mr=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
for dir_name in "$monthly_backup_dir"/*; do
    [ -f "$dir_name" ] && [ "$(basename "$dir_name" .gz)" -lt "$mr" ] && rm -f "$dir_name"
done

# Delete old backup files if the condition meets the yearly backup retention
yr=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')
for dir_name in "$yearly_backup_dir"/*; do
    [ -f "$dir_name" ] && [ "$(basename "$dir_name" .gz)" -lt "$yr" ] && rm -f "$dir_name"
done
# -------------------------------------------------DON'T TOUCH---------------------------------------------------#

yesterday=$(date --date="yesterday" +\%Y-%m-%d)

cd "$daily_backup_dir"
message+="\n\nApplication Backup Size of Today: "
size_today=$(du -csh *_${today}.tar.gz | awk 'END {print $1}')
message+="$size_today"

message+="\nApplication Backup Size of Yesterday: "
size_yesterday=$(du -csh *_${yesterday}.tar.gz | awk 'END {print $1}')
message+="$size_yesterday"

message+="\n\nList of all application daily backups: "
size_total=$(du -sh *)
message+="\n$size_total"

# Send email
echo -e "$message" | mail -s "$subject" "$recipient"
