#!/bin/bash

# Display formal confirmation message
echo "+-------------------------------------------------------+"
echo "|                                                       |"
echo "|   NOTICE: This script is configured for deleting a    |"
echo "|           user from a list of database servers.       |"
echo "|                                                       |"
echo "|   Please use caution and ensure you have verified     |"
echo "|   the user and servers before proceeding.             |"
echo "|                                                       |"
echo "+-------------------------------------------------------+"
read -p "Do you want to continue? (yes/no): " confirmation

# Check user's response
if [ "$confirmation" != "yes" ]; then
  echo "Exiting script. No changes were made."
  exit 0
fi

# Prompt user for email address
read -p "Email Address of the user? [e.g., user.name@apsissolutions.com]: " email

# Convert email address to MySQL username
user=$(echo "$email" | awk -F'[@.]' '{print $1}')

# Define the host variations
hosts=('localhost' '127.0.0.1' '172.20.%' '%')

# Define the list of databases
databases=(
  "192.168.0.119"
  "192.168.20.31"
  "192.168.20.32"
  "192.168.20.34"
  "192.168.20.35"
  "192.168.20.201"
)

# Define the ports for each database
ports=('3306' '3356' '3380' '3103')

# MySQL credentials
DB_ADMIN_USER='infra'
DB_ADMIN_PASS='F&D%3X]>k6IdT<jA'

# Email configuration
EMAIL_RECIPIENT='jamal.hossain@apsissolutions.com'
EMAIL_SUBJECT='MySQL User Revocation Status'
EMAIL_BODY=""

# Loop through each database and host
for db in "${databases[@]}"; do
  for host in "${hosts[@]}"; do
    # Loop through each port
    for port in "${ports[@]}"; do
      # Check if the user exists before attempting to revoke privileges
      if mysql -h "$db" -P "$port" -u "$DB_ADMIN_USER" -p"$DB_ADMIN_PASS" -e \
        "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$user' AND host = '$host') as result" | grep -q '1'; then
        # User exists, revoke privileges
        mysql -h "$db" -P "$port" -u "$DB_ADMIN_USER" -p"$DB_ADMIN_PASS" -e \
          "REVOKE ALL PRIVILEGES ON *.* FROM '$user'@'$host'; FLUSH PRIVILEGES;"
        EMAIL_BODY+="User $user is dropped from the database server: $db:$port\n"
      else
        EMAIL_BODY+="User $user does not exist on the database server: $db:$port\n"
      fi
    done
  done
done

# Send email with status
echo -e "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_RECIPIENT"

echo "Revocation complete."
