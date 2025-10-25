#!/bin/bash

# Set your password
PASSWORD="Nopass@2357"

# Set the target user
TARGET_USER="ops"

while true; do
    # Prompt the user for the target host (IP address)
    read -p "Enter the target host IP address (or 'exit' to end): " TARGET_HOST

    # Check if the user wants to exit
    if [ "$TARGET_HOST" == "exit" ]; then
        echo "Exiting the script."
        exit 0
    fi    


    # Use sshpass to copy the SSH key without entering a password
    if sshpass -p "$PASSWORD" ssh-copy-id "$TARGET_USER@$TARGET_HOST"; then
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

