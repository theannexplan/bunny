#!/bin/bash

# Update and upgrade the system
yes | sudo pacman -Sy
yes | sudo pacman -Syu

# Install tools to help manage other servers
yes | sudo pacman -S ansible nmap

# Add a new sudo user
new_username="<<<username>>>"
new_password="<<<password>>>"

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

# Add users with a folder in /home to the Docker group
DOCKER_GROUP="docker"
while IFS=: read -r username _ uid gid _ home _; do
    if [[ -d "$home" && $home != "/nonexistent" ]]; then
        if ! id -nG "$username" | grep -qw "$DOCKER_GROUP"; then
            # Add the user to the Docker group
            sudo usermod -aG $DOCKER_GROUP $username
            echo "User '$username' has been added to the '$DOCKER_GROUP' group."
        else
            echo "User '$username' is already a member of the '$DOCKER_GROUP' group."
        fi
    fi
done < <(grep /home/ /etc/passwd)

# Generate SSH Keys For The Master Node
ssh-keygen -t ed25519 -N "" -C "master@matrix.dev00ps.com" -f ~/.ssh/id_ed

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

    5 - Once the script has finished executing, you can delete the script from the http server.

DONE!!!
"