#!/bin/bash

# Remote server details
REMOTE_USER="ops"
REMOTE_HOST="192.168.10.50"
REMOTE_DIRS=(
    "/share/DEV-APP-DB-BACKUP/@Recycle"
    "/share/PROD-APP-DB-BACKUP/@Recycle"
    "/share/CONTENTS/@Recycle"
    # Add more directories here if needed
)

# SSH into remote server and remove files within each directory
for dir in "${REMOTE_DIRS[@]}"; do
    ssh "$REMOTE_USER@$REMOTE_HOST" "find $dir -type f -exec rm {} \;"
    echo "Files within remote directory $dir have been removed."
done

