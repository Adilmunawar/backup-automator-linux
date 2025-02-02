#!/bin/bash

echo "Starting backup script..."

# Import variables
source config.sh

# Create necessary directories and set permissions
create_dir() {
    mkdir -p "$1"
    chown -R "$system_user":"$system_user" "$1"
}

create_dir "$shared_dir_mount_target"
create_dir "$destination_dir"
create_dir "$log_dir"

# Remove old log files
find "$log_dir" -type f -name "rsync_log_*" -mtime +30 -exec rm {} \;

# Timestamp for the log file
timestamp=$(date +"%Y-%m-%d-%H-%M")
log_file="$log_dir/rsync_log_$timestamp.txt"

echo "Variables created."

# Function to display rsync messages
display_rsync_messages() {
    while IFS= read -r line; do
        echo "$line"   # Print the rsync message to the terminal
        echo "$line" >> "$log_file"  # Log the message to the log file
    done
}

# Function to mount directories
mount_dir() {
    if [ -d "$1" ]; then
        echo "$2 directory already mounted."
    else
        mount -t cifs "$1" "$2" -o username="$samba_user",password="$samba_password",uid=$(id -u),gid=$(id -g)
        if [ $? -eq 0 ]; then
            echo "$2 mount successful."
        else
            echo "$2 mounting failed. Check your path."
            exit 1
        fi
    fi
}

# Mount source and destination directories
mount_dir "$shared_dir_source" "$shared_dir_mount_target"
mount_dir "$destination_mount_device_location" "$destination_dir"

# Rsync command
echo "Starting rsync command..."
rsync -av --progress --info=progress1 "$shared_dir_mount_target" "$destination_dir" 2>&1 | tee >(display_rsync_messages)

# Set log file ownership
chown "$system_user":"$system_user" "$log_file"

# Check the rsync exit status
if [ $? -eq 0 ]; then
    echo "Rsync completed successfully. Log saved to: $log_file"
else
    echo "Rsync encountered an error. Check the log file for details: $log_file"
fi

# Unmount directories
echo "Unmounting shared directory..."
umount "$shared_dir_mount_target"
echo "Unmounting destination directory..."
umount "$destination_dir"

echo "Backup script completed."
