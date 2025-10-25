#!/bin/bash

# Set your password
PASSWORD="GEz?I0MU;AnTD=8%"

# Set the target user
TARGET_USER="jamal"

# Prompt the user for the subnet (e.g., 192.168.20.0/24)
read -p "Enter the target subnet (e.g., 192.168.20.0/24): " SUBNET

while true; do
    # Prompt the user for the last octet of the IP address
    read -p "Enter the last octet of the target host IP address (or 'exit' to end): " LAST_OCTET

    # Prompt the user for the SSH port (default is 22)
    read -p "Enter the SSH port (default is 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}

    # Check if the user wants to exit
    if [ "$LAST_OCTET" == "exit" ]; then
        echo "Exiting the script."
        exit 0
    fi

    # Construct the TARGET_HOST using the subnet and the last octet
    TARGET_HOST="${SUBNET%.*}.$LAST_OCTET"

    # Use sshpass to copy the SSH key without entering a password
    if sshpass -p "$PASSWORD" ssh-copy-id -p "$SSH_PORT" "$TARGET_USER@$TARGET_HOST"; then
        echo "SSH key installed successfully for $TARGET_HOST."
    else
        echo "Error: Unable to install SSH key for $TARGET_HOST."
    fi

    # Prompt the user for another iteration
    read -p "Do you want to install SSH key for another host? (y/n): " answer
    # Check if the user wants to exit the loop
    if [ "$answer" != "y" ]; then
        echo "Exiting the script."
        exit 0
    fi
done

