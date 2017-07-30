#!/bin/bash

# Color Definitions (Change if you want)
COLOR='\033[1;34m' # default is light blue
NO_COLOR='\033[0m'

# Loading Config
source arch-install-script.conf

# Updating the System Clock
if [ "$do_update_system_clock" == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Updating the system clock.."
	timedatectl set-ntp true
	timedatectl status
	if [ "$ask_if_the_system_clock_is_okay_before_proceeding" == true ]; then
		echo -e "${COLOR}$0:${NO_COLOR} Is this okay? (y/n):"
		select yn in "y" "n"; do
			case $yn in
				y ) break;;
				n ) exit;;
			esac
		done
	fi
fi

# Partitioning and Formatting
if [ "$do_partition_and_format" == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Partitioning and formatting drives.."
	partition_and_format_drives
fi

# Mounting
if [ "$do_mount" == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Mounting partitions.."
	mount_partitions
fi

# Setting Mirrors
if [ "$use_reflector" == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Setting mirrors.."
	pacman -Sy
	echo y | pacman -S reflector
	$reflector_command --verbose
fi

# Installation
echo -e "${COLOR}$0:${NO_COLOR} Installing Arch Linux.."
if [ "$install_base_devel" == true ]; then
	echo y | pacstrap $mount_drive base base-devel
else
	echo y | pacstrap $mount_drive base
fi

# Fstab
echo -e "${COLOR}$0:${NO_COLOR} Generating fstab.."
if [ "$use_uuid" == true ]; then
	genfstab -U $mount_drive >> $mount_drive/etc/fstab
else
	genfstab -L $mount_drive >> $mount_drive/etc/fstab
fi

echo -e "${COLOR}$0:${NO_COLOR} Output:"
cat $mount_drive/etc/fstab

if [ "$ask_to_edit_before_proceeding" == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Edit before proceeding? (y/n):"
	select yn in "y" "n"; do
		case $yn in
			y ) break;;
			n ) $fstab_editor $mount_drive/etc/fstab;;
		esac
	done
fi

# Copy Internet Information
echo -e "${COLOR}$0:${NO_COLOR} Copying over internet information.."
if [ -d "/etc/NetworkManager" ]; then
	cp -rf /etc/NetworkManager $mount_drive/etc/NetworkManager
fi

if [ -d "/etc/netctl" ]; then
	cp -rf /etc/netctl $mount_drive/etc/netctl
fi

enable_dhcpcd=false
enable_netctl=false
enable_NetworkManager=false

if [ $(systemctl is-active dhcpcd.service) == "active" ]; then
	enable_dhcpcd=true
fi

if [ $(systemctl is-active netctl.service) == "active" ]; then
	enable_netctl=true
fi

if [ $(systemctl is-active NetworkManager.service) == "active" ]; then
	enable_NetworkManager=true
fi

# Create Chroot Script
touch $mount_drive/root/chroot-script.sh
echo "#!/bin/bash

# Time zone
echo -e '${COLOR}$0:${NO_COLOR} Setting time zone..'
ln -sf /usr/share/zoneinfo/$timezone_info /etc/localtime
hwclock --systohc
if [ '$enable_ntpd_on_startup' == true ]; then
	echo y | pacman -S ntp
	systemctl enable ntpd.service
fi

# Locale
echo -e '${COLOR}$0:${NO_COLOR} Setting up localizations..'
echo $needed_localizations >> /etc/locale.gen
locale-gen
echo 'LANG=$default_language' >> /etc/locale.conf

# Keyboard Layout
if [ '$non_us_keyboard_layout' == true ]; then
	echo -e '${COLOR}$0:${NO_COLOR} Setting keyboard layout..'
	echo 'KEYMAP=$used_layout' >> /etc/vconsole.conf
fi

# Hostname
echo -e '${COLOR}$0:${NO_COLOR} Setting hostname..'
echo $preferred_hostname >> /etc/hostname
echo '127.0.1.1	$preferred_hostname.localdomain	$preferred_hostname' >> /etc/hosts

# Internet
echo -e '${COLOR}$0:${NO_COLOR} Enabling internet..'

if [ '$use_reflector' == true ]; then
	echo y | pacman -S reflector
fi

if [ '$enable_dhcpcd' == true ]; then
	systemctl enable dhcpcd.service
elif [ $enable_netctl == true ]; then
	systemctl enable netctl.service
elif [ $enable_NetworkManager == true ]; then
	systemctl enable NetworkManager.service
else
	systemctl enable dhcpcd.service
fi

# Setting Root Password
echo -e '${COLOR}$0:${NO_COLOR} Setting root password..'
echo -e \"$preferred_root_password\n$preferred_root_password\" | passwd

# Boot Loader
echo -e '${COLOR}$0:${NO_COLOR} Installing boot loader..'
$(declare -f install_boot_loader)
install_boot_loader

# Custom Chroot Commands
echo -e '${COLOR}$0:${NO_COLOR} Custom chroot commands..'
$(declare -f custom_chroot_commands)
custom_chroot_commands

echo -e '${COLOR}$0:${NO_COLOR} Exiting chroot..'

" > $mount_drive/root/chroot-script.sh
chmod +x $mount_drive/root/chroot-script.sh

# Running Chroot Script
echo -e "${COLOR}$0:${NO_COLOR} Going into chroot.."
arch-chroot $mount_drive /root/chroot-script.sh
rm $mount_drive/root/chroot-script.sh

# Unmounting
if [ '$do_unmount' == true ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Unmounting drives.."
	unmount_drives
fi

echo -e "${COLOR}$0:${NO_COLOR} Arch Linux is now installed."
