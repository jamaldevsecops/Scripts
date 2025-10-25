#!/bin/bash
MYSQL_USER="ops"     
MYSQL_PASSWORD="F&D%3X]>k6IdT<jA"


EXCLUDED_USERS=("ops" "infra" "saif_shovon" "tarek_nasif")
HOST_WILDCARD="%"

HOST_LIST=(
    "192.168.20.31"
    "192.168.20.32"
    "192.168.20.34"
    "192.168.20.35"
    "192.168.0.119"
)
for MYSQL_HOST in "${HOST_LIST[@]}"; do

    # Get a list of MySQL users with host '%'
    USER_HOST_LIST=$(mysql -u$MYSQL_USER -h$MYSQL_HOST -p$MYSQL_PASSWORD -Bse "SELECT CONCAT(User, '@', Host) FROM mysql.user WHERE Host = '$HOST_WILDCARD' AND User NOT IN ('root');" 2>/dev/null)

    # Loop through each user and revoke DROP privilege if not in the excluded list
    for USER_HOST in $USER_HOST_LIST; do
        IFS='@' read -r USER HOST <<< "$USER_HOST"
        # Use the $USER and $HOST variables here for your actions
        echo ">>>>>>>>>> Processing user: $USER on host: $HOST"
        # Get a list of databases owned by the user
        OWNED_DATABASES=$(mysql -u$MYSQL_USER -h$MYSQL_HOST -p$MYSQL_PASSWORD -Bse "SELECT DB FROM mysql.db WHERE User = '$USER' AND Host = '$HOST';" 2>/dev/null)
        
        # Revoke DROP privilege for all databases except owned ones
        for DB in $OWNED_DATABASES; do
            if [[ ! " ${EXCLUDED_USERS[@]} " =~ " ${USER} " ]]; then
                mysql -u$MYSQL_USER -h$MYSQL_HOST -p$MYSQL_PASSWORD -e "REVOKE DROP ON $DB.* FROM '$USER'@'$HOST';" 2>/dev/null
                echo "DROP privilege revoked for user $USER on database $DB"
            else
                echo "User $USER is excluded from privilege revocation on database $DB."
            fi
        done
        mysql -u$MYSQL_USER -h$MYSQL_HOST -p$MYSQL_PASSWORD -e "FLUSH PRIVILEGES;" 2>/dev/null
        echo "********************* DROP privilege revoked for user: $USER on owned databases. *********************"
    done

    echo ""
    echo "All '$HOST_WILDCARD' users' DROP privileges revoked except the excluded users."
done

