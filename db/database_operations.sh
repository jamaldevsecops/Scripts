#!/bin/bash

# Database credentials
read -p "Enter the Database's IP:" DB_HOST
#DB_USER="infra"
DB_USER="ops"
DB_PASS="F&D%3X]>k6IdT<jA"
#DB_PASS="K*4sV5LjDUpWPXo?XcrB*WE#"
read -p "Enter the Database's Port:" DB_PORT
#DB_PORT="3306"



second_level_password="Dhaka@123" 
while :
do
    clear
    echo "MySQL Database Operations Menu:"
    echo "1. Create a New User"
    echo "2. Change a User's Password"
    echo "3. Change a User's Host"
    echo "4. Grant User Privilege(s)"
    echo "5. Show User Privilege(s)"
    echo "6. Revoke User Privilege(s)"
    echo "7. Delete a User"
    echo "8. Create a Database"
    echo "9. Show Existing Databases"
    echo "10. Show Existing Users"
    echo "11. Create Bulk User"
    echo "12. Show Database Size"
    echo "13. Show Table Size" 
    echo "14. Show Versions"
    echo "15. Get the Terminal"
    echo "00. Exit"

    read -p "Enter your choice 1/2/3/...: " choice

    case $choice in
        1)
            # Create a New Database User
            read -p "Enter the new username: " username
            read -p "Enter the user's host: " user_host
            read -p "Enter the user's password: " user_password
            existing_user=$(mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user FROM mysql.user WHERE user='$username' AND host='$user_host';" --skip-column-names)
            if [ -z "$existing_user" ]; then
                read -p "Confirm user creation (y/n): " confirm
                if [ "$confirm" == "y" ]; then
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "CREATE USER '$username'@'$user_host' IDENTIFIED BY '$user_password';"
                    echo "User created successfully."
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
                fi
            else
                echo "The user already exists on the database."
            fi
            ;;

        2)
            # Change a User's Password
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"

            read -p "Enter the username whose password you want to change: " username
            read -p "Enter the user's host: " user_host

            read -p "Enter the new password: " new_password
            read -p "Confirm password change (y/n): " confirm

            if [ "$confirm" == "y" ]; then
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "ALTER USER '$username'@'$user_host' IDENTIFIED BY '$new_password';"
                echo "Password changed successfully."
            fi
            ;;

        3)
            # Change a User's Host
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"

            read -p "Enter the username whose host you want to change: " username
            existing_user=$(mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user WHERE user='$username';" --skip-column-names)

            if [ -n "$existing_user" ]; then
		read -p "Enter the user's host: " user_host
                read -p "Enter the new host: " new_host
                read -p "Confirm host change (y/n): " confirm
                if [ "$confirm" == "y" ]; then
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "RENAME USER '$username'@'$user_host' TO '$username'@'$new_host';"
                    echo "Host changed successfully."
                    echo "Updated user list:"
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
                fi
            else
                echo "User $username not found."
            fi
            ;;

        4)
            # Grant User Privileges
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"

            read -p "Enter the username for whom you want to grant privileges: " username
            read -p "Enter the user's host: " user_host
            
            echo "The selected user's current privileges:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW GRANTS FOR '$username'@'$user_host';"
            echo "e.g., for backup user privileges: SELECT, SHOW VIEW, RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT, CREATE TABLESPACE"
            read -p "Enter the privileges to grant (e.g., SELECT, INSERT, UPDATE): " privileges

            echo "List of existing databases:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"
            read -p "Enter the database name to grant privileges on: " db_name
            read -p "Confirm privilege grant (y/n): " confirm
            if [ "$confirm" == "y" ]; then
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "GRANT $privileges ON $db_name.* TO '$username'@'$user_host';"
                echo "Privileges granted successfully."
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW GRANTS FOR '$username'@'$user_host';"
            fi
            ;;

        5)
            # Grant User Privileges
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"

            read -p "Enter the username for whom you want to grant privileges: " username
            read -p "Enter the user's host: " user_host
            
            echo "The selected user's current privileges:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW GRANTS FOR '$username'@'$user_host';"
            ;;

        6)
            # Revoke User Privileges
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
            read -p "Enter the username for whom you want to revoke privileges: " username
            read -p "Enter the user's host: " user_host
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW GRANTS FOR '$username'@'$user_host';"
            read -p "Enter the privileges to revoke (e.g., SELECT, INSERT, UPDATE): " privileges
            read -p "Enter the database name to revoke privileges from: " db_name
            read -p "Enter your second-level confirmation password: " second_level_confirm
            if [ "$second_level_confirm" == "$second_level_password" ]; then
                read -p "Confirm privilege revocation (y/n): " confirm
                if [ "$confirm" == "y" ]; then
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "REVOKE $privileges ON $db_name.* FROM '$username'@'$user_host';"
                    echo "Privileges revoked successfully."
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW GRANTS FOR '$username'@'$user_host';"
                fi
            else
                echo "Second-level confirmation password is incorrect. Privilege revocation canceled."
            fi
            ;;

        7)
            # Delete a User
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
            read -p "Enter the username to delete: " username
            read -p "Enter the user's host: " user_host
            read -p "Enter your second-level confirmation password: " second_level_confirm
            if [ "$second_level_confirm" == "$second_level_password" ]; then
                read -p "Confirm user deletion (y/n): " confirm
                if [ "$confirm" == "y" ]; then
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "DROP USER '$username'@'$user_host';"
                    echo "User deleted successfully."
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
                fi
            else
                echo "Second-level confirmation password is incorrect. User deletion canceled."
            fi
            ;;

        8)
            # Create a Database
            echo "List of existing databases:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"

            read -p "Enter the new database name: " db_name
            read -p "Confirm database creation (y/n): " confirm
            if [ "$confirm" == "y" ]; then
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "CREATE DATABASE $db_name;"
                echo "Database created successfully."
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"
            fi
            ;;
        9)
            # Show Existing Databases
            echo "List of existing databases:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"
            ;;
        10)
            # Show Existing Users
            echo "List of existing users:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT user, host FROM mysql.user;"
            ;;


        11)            
            read -p "Provide the Path of the Bulk Users: " BULK_USER_FILE
            generate_random_password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

                while IFS= read -r line; do
                    username="$line"
                    user_password=$(generate_random_password)

                    # Create the user with a random password
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "CREATE USER '$username'@'%' IDENTIFIED BY '$user_password';"

                    # Grant privileges to specific databases (adjust the database names and privileges accordingly)
                    echo "List of existing databases:"
                    mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"

                    read -p "Enter the database name on which the user will be granted: " db_name
                    read -p "Confirm database creation (y/n): " confirm
                        if [ "$confirm" == "y" ]; then
                            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$username'@'%';"
                            echo "User created successfully."
                        fi

                    # Display user credentials
                    echo "User: $username"
                    echo "Password: $user_password"
                    echo "-------------------------------"

                done < "$BULK_USER_FILE"
            ;;
        12)
            while [ "$confirm" != "exit" ]; do
            read -p "Do you want to show all or single database size? (a/s), or 'exit' to quit: " confirm
            if [ "$confirm" == "a" ]; then
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 3) AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;"
        
            elif [ "$confirm" == "s" ];then
                echo "List of existing databases:"
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"
                read -p "Enter the name of the database: " db_name
                mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 3) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = '$db_name';"
            
            elif [ "$confirm" == "exit" ]; then
                echo "Exiting the script."

            else
                echo "Invalid choice"
            fi
            done
            ;;

        13)
            echo "List of existing databases:"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "SHOW DATABASES;"
            read -p "Enter the name of the database: " db_name
            query="SELECT table_name AS 'Table', round(((data_length + index_length) / 1024 / 1024), 2) 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '$db_name';"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "$query"
            ;;
        
        14)
            echo "Showing Versions: "
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS -e "show variables like '%version%';"
            ;;


        15)
            echo "Entering into the SQL Terminal"
            mysql -h $DB_HOST -u $DB_USER -P $DB_PORT -p$DB_PASS
            ;;

        00)
            # Exit
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select a valid option."
            ;;
    esac

    read -p "Press Enter to continue..."
done
