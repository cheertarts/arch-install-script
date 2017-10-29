#!/bin/bash

# Change the time zone
# ATTENTION: Change this if you want a different timezone
echo ">>> Changing the time zone.."
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

# Enable the ntp daemon on boot
# ATTENTION: Comment this out if you do not want the ntp daemon
echo ">>> Enabling the ntp daemon on boot.."
echo y | pacman -Sy ntp
systemctl enable ntpd

# Set the locale
# ATTENTION: Change this if you do not want an en_US.UTF-8 locale
echo ">>> Setting the locale.."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# Set the hostname
# ATTENTION: CHANGE THIS!!!
echo ">>> Setting the hostname.."
echo "palace" >> /etc/hostname
echo "127.0.1.1 palace.localdomain palace" >> /etc/hosts

# Network Configuration
# ATTENTION: Change this if you have wireless
echo ">>> Configuring the network.."
systemctl enable dhcpcd

# Type in the root password
clear
echo ">>> Type in the root password you want to use:"
passwd

# Install the grub boot loader
# ATTENTION: CHANGE THIS!!! (maybe?)
echo ">>> Installing grub.."
echo y | pacman -Sy grub
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Install the intel microcode
# ATTENTION: Uncomment this if you have an intel cpu
#echo ">>> Installing the intel microcode.."
#echo y | pacman -Sy intel-ucode

# Exit chroot
echo ">>> Exiting chroot.."
