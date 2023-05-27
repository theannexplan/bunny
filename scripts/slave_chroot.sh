#!/bin/bash

# Modify the following information
new_username="<<<Username Here>>>"
new_password="<<<Password Here>>>"
base_hostname="<<<Base Hostname Here>>>"




# The Script





# Update and upgrade the system
y | sudo pacman -Sy
y | sudo pacman -Syu

if id -u "$new_username" >/dev/null 2>&1; then
    echo "User $new_username already exists."
    echo "Changing password..."
    echo "$new_username:$new_password" | sudo chpasswd
else
    sudo useradd -m $new_username
    echo "$new_username:$new_password" | sudo chpasswd
    echo "User $new_username created."
fi
sudo sh -c "echo '$new_username ALL=(ALL) ALL' >> /etc/sudoers"
echo -e "\nUser $new_username added to the sudoers file.\n"

# Add new user to Docker group
sudo usermod -aG docker $new_username

# Set a new hostname for the server
counter=1
hostname="${base_hostname}-${counter}"
while [[ -n "$(ping -c 1 -w 1 ${hostname} 2>/dev/null)" ]]; do
  ((counter++))
  hostname="${base_hostname}-${counter}"
done
echo "${hostname}" | sudo tee /etc/hostname > /dev/null
sudo hostnamectl set-hostname "${hostname}"
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t${hostname}/" /etc/hosts
echo -e "\nHostname set to: ${hostname}\n"

# Generate SSH keys for the newly created user
sudo -u $new_username ssh-keygen -t ed25519 -N "" -C "slavenode" -f "/home/$new_username/.ssh/id_ed"
echo -e "\nGenerated an SSH key.\n"

# Copy public ssh key from the Master Node and authorize it for the new user
echo -e "
<<<PASTE PUBLIC KEY HERE>>>
" | sudo -u $new_username tee -a "/home/$new_username/.ssh/authorized_keys" >/dev/null
sudo chmod 600 "/home/$new_username/.ssh/authorized_keys"
echo -e "\nCopied master node SSH public key.\n"

# Add the SSH key to the new user's SSH session
sudo -u $new_username bash -c "eval \$(ssh-agent); ssh-add /home/$new_username/.ssh/id_ed"
echo -e "\nAdded SSH key to the new user's SSH session.\n"

echo -e "\nDONE!!!\n"
