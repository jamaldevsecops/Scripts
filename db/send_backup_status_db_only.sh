#!/bin/bash
HOST=$(hostname)
#---------------------------------------------------------------------Mailing---------------------------------------------------------------------#
db=/backup_v2023/$HOST/db_backup/daily
 
today=$(date +\%Y-\%m-\%d)
yest=$(date --date="yesterday" +\%Y-%m-%d)


echo "**Database Backup Size of Yesterday**" >> /tmp/backup_size.txt
cd $db && du -sh $yest >> /tmp/backup_size.txt

echo "**Database Backup Size of Today**" >> /tmp/backup_size.txt
cd $db && du -sh $today >> /tmp/backup_size.txt

echo "================================================================" >> /tmp/backup_size.txt
echo "**More Informations:" >> /tmp/backup_size.txt

echo "List of all database daily backup:" >> /tmp/backup_size.txt
cd $db && du -sh * >> /tmp/backup_size.txt

#echo "Hi there! This is an automatic email from SR-PARCEL Prod Server. Please find the attachment." | mutt -a "/ops/ops_var/SR-Parcel_App_DB_size.txt" -s "APP and DB Backup Size" -- jamal.hossain@apsissolutions.com
echo "Hi there! This is an automatic email from $HOST Server." | mail -s "$HOST Backup Size" infra@apsissolutions.com < /tmp/backup_size.txt
