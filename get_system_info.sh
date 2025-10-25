#!/bin/bash

REMOTE_HOST_SUBNET="192.168.20.11/32"
REMOTE_SSH_PORT=22
REMOTE_SSH_USER="ops"

# Function to gather system information from a remote host
get_system_info() {
  local host=$1
  local ssh_user=$2
  local ssh_port=$3

  ssh -o ConnectTimeout=5 -p "$ssh_port" "$ssh_user@$host" "
    hostname
    lsb_release -d | grep -i 'description' || cat /etc/*release | grep -i 'PRETTY_NAME'
    uname -r
    grep -c ^processor /proc/cpuinfo
    free -m | awk '/Mem:/ {print \$2}'
    df -h --total | grep 'total' | awk '{print \$2}'
  " 2>/dev/null
}

# Scan the subnet for hosts with open SSH ports
hosts=$(nmap -p "$REMOTE_SSH_PORT" --open -oG - "$REMOTE_HOST_SUBNET" | awk '/Up$/{print $2}')

# Collect and display information for each host
for host in $hosts; do
  echo "===================================================================="
  echo "Hostname:"
  system_info=$(get_system_info "$host" "$REMOTE_SSH_USER" "$REMOTE_SSH_PORT")
  if [ -n "$system_info" ]; then
    hostname=$(echo "$system_info" | sed -n '1p')
    os_type=$(echo "$system_info" | sed -n '2p' | cut -d: -f2 | xargs)
    kernel=$(echo "$system_info" | sed -n '3p')
    core=$(echo "$system_info" | sed -n '4p')
    memory=$(echo "$system_info" | sed -n '5p')
    total_disk=$(echo "$system_info" | sed -n '6p')
    echo "$hostname"
    echo "OS Type: $os_type"
    echo "IP: $host"
    echo "Kernel: $kernel"
    echo "Core: $core"
    echo "Memory: ${memory}MB"
    echo "Total Disk: $total_disk"
  else
    echo "Unable to connect or gather information"
  fi
  echo "===================================================================="
done

