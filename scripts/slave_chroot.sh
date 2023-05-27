#!/bin/bash

# Update and upgrade the system
yes | sudo pacman -Sy
yes | sudo pacman -Syu

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

# Generate SSH keys for the newly created user
sudo -u $new_username ssh-keygen -t ed25519 -N "" -C "slave@matrix.dev00ps.com" -f "/home/$new_username/.ssh/id_ed"
echo -e "\nGenerated an SSH key."

# Copy public ssh key from the Master Node and authorize it for the new user
echo -e "
<<<PASTE PUBLIC KEY HERE>>>
" | sudo -u $new_username tee -a "/home/$new_username/.ssh/authorized_keys" >/dev/null
sudo chmod 600 "/home/$new_username/.ssh/authorized_keys"
echo -e "\nCopied master node SSH public key."

# Add the SSH key to the new user's SSH session
sudo -u $new_username bash -c "eval \$(ssh-agent); ssh-add /home/$new_username/.ssh/id_ed"
echo -e "\nAdded SSH key to the new user's SSH session."

echo -e "\nDONE!!!"
