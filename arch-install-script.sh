#!/bin/bash

# ATTENTION: This script must be run in the same directory as "install-script-part-2.sh"

# This is the first install script. The second install script,
# labeled "arch-install-script-part-2.sh", is ran by this
# install script. We recommend checking both and changing anything
# that you do not like. :)

# Internet Warning
echo ">>> Warning: This script will fail if you are not connected to the internet!"

# Update the system clock
echo ">>> Updating the system clock.."
timedatectl set-ntp true

# Partition the disks (add something if you like)
#echo ">>> Partitioning the disks.."

# Format the partitions
# ATTENTION: CHANGE THIS!!!
echo ">>> Formatting the partitions.."
mkfs.xfs -f /dev/sda4

# Mount the partitions
# ATTENTION: CHANGE THIS!!!
echo ">>> Mounting the partitions.."
mount /dev/sda4 /mnt

# Create a swapfile
# ATTENTION: Change this if you do not want a 10G swapfile
echo ">>> Creating swapfile.."
dd if=/dev/zero of=/mnt/swapfile bs=1G count=10
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile

# Select mirrors
echo ">>> Selecting mirrors with reflector.."
echo y | pacman -Sy reflector
reflector --verbose --protocol https --sort rate --save /etc/pacman.d/mirrorlist
echo y | pacman -Rns reflector

# Install a base system
# ATTENTION: Change this if you want base-devel packages
echo ">>> Installing a base system.."
pacstrap /mnt base

# Generate an fstab file
# ATTENTION: Change this if you do not want a swapfile
echo ">>> Generating an fstab file.."
genfstab -U /mnt >> /mnt/etc/fstab
echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
cat /mnt/etc/fstab

# Chroot into the new system
echo ">>> Chrooting into the new system.."
cp arch-install-script-part-2.sh /mnt/
arch-chroot /mnt /arch-install-script-part-2.sh
rm /mnt/arch-install-script-part-2.sh

# Unmount partitions
echo ">>> Unmounting partitions.."
umount -R /mnt

# Done
echo ">>> Done!"
