#!/bin/bash
db_host=127.0.0.1
db_user="postgres"
db_password="Nopass@123"
db_post="5432"
db_name="nbol360" 
dst=/backup_v2023
type2=db_backup


daily_retention=7
weekly_retention=2
monthly_retention=1
#============================================================Required Variables=================================================================#
HostName=$(hostname)
full_path=$dst/$HostName/$type2
daily=$full_path/daily
weekly=$full_path/weekly
biweekly=$full_path/biweekly
monthly=$full_path/monthly 

last_month_day1=$(date -d "$(date +%Y-%m-01 -d 'last month')" +%Y-%m-%d)
last_month_last_day=$(date -d "$(date +%Y-%m-01) -1 day" +%Y-%m-%d)
month_day1=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
month_last_day=$(date -d "$(date +%Y-%m-01 -d 'next month') -1 day" +%Y-%m-%d)
month_mid=$(date -d "$(date +%Y-%m-01) +14 day" +%Y-%m-%d)
month_30th_day=$(date -d "$(date +%Y-%m-01) +29 day" +%Y-%m-%d)

date_format=$(date +"%Y-%m-%d_%H-%M-%S")
weekend=$(date +%A)
today=$(date +\%Y-\%m-\%d)
yest1=$(date --date="yesterday" +\%Y%m%d)

dr_val=$((1 * daily_retention))
dr=$(date -d "$dr_val days ago" +%Y-%m-%d)

wr_val=$((7 * weekly_retention))
wr=$(date -d "$wr_val days ago" +%Y-%m-%d)

mr=$(date -d "$monthly_retention month ago" +%F)
#######################################################################DO NOT TOUCH HERE#########################################################
if [ ! -d "$dst/$HostName" ];then
mkdir "$dst/$HostName"
fi

if [ ! -d "$dst/$HostName/$type2" ];then
mkdir "$dst/$HostName/$type2"
fi

if [ ! -d "$full_path/daily" ];then
mkdir "$full_path/daily"
fi
if [ ! -d "$full_path/weekly" ];then
mkdir "$full_path/weekly"
fi
if [ ! -d "$full_path/monthly" ];then
mkdir "$full_path/monthly"
fi

#----------------------------------------------------------------------Daily Backup----------------------------------------------------------------#
mkdir $daily/$today

backup_file="$daily/$today/${db_name}_backup_$date_format.dump.gz"
PGPASSWORD="$db_password" pg_dump -U "$db_user" -h "$db_host" -p "$db_port" "$db_name" | gzip > "$backup_file"

echo "Single database backups successfully created in: $daily/$today"
#----------------------------------------------------------------------Weekly Backup---------------------------------------------------------------#
if [[ "$weekend" == "Friday" ]];then
cp -rp "$daily/$today" "$weekly/"
fi
#----------------------------------------------------------------------Monthly Backup--------------------------------------------------------------#
if [[ "${today}" ==  "$month_last_day" ]];then
cp -rp "$daily/$today" "$monthly/"
fi

#---------------------------------------------------------------------Daily Backup Deletion--------------------------------------------------------#
if [ -d "$daily/$dr" ];then
rm -rf $daily/$dr
fi
#---------------------------------------------------------------------Weekly Backup Deletion-------------------------------------------------------#
if [ -d "$weekly/$wr" ];then
rm -rf "$weekly/$wr"
fi
#---------------------------------------------------------------------Monthly Backup Deletion------------------------------------------------------#
if [[ "${today}" ==  "$month_last_day" ]];then
rm -rf $monthly/$mr
fi
