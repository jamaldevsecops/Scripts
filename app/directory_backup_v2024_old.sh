#!/bin/bash
today=$(date +%Y-%m-%d)
backup_dir="/var/www/html"
base_dest="/backup_v2023"


#Retention Period 
daily_backup_retention=7
weekly_backup_retention=2
monthly_backup_retention=1
yearly_backup_retention=1

# Required Variables
hostname=$(hostname)


last_day_of_month=$(date -d "$(date +'%Y-%m-01') + 1 month - 1 day" +'%d')
last_day_of_year=$(date -d "$(date +'%Y-12-31')" +'%Y-%m-%d')
yesterday=$(date --date="yesterday" +\%Y-%m-%d)

# Set recipient, subject, and message as variables
recipient="infra@apsissolutions.com"
subject="[Applications Backup Summary Report of $hostname] - Date: $today"
#----------------------------------------------------------------------------------------------------------------------#
#Create the destination directory if it does not exist"
daily_backup_dir="$base_dest/$hostname/daily_backup" 
if [ ! -d "$daily_backup_dir" ]; then
    mkdir -p "$daily_backup_dir" && echo "created $daily_backup_dir directory."
fi

# List all directories in the backup directory
directories=($(find "$backup_dir" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;))

# Initialize the report and file list variables
message="Backup Summery at a Glance:"
todays_files=""

# Create backups for each directory and update the report
for dir_name in "${directories[@]}"
do
    tar -czf "${daily_backup_dir}/${dir_name}_${today}.tar.gz" -C "$backup_dir" "$dir_name"
    if [ $? -eq 0 ]; then
        message+="\n${dir_name}: Success"
        todays_files+=" ${daily_backup_dir}/${dir_name}_${today}.tar.gz"
    else
        message+="\n${dir_name}: Failed"
    fi
done

# Check if it is Friday and create a weekly backup directory if not exists
if [ $(date +%A) == "Friday" ]; then
    weekly_backup_dir="$base_dest/$hostname/weekly_backup"
    if [ ! -d "$weekly_backup_dir" ]; then
        mkdir -p "$weekly_backup_dir" && echo "created $weekly_backup_dir directory."
    fi
    # Copy today's backed up files to the weekly backup directory
    cp -r $todays_files "$weekly_backup_dir"
fi

# Check if it is the last day of the month and create a monthly backup directory if not exists
day_of_month=$(date +%d)
if [ "$day_of_month" -eq "$last_day_of_month" ]; then
    monthly_backup_dir="$base_dest/$hostname/monthly_backup"
    if [ ! -d "$monthly_backup_dir" ]; then
        mkdir -p "$monthly_backup_dir" && echo "created $monthly_backup_dir directory."
    fi
    # Copy today's backed up files to the monthly backup directory
    cp -r $todays_files "$monthly_backup_dir"
fi

# Check if it is the last day of the year and create a yearly backup directory if not exists
if [ "$today" == "$last_day_of_year" ]; then
    yearly_backup_dir="$base_dest/$hostname/yearly_backup"
    if [ ! -d "$yearly_backup_dir" ]; then
        mkdir -p "$yearly_backup_dir" && echo "created $yearly_backup_dir directory."
    fi
    # Copy today's backed up files to the yearly backup directory
    cp -r $todays_files "$yearly_backup_dir"
fi


# Delete old backup files if condition meets the daily backup retention
dr_val=$((1 * $daily_backup_retention))
dr=$(date -d "$dr_val days ago" +%Y-%m-%d)
for dir_name in "${directories[@]}"
do
    cd ${daily_backup_dir} && rm -f ${dir_name}_${dr}.tar.gz
done

# Delete old backup files if condition meets the weekly backup retention
wr_val=$((7 * $weekly_backup_retention))
wr=$(date -d "$wr_val days ago" +%Y-%m-%d)
for dir_name in "${directories[@]}"
do
    cd ${weekly_backup_dir} && rm -f ${dir_name}_${wr}.tar.gz
done

# Delete old backup files if condition meets the monthly backup retention
mr=$(date -d "$(date +'%Y-%m-01') - $monthly_backup_retention month +1 month -1 day" +'%Y-%m-%d')
for dir_name in "${directories[@]}"
do
    cd ${monthly_backup_dir} && rm -f ${dir_name}_${mr}.tar.gz
done

# Delete old backup files if condition meets the yearly backup retention
yr=$(date -d "-${yearly_backup_retention} year" +'%Y-12-31')
for dir_name in "${directories[@]}"
do
    cd ${yearly_backup_dir} && rm -f ${dir_name}_${yr}.tar.gz
done


cd $daily_backup_dir 
message+="\nApplication Backup Size of Today: "
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
