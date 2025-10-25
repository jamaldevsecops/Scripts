#!/bin/bash

# MySQL connection details
MYSQL_HOST="10.224.2.21"
MYSQL_USER="infra"
MYSQL_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"
MYSQL_PORT="3322"

# MySQL query to get distinct user and host combinations
QUERY="SELECT DISTINCT user, host FROM mysql.user;"

# Run MySQL query to get distinct user and host combinations
USERS_AND_HOSTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -P "$MYSQL_PORT" -N -e "$QUERY" 2>/dev/null)

# Loop through distinct user and host combinations and show grants
while read -r USER HOST; do
    echo "Grants for '$USER'@'$HOST':"
    mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -P "$MYSQL_PORT" -e "SHOW GRANTS FOR '$USER'@'$HOST';"
    echo "-------------------------------------------------------------------------------------------------------"
done <<< "$USERS_AND_HOSTS"
