#!/bin/bash

# Define the threshold size in gigabytes (5GB)
threshold_size=15

# Define an array of users and their corresponding Mail addresses
users=("ops" "apsiscrm" "apsiserp" "apsisecom" "apsisint" "apsisin")
email_addresses=("jamal.hossain@apsissolutions.com" "rokib.hasnat@apsissolutions.com" "rashed.islam@apsissolutions.com" "musabbir.mamun@apsissolutions.com" "foysal.ahmed@apsissolutions.com" "aatif.sayyed@apsissolutions.com")

# Email configuration
subject="Large Home Directories Report"

# Additional message
note="Note: Please reduce the size of your directory to free up space.\n\nThis is an automated message and needs immediate attention. Please do not reply."
ip=$(hostname -I | awk '{print $1}')
# Initialize the message body
message="Large home directories exceeding ${threshold_size}GB:\n"

# Loop through the array of users
for ((i=0; i<${#users[@]}; i++)); do
  user="${users[i]}"
  email="${email_addresses[i]}"
  
  # Get the user's home directory
  home_dir=$(eval echo "~$user")
  
  # Check if the user's home directory exists
  if [ -d "$home_dir" ]; then
    # Calculate the size of the user's home directory in gigabytes and round to the nearest integer
    size_gb=$(du -s "$home_dir" | awk '{printf "%.0f", $1/1024/1024}')
    
    # Check if the size exceeds the threshold using a simple comparison
    if ((size_gb > threshold_size)); then
      # Print the name of the user and the size of their home directory
      message+="Server: $ip, User: $user, Home Directory: $home_dir, Size: ${size_gb}GB\n"
      
      # Send an email to the corresponding Gmail address with the additional message
      echo -e "$message\n$note" | mail -s "$subject" "$email"
    fi
  else
    # User's home directory not found
    echo "User $user not found on the system."
  fi

  # Reset the message body for the next user
  message=""
done
