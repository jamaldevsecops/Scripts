#!/bin/bash
DB1=
DB2=
DB3=
DB_USER=
DB_PASS=
DB_POR=


echo -p "Email Address of the User: " email
username=$(echo "$email" | cut -d '@' -f 1 | tr '.' '_')
random_pass=$(pwgen -snc -1 16)

echo -p "Create User on $DB1? (y/n) :" confirm
if [ "$confirm" == "y" ]; then
    mysql -h $DB1 -u $DB_USER -P $DB_PORT -p$DB_PASS -e "create user '$username'@'%' identified by '$random_pass';" 
else 
    exit 1
fi
