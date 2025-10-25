#!/bin/bash

# Set source and destination variables
read -p "Enter the Source DB IP: " SRC_HOST
read -p "Enter the Source DB Port: " SRC_PORT
read -p "Enter the Source DB Name: " SRC_DB
SRC_USER=infra
#SRC_PASS="F&D%3X]>k6IdT<jA"
SRC_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"


read -p "Enter the Destination DB IP: " DST_HOST
read -p "Enter the Distation DB Port: " DST_PORT
read -p "Enter the Destination DB Name: " DST_DB
DST_USER=infra
DST_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"

SCRIPT_DIR=/home/jamal/system_admin/script/db/backup
# Email configurations
EMAIL_TO="jamal.hossain@apsissolutions.com"
EMAIL_SUBJECT="Table Restoration Report[$SRC_DB to $DST_DB]"
EMAIL_MESSAGE="Take Necessary Actions for the Followings:\n"

SRC_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-mode=VERIFY_CA"
DST_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-cert=./client-cert.pem --ssl-key=./client-key.pem --ssl-mode=VERIFY_CA"

#-------------------------------------------------DON'T TOUCH------------------------------------------------#
# Directory to store temporary tables
TEMP_DIR="/tmp/$SRC_DB-$(date +%Y%m%d%H%M%S)"

# Directory to store temporary tables
if [ ! -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR" || { echo "Error: Unable to create temporary directory"; exit 1; }
fi

# Log file to track the process
LOG_FILE="$SCRIPT_DIR/table_import_log.txt"

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

# Ask the user whether to use the provided table list or fetch dynamically
read -p "Do you want to use a specific table list? (y/n): " USE_SPECIFIC_TABLE_LIST

if [ "$USE_SPECIFIC_TABLE_LIST" == "y" ]; then
    # Read table list file into a variable
    TABLE_LIST=$(cat "$SCRIPT_DIR/table_list.txt" 2>/dev/null) || { echo "Error: Unable to read table_list.txt"; exit 1; }
else
    # Get the list of tables dynamically from the source database
    TABLE_LIST=$(mysql -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER" -p"$SRC_PASS" "$SRC_DB" -e "SHOW TABLES;" | tail -n +2 2>/dev/null) || { echo "Error: Unable to fetch table list from source database"; exit 1; }
fi

# Iterate through the table list and import each table
for table in $TABLE_LIST; do
    echo "Dumping table $table from the source database $SRC_DB."
    mysqldump --skip-lock-tables --skip-add-locks -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER" -p"$SRC_PASS" "$SRC_DB" "$table" > "$TEMP_DIR/$table.sql" 2>/dev/null || { echo "Error: Failed to dump table $table"; continue; }

    # Check if the import was successful
    echo "$(date): Successfully dumped table $table" >> "$LOG_FILE"

    echo "Importing table $table dump into the destination database $DST_DB."
    mysql -h "$DST_HOST" -P "$DST_PORT" -u "$DST_USER" -p"$DST_PASS" "$DST_DB" < "$TEMP_DIR/$table.sql" 2>/dev/null || { echo "Error: Failed to import table $table"; append_to_email_message "$table: Error during importing."; continue; }

    # Check if the import was successful
    echo "$(date): Successfully imported table $table" >> "$LOG_FILE"
    append_to_email_message "$table: Success."

    # Remove the temporary dump file
    rm "$TEMP_DIR/$table.sql"
done

append_to_email_message "\n\n***This is an automated message and needs immediate attention. Please do not replay***"
# Send the final email with the summary
echo -e "$EMAIL_MESSAGE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"

