#!/bin/bash

# To be run on the control node

# Replace the following with your information
ansible_user="arch" # The non-root user that you setup on your worker nodes (you don't want to use root, only sudo)
gateway_ip="10.0.0.1" # Usually the router
control_node_ip="10.0.0.2" # The current server IP
network_range="10.0.0.0/24"

# If unsure of your network range, run the following:
# ip -o -f inet addr show | awk '/scope global/ {print $4}'

# Set the file to write to
file2write="./inventory.ini"

# Run nmap scan and extract active IP addresses
active_ips=$(nmap -sn $network_range | grep "Nmap scan report" | awk '{print $5}')

# Remove gateway and control node IPs from the list
active_ips=($(echo "${active_ips[@]}" | grep -vwE "$gateway_ip|$control_node_ip"))

# Define control node hostname
control_node_hostname="kube_master"

# Create inventory.ini file
echo "[kubernetes_master]" > $file2write
echo "${control_node_hostname} ansible_host=${control_node_ip}" >> $file2write
echo "" >> $file2write
echo "[kubernetes_workers]" >> $file2write

# Assign remaining IPs to worker nodes
for ((i=0; i<${#active_ips[@]}; i++)); do
  worker_node_ip=${active_ips[i]}
  worker_node_hostname="kube_worker$((i+1))"
  echo "${worker_node_hostname} ansible_host=${worker_node_ip} ansible_user=${ansible_user}" >> $file2write
done