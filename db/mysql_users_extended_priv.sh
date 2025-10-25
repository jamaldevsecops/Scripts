#!/bin/bash

# Function to prompt for user choice with validation
prompt_user_choice() {
    while true; do
        echo "Operation Menu:"
        echo "1. for development"
        echo "2. for production"
        echo "00. Exit"
        read -p "Enter your choice: " OPERATION_TYPE_CHOICE

        case "$OPERATION_TYPE_CHOICE" in
            "1")
                MYSQL_USER="ops"
                MYSQL_PASS="F&D%3X]>k6IdT<jA"
                break
                ;;
            "2")
                MYSQL_USER="infra"
                MYSQL_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"
                break
                ;;
            "00")
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please choose 1 for DEV, 2 for PROD, or 00 to exit."
                ;;
        esac
    done
}

# Function to prompt for MySQL host with validation
prompt_mysql_host() {
    while true; do
        read -p "Enter MySQL host: " MYSQL_HOST
        if [[ -z "$MYSQL_HOST" ]]; then
            echo "MySQL host cannot be empty. Please try again."
        else
            break
        fi
    done
}

# Function to prompt for MySQL port with validation
prompt_mysql_port() {
    while true; do
        read -p "Enter MySQL port: " MYSQL_PORT
        if ! [[ "$MYSQL_PORT" =~ ^[0-9]+$ ]]; then
            echo "Invalid MySQL port. Please enter a valid number."
        else
            break
        fi
    done
}

# Main script execution
prompt_user_choice
prompt_mysql_host
prompt_mysql_port

# MySQL query to get distinct user and host combinations
QUERY="SELECT DISTINCT user, host FROM mysql.user;"

# Run MySQL query to get distinct user and host combinations
USERS_AND_HOSTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -P "$MYSQL_PORT" -N -e "$QUERY" 2>/dev/null)

# Check for errors
if [ $? -ne 0 ]; then
    echo "Error: MySQL query failed. Exiting."
    exit 1
fi

# Loop through distinct user and host combinations and check for 'ALL PRIVILEGES'
while read -r USER HOST; do
    GRANTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -P "$MYSQL_PORT" -e "SHOW GRANTS FOR '$USER'@'$HOST';" 2>/dev/null)
    if echo "$GRANTS" | grep -q "GRANT ALL PRIVILEGES"; then
        echo "Grants for '$USER'@'$HOST':"
        echo "$GRANTS" | grep "GRANT ALL PRIVILEGES"
        echo "-------------------------------------------------------------------------------------------------------"
    fi
done <<< "$USERS_AND_HOSTS"

