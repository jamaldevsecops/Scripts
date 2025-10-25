#!/bin/bash

# Set source and destination variables
SRC_HOST=production-database.mysql.database.azure.com
SRC_USER=infra
SRC_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"
SRC_PORT=3306
SRC_DB=prism_batb

DST_HOST=192.168.20.201
DST_USER=ops
DST_PASS="F&D%3X]>k6IdT<jA"
DST_PORT=3380
DST_DB=prism_batb

# Read table list file into a variable
TABLE_LIST=$(cat table_list.txt)

# Email configurations
EMAIL_TO="jamal.hossain@apsissolutions.com"
EMAIL_SUBJECT="Table Restoration Report[$SRC_DB to $DST_DB]"
EMAIL_MESSAGE="Take Necessary Actions for the Followings:\n"

SRC_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-mode=VERIFY_CA"
DST_SSL="--ssl-mode=REQUIRED --ssl-ca=./ca-cert.pem --ssl-cert=./client-cert.pem --ssl-key=./client-key.pem --ssl-mode=VERIFY_CA"

#-------------------------------------------------DON'T TOUCH------------------------------------------------#
# Directory to store temporary tables
TEMP_DIR="/tmp/$SRC_DB"

# Directory to store temporary tables
if [ ! -d "$TEMP_DIR" ]; then
    mkdir "$TEMP_DIR"
fi

# Log file to track the process
LOG_FILE="table_import_log.txt"

# Function to append to the email message
append_to_email_message() {
    local message=$1
    EMAIL_MESSAGE+="\n$message"
}

# Iterate through the table list and import each table
for table in $TABLE_LIST; do
    echo "Dumping table $table from the source database $SRC_DB."
    mysqldump --skip-lock-tables --skip-add-locks -h $SRC_HOST -P $SRC_PORT -u $SRC_USER -p$SRC_PASS $SRC_DB $table > /$TEMP_DIR/$table.sql 2>/dev/null

    # Check if the dump was successful
    if [ $? -eq 0 ]; then
        echo "$(date): Successfully dumped table $table" >> $LOG_FILE
        echo "Importing table $table dump into the destination database $DST_DB."
        mysql -h $DST_HOST -P $DST_PORT -u $DST_USER -p$DST_PASS $DST_DB < /$TEMP_DIR/$table.sql 2>/dev/null

        # Check if the import was successful
        if [ $? -eq 0 ]; then
            echo "$(date): Successfully imported table $table" >> $LOG_FILE
            append_to_email_message "$table: Success."
        else
            echo "$(date): Error importing table $table" >> $LOG_FILE
            append_to_email_message "$table: Error during importing."
        fi

        # Remove the temporary dump file
        rm /$TEMP_DIR/$table.sql
    else
        echo "$(date): Error dumping table $table" >> $LOG_FILE
        append_to_email_message "$table: Error during dumping."
    fi
done
append_to_email_message "\n\n***This is an automated message and needs immediate attention. Please do not replay***"
# Send the final email with the summary
echo -e "$EMAIL_MESSAGE" | mail -s "$EMAIL_SUBJECT" "$EMAIL_TO"
