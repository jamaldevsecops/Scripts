#!/bin/bash
threshold_size=15  #in GB
search_paths=(
  "/var/www/html"
  "/home"
  # Add more paths as needed
)

# Email configuration
recipient="infra@apsissolutions.com"
subject="Large Directories Report"

# Get the hostname
hostname=$(hostname)

# Initialize the message body
message="The information was exported from $hostname\nLarge directories exceeding ${threshold_size}GB:\n"
#Additional message
note="Note: This is an automated message and needs immediate attention. Please do not reply."

# Loop through the array of search paths
for path in "${search_paths[@]}"; do
  # Find directories in each path and check their size
  while IFS= read -r dir; do
    # Calculate the size of the directory in gigabytes
    size_gb=$(du -s "$dir" | awk '{print $1/1024/1024}')
    
    # Check if the size exceeds the threshold using a simple comparison
    if (( $(echo "$size_gb > $threshold_size" | bc) )); then
      # Print the name of the directory and its size
      message+="Directory: $dir, Size: $size_gb GB\n"
    fi
  done < <(find "$path" -type d)
done

# Print the message to the console
echo -e "$message"

# Send the email
echo -e "$message\n$note" | mail -s "$subject" "$recipient"
