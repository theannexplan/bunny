#!/bin/bash

# Modify the following information
new_username="<<<Username Here>>>"
new_password="<<<Password Here>>>"
new_hostname="<<<New Hostname Here>>>"




# The Script






# Update and upgrade the system
yes | sudo pacman -Sy
yes | sudo pacman -Syu

# Install tools to help manage other servers
yes | sudo pacman -S ansible nmap

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
echo "User $new_username added to the sudoers file."

# Add new user to Docker group
sudo usermod -aG docker $new_username

# Set a new hostname for the server
echo "${new_hostname}" | sudo tee /etc/hostname > /dev/null
sudo hostnamectl set-hostname "${new_hostname}"
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t${new_hostname}/" /etc/hosts
echo -e "\nHostname set to: ${new_hostname}\n"

# Generate SSH Keys For The Master Node
ssh-keygen -t ed25519 -N "" -C "masternode" -f ~/.ssh/id_ed
echo -e "\nGenerated an SSH key."

# Add the SSH key to the new user's SSH session
sudo -u $new_username bash -c "eval \$(ssh-agent); ssh-add /home/$new_username/.ssh/id_ed"
echo -e "\nAdded SSH key to the new user's SSH session."

# Tell User Next Steps
file_path="~/.ssh/id_ed.pub"
pub_key="$(cat "$file_path")"

directions="
Now Follow These Steps:

    1 - Copy the ssh public key below:
    
    ${pub_key}

    2 - Paste the key into the 'slave_setup.sh' script
    3 - Host the slave script on an http server that slave servers can access.

    4 - Run the following command to execute the script on slave nodes, replacing necessary information:

    curl -sSL http://DOMAIN:PORT/folders/slave_setup.sh | bash

    Note: You can use a url shortener such as https://www.shorturl.at/ to reduce the number of key strokes you need to make

    5 - Once the script has finished executing on all servers, modify and run the inventory_gen.sh script on this server.

    6 - Copy the generated 'inventory' file to /etc/ansible/hosts

    7 - Run the following command to test the connection to all slave nodes:
    
    ansible all -m ping 

DONE!!!
"