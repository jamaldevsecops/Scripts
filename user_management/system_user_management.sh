#!/bin/bash

read -p "On which server do you want to create an account: " SSH_HOST
SSH_USER="ops"
read -p "Privide the password: " SSH_PASSWORD
SSH_PORT="22"

get_distro() {
    if [ -f /etc/os-release ]; then
        # Try to get distribution name from /etc/os-release
        distro=$(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "awk -F= '/^NAME/{print \$2}' /etc/os-release | tr -d '\"'")
        echo "$distro"
    elif [ -f /etc/redhat-release ]; then
        # CentOS
        echo "CentOS"
    else
        # Unknown distribution
        echo "Unknown"
    fi
}

user_exists() {
    local username=$1
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "id -u $username > /dev/null 2>&1"
}

group_exists() {
    local groupname=$1
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "getent group $groupname > /dev/null 2>&1"
}

display_users_starting_from_1000() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "awk -F: '\$3 >= 1000 {print \$1}' /etc/passwd"
}

display_groups_starting_from_1000() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "getent group | awk -F: '\$3 >= 1000 {print \$1}'"
}

add_to_sudoers() {
    local name=$1
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "echo '$name ALL=(ALL:ALL) ALL' | sudo tee -a /etc/sudoers"
}

remote_terminal() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST
}

create_user() {
    read -p "Enter username: " username
    if user_exists $username; then
        echo "User $username already exists. Exiting operation."
    else
        case $(get_distro) in
            "Ubuntu")
                sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "sudo useradd $username"
                ;;
            "CentOS")
                sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "sudo adduser $username"
                ;;
            *)
                echo "Unsupported distribution."
                ;;
        esac
        echo "User $username created successfully."

        read -p "Do you want to add $username to sudoers file? (y/n): " add_to_sudoers_option
        if [ "$add_to_sudoers_option" == "y" ]; then
            add_to_sudoers $username
            echo "$username added to sudoers file."
        fi
    fi
}

create_group() {
    read -p "Enter group name: " groupname
    if group_exists $groupname; then
        echo "Group $groupname already exists. Exiting operation."
    else
        case $(get_distro) in
            "Ubuntu")
                sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "sudo groupadd $groupname"
                ;;
            "CentOS")
                sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "sudo groupadd $groupname"
                ;;
            *)
                echo "Unsupported distribution."
                ;;
        esac
        echo "Group $groupname created successfully."

        read -p "Do you want to add $groupname to sudoers file? (y/n): " add_to_sudoers_option
        if [ "$add_to_sudoers_option" == "y" ]; then
            add_to_sudoers %$groupname
            echo "$groupname added to sudoers file."
        fi
    fi
}

assign_user_to_group() {
    read -p "Enter username: " username
    read -p "Enter group name: " groupname
    if user_exists $username && group_exists $groupname; then
        echo "Existing users with IDs starting from 1000:"
        display_users_starting_from_1000
        echo "Existing groups with IDs starting from 1000:"
        display_groups_starting_from_1000
        sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$SSH_HOST "sudo usermod -aG $groupname $username"
        echo "User $username assigned to group $groupname successfully."
    else
        echo "User or group does not exist. Exiting operation."
    fi
}

while true; do
    echo "Select an option:"
    echo "1. Create a user"
    echo "2. Create a group"
    echo "3. Assign a user to a group"
    echo "4. Open a remote terminal"
    echo "5. Exit"

    read -p "Enter your choice (1, 2, 3, 4, or 5 to exit): " choice

    case $choice in
        1)
            create_user
            ;;
        2)
            create_group
            ;;
        3)
            assign_user_to_group
            ;;
        4)
            remote_terminal
            ;;
        5)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1, 2,...or 5 to exit."
            ;;
    esac
done
