#!/bin/bash

new_user=$NEW_USER

# Install yay from /opt/ directory as non-root user
install_yay() {
    # Set permissions for /opt/ directory
    sudo chmod 777 /opt/
    
    # Switch to the "arch" user
    sudo -u $new_user bash << EOF
# Clone yay repository
git clone https://aur.archlinux.org/yay.git /opt/yay

# Change directory to yay
cd /opt/yay

# Build and install yay
makepkg -si
EOF
}

# Harden SSH
harden_ssh() {
    # Backup the SSH daemon configuration file
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # disallow root SSH access
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    # Restart the SSH service
    sudo systemctl restart sshd

    echo -e "SSH hardened. 
    - Root login disabled.
    "
}

# Harden the firewall
harden_firewall() {
    # Reset the firewall to default settings
    sudo ufw --force reset

    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow specific ports
    sudo ufw allow 22/tcp           # SSH (Ansible)
    sudo ufw allow 80/tcp           # HTTP webserver
    sudo ufw allow 443/tcp          # HTTPS webserver
    sudo ufw allow 3478/tcp         # TURN over TCP (used by Coturn)
    sudo ufw allow 3478/udp         # TURN over UDP (used by Coturn)
    sudo ufw allow 5432/tcp         # PostgreSQL
    sudo ufw allow 5349/tcp         # TURN over TCP (used by Coturn)
    sudo ufw allow 5349/udp         # TURN over UDP (used by Coturn)
    sudo ufw allow 6443/tcp         # Kubernetes API Server
    sudo ufw allow 8448/tcp         # Matrix Federation API HTTPS webserver
    sudo ufw allow 49152:49172/udp  # TURN over UDP

    # Enable the firewall
    sudo ufw enable

    echo "Firewall hardened. Only specific ports allowed."
}

# Harden system packages, kernel, and microcode
harden_packages_kernel_microcode() {
    # Update the system packages
    sudo pacman -Syu

    # Install the latest kernel
    sudo pacman -S linux

    # Install the latest microcode updates for Intel processors
    sudo pacman -S intel-ucode

    # Install the latest microcode updates for AMD processors
    sudo pacman -S amd-ucode

    echo "Packages, Kernel, and Microcode updated successfully."
}

# Enable hardened_malloc for all applications
enable_hardened_malloc() {
    yay -S hardened_malloc
    if [ ! -f "/usr/lib/libhardened_malloc.so" ]; then
        echo "hardened_malloc library not found. Please ensure it is installed."
        return 1
    fi

    # Add the LD_PRELOAD line to the ld.so.preload file if not already present
    if ! grep -Fxq "/usr/lib/libhardened_malloc.so" /etc/ld.so.preload; then
        echo "/usr/lib/libhardened_malloc.so" | sudo tee -a /etc/ld.so.preload > /dev/null
        echo "hardened_malloc enabled for all applications."
    else
        echo "hardened_malloc is already enabled for all applications."
    fi
}

# Enforce a delay after a failed login attempt
enforce_login_delay() {
    # Check if the SSH configuration file exists
    if [ ! -f "/etc/ssh/sshd_config" ]; then
        echo "SSH configuration file not found."
        return 1
    fi

    # Add or update the 'LoginGraceTime' option in the SSH configuration file
    sudo sed -i 's/^#*\(LoginGraceTime\).*$/\1 1m/' /etc/ssh/sshd_config

    # Check if the system-login PAM configuration file exists
    if [ ! -f "/etc/pam.d/system-login" ]; then
        echo "system-login PAM configuration file not found."
        return 1
    fi

    # Add the 'auth optional pam_faildelay.so delay=600000' line to the system-login PAM configuration file
    sudo sed -i '/^auth[[:space:]]\+required[[:space:]]\+pam_faillock.so/a auth optional pam_faildelay.so delay=600000' /etc/pam.d/system-login

    # Restart the SSH service to apply the SSH configuration changes
    sudo systemctl restart sshd

    echo "Login delay of 1 minute enforced after a failed login attempt."
}

# Lock out a user for 30 minutes after 3 failed login attempts
lockout_user() {
    local username=$1

    # Check if the faillock command is available
    if ! command -v faillock >/dev/null; then
        echo "faillock command not found. Make sure the pam_faillock package is installed."
        return 1
    fi

    # Reset faillock count for the user
    faillock --user "$username" --reset >/dev/null

    # Set lockout parameters for the user
    faillock --user "$username" --unlock-time 1800 --failinterval 900 --deny 3 >/dev/null

    echo "User '$username' locked out for 30 minutes after 3 failed login attempts."
}

set_general_process_limits() {
    # Set limits for number of processes in /etc/security/limits.conf
    echo "* soft nproc 100" | sudo tee -a /etc/security/limits.conf
    echo "* hard nproc 200" | sudo tee -a /etc/security/limits.conf

    echo "Limits for number of processes have been set."
}

set_specific_process_limits() {
    local username=$1
    local limit_number=$2

    echo "$username soft nproc $limit_number" | sudo tee -a /etc/security/limits.conf
    echo "$username hard nproc $limit_number" | sudo tee -a /etc/security/limits.conf

    echo "Limits for number of processes have been set for user $username."
}

# Function to set up AppArmor
setup_apparmor() {

    #unfinished


    # Install AppArmor
    sudo pacman -Sy apparmor

    # Enable AppArmor kernel module
    sudo systemctl enable apparmor.service
    sudo systemctl start apparmor.service

    # Verify AppArmor status
    sudo apparmor_status

    # Configure AppArmor profiles
    sudo aa-enforce /etc/apparmor.d/*  # Enforce all AppArmor profiles
    # Alternatively, you can selectively enforce specific profiles as needed

    # Update grub configuration to enable AppArmor
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' /etc/default/grub
    sudo update-grub

    # Reboot the system to apply changes
    echo "AppArmor has been set up. Reboot the system for changes to take effect."
}

# Install the linux-hardened kernel package
# Note: some apps might not work after installing this package, this is why it's installation is isolated
install_linux_hardened() {
    pacman -S linux-hardened
}

# Restrict access to kernel pointers
restrict_kernel_pointers() {
    # Create a sysctl configuration file
    sudo bash -c 'echo "kernel.kptr_restrict = 1" > /etc/sysctl.d/51-kptr-restrict.conf'

    # Apply the sysctl configuration
    sudo sysctl --system

    echo "Access to kernel pointers in the proc filesystem has been restricted."
}

install_kernel_runtime_guard() {
    yay -S lkrg-dkms
}

disallow_usb_devices() {

    # unfinished


    sudo pacman -Syu usbguard

    usbguard generate-policy > /etc/usbguard/rules.conf
    systemctl enable usbguard

    echo "usbGuard has been installed and all USB devices are disallowed."
}


setup_arch_audit() {

    # Install the package
    sudo pacman -Syu arch-audit

    # Create the log directory if it doesn't exist
    log_dir="/var/log/arch_audit_logs"
    sudo mkdir -p "$log_dir"

    # Set up the cron job to run arch-audit on the first of every month
    cron_command="/usr/bin/arch-audit --refresh && /usr/bin/arch-audit > $log_dir/$(date +'%Y-%m-%d-%H-%M').log"
    cron_job="@monthly $cron_command"

    # Add the cron job
    (crontab -l ; echo "$cron_job") | crontab -

}

schedule_system_updates() {
    # Set up the cron job to update Pacman repositories and upgrade packages
    cron_command="sudo pacman -Syu --noconfirm"
    cron_job="@monthly $cron_command"

    # Add the cron job
    (crontab -l ; echo "$cron_job") | crontab -
    
    # Add the cron job
    (crontab -l ; echo "$cron_job") | crontab -

    echo "System updates have been scheduled to run monthly"
}

main() {
    # Comment out functions you don't want to run
    install_yay
    harden_ssh
    harden_firewall
    harden_packages_kernel_microcode
    enable_hardened_malloc
    enforce_login_delay

    lockout_user "root"
    lockout_user "$new_user"

    set_general_process_limits

    set_specific_process_limits "root" 400
    set_specific_process_limits "$new_user" 200

    #setup_apparmor
    install_linux_hardened
    restrict_kernel_pointers
    install_kernel_runtime_guard
    #disallow_usb_devices
    setup_arch_audit
    schedule_system_updates
}

main