#!/bin/bash

# Set source and destination variables
SRC_HOST=192.168.20.32
SRC_USER=ops
SRC_PASS="F&D%3X]>k6IdT<jA"
SRC_PORT=3306
SRC_DB=recruitment

DST_HOST=192.168.10.30
DST_USER=ops
DST_PASS="F&D%3X]>k6IdT<jA"
DST_PORT=3357
DST_DB=recruitment_demo

SCRIPT_DIR=/home/jamal/system_admin/script/db/backup
# Email configurations
EMAIL_TO="jamal.hossain@apsissolutions.com"
EMAIL_SUBJECT="Table Restoration Report[$SRC_DB to $DST_DB]"
EMAIL_MESSAGE="Take Necessary Actions for the Followings:\n"

SRC_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-mode=VERIFY_CA"
DST_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-cert=./client-cert.pem --ssl-key=./client-key.pem --ssl-mode=VERIFY_CA"

#-------------------------------------------------DON'T TOUCH------------------------------------------------#
# Directory to store temporary database backup
TEMP_DIR="/tmp/$SRC_DB-$(date +%Y%m%d%H%M%S)"

# Directory to store temporary database backup
if [ ! -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR" || { echo "Error: Unable to create temporary directory"; exit 1; }
fi

# Log file to track the process
LOG_FILE="$SCRIPT_DIR/db_backup_log.txt"

# Function to append to the email message
append_to_email_message() {
    local message=$1
    EMAIL_MESSAGE+="\n$message"
}

# Function to clean up temporary directory
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Trap to ensure cleanup on script exit
trap cleanup EXIT

# Dump the entire source database
echo "Dumping database $SRC_DB."
mysqldump --skip-lock-tables --skip-add-locks -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER" -p"$SRC_PASS" "$SRC_DB" > "$TEMP_DIR/$SRC_DB.sql" 2>/dev/null || { echo "Error: Failed to dump database $SRC_DB"; exit 1; }

# Check if the database dump was successful
echo "$(date): Successfully dumped database $SRC_DB" >> "$LOG_FILE"

# Import the database dump into the destination database
echo "Importing database $SRC_DB dump into the destination database $DST_DB."
mysql -h "$DST_HOST" -P "$DST_PORT" -u "$DST_USER" -p"$DST_PASS" "$DST_DB" < "$TEMP_DIR/$SRC_DB.sql" 2>/dev/null || { echo "Error: Failed to import database $SRC_DB"; append_to_email_message "$SRC_DB: Error during importing."; exit 1; }

# Check if the import was successful
echo "$(date): Successfully imported database $SRC_DB" >> "$LOG_FILE"
append_to_email_message "$SRC_DB: Success."

# Remove the temporary database dump file
rm "$TEMP_DIR/$SRC_DB.sql"

append_to_email_message "\n\n***This is an automated message and needs immediate attention. Please do not replay***"
# Send the final email with the summary
echo -e "$EMAIL_MESSAGE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"


