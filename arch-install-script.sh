#!/bin/bash

# Color Definitions (Change if you want)
COLOR='\033[1;34m' # default is light blue
NO_COLOR='\033[0m'

###
### Configuration
###

# Updating the System Clock
do_update_system_clock=true
ask_if_the_system_clock_is_okay_before_proceeding=false

# Partitioning/Formatting (Manual)
do_partition_and_format=true # if you want to partition and format before hand, you can set this to false.

function partition_and_format_drives {
	mkfs.ext4 /dev/sda6
	mkfs.ext4 /dev/sda7
	mkswap /dev/sda5
}

# Mounting (Manual)
do_mount=true # if you want to mount before hand, you can set this to false.
mount_drive='/mnt' # This variable must be set.

function mount_partitions {
	mount /dev/sda6 $mount_drive
	mkdir -p $mount_drive/home
	mount /dev/sda7 $mount_drive/home
	swapon /dev/sda5
}

# Setting Mirrors
use_reflector=true # if false, you must select mirrors manually.
reflector_command='reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist'

# Installation
install_base_devel=true

# Fstab
use_uuid=true # if false, labels will be used.
ask_to_edit_before_proceeding=false
fstab_editor='nano'

# Time zone
timezone_info='America/New_York'
enable_ntpd_on_startup=true

# Locale
default_language='en_US.UTF-8'
needed_localizations='
en_US.UTF-8 UTF-8
'

# Keyboard Layout
non_us_keyboard_layout=false
used_layout='de-latin1'

# Hostname
preferred_hostname='gandalf'

# Root Password
preferred_root_password='password'

# Boot Loader (Manual)

function install_boot_loader {
	pacman -S --noconfirm grub os-prober
	grub-install --target=i386-pc /dev/sda # Change for your specific drive
	echo "
	if [ '$grub_platform' == 'pc' ]; then
		menuentry 'Windows 10' {
			insmod ntfs
			set root=(hd0,1)
			chainloader +1
		}
	fi
	" >> /etc/grub.d/40_custom # Custom setup for my grub configuration, delete or change if you do not have windows 10 on /dev/sda1
	grub-mkconfig -o /boot/grub/grub.cfg
}

# Custom Commands in Chroot (Manual)

function custom_chroot_commands {
	# Empty for me, I usually install and customize after installation.
}

# Unmounting
do_unmount=true

function unmount_drives {
	umount -R $mount_drive
}

###
### Actual Install Script
###

# Updating the System Clock
if [ "$do_update_system_clock" == "true" ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Updating the system clock.."
	timedatectl set-ntp true
	timedatectl status
	if [ "$ask_if_the_system_clock_is_okay_before_proceeding" == "true" ]; then
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
if [ "$do_partitioning_and_formatting" == "true" ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Partitioning and formatting drives.."
	partition_and_format_drives
fi

# Mounting
if [ "$do_mounting" == "true" ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Mounting partitions.."
	mount_partitions
fi

# Setting Mirrors
if [ "$use_reflector" == "true" ]; then
	echo -e "${COLOR}$0:${NO_COLOR} Setting mirrors.."
	$reflector_command --verbose
fi

# Installation
echo -e "${COLOR}$0:${NO_COLOR} Installing Arch Linux.."
if [ "$install_base_devel" == "true" ]; then
	echo y | pacstrap $mount_drive base base-devel
else
	echo y | pacstrap $mount_drive base
fi

# Fstab
echo -e "${COLOR}$0:${NO_COLOR} Generating fstab.."
if [ "$use_uuid" == "true" ]; then
	genfstab -U $mount_drive >> $mount_drive/etc/fstab
else
	genfstab -L $mount_drive >> $mount_drive/etc/fstab
fi

echo -e "${COLOR}$0:${NO_COLOR} Output:"
cat $mount_drive/etc/fstab

if [ "$ask_to_edit_before_proceeding" == "true" ]; then
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
echo "#!/bin/bash

# Time zone
echo -e '${COLOR}$0:${NO_COLOR} Setting time zone..'
ln -sf /usr/share/zoneinfo/$timezone_info /etc/localtime
hwclock --systohc
if [ '$enable_ntpd_on_startup' == 'true' ]; then
	pacman -S ntp
	systemctl enable ntpd.service
fi

# Locale
echo -e '${COLOR}$0:${NO_COLOR} Setting up localizations..'
echo $needed_localizations >> /etc/locale.gen
locale-gen
echo 'LANG=$default_language' >> /etc/locale.conf

# Keyboard Layout
if [ '$non_us_keyboard_layout' == 'true' ]; then
	echo -e '${COLOR}$0:${NO_COLOR} Setting keyboard layout..'
	echo 'KEYMAP=$used_layout' >> /etc/vconsole.conf
fi

# Hostname
echo -e '${COLOR}$0:${NO_COLOR} Setting hostname..'
echo $preferred_hostname >> /etc/hostname
echo '127.0.1.1	$preferred_hostname.localdomain	$preferred_hostname' >> /etc/hosts

# Internet
echo -e '${COLOR}$0:${NO_COLOR} Enabling internet..'

if [ '$enable_dhcpcd' == 'true' ]; then
	systemctl enable dhcpcd.service
fi

if [ $enable_netctl == 'true' ]; then
	systemctl enable netctl.service
fi

if [ $enable_NetworkManager == 'true' ]; then
	systemctl enable NetworkManager.service
fi

# Setting Root Password
echo -e '${COLOR}$0:${NO_COLOR} Setting root password..'
echo $preferred_root_password | passwd

# Boot Loader
echo -e '${COLOR}$0:${NO_COLOR} Installing boot loader..'
$(declare -f install_boot_loader)
install_boot_loader

# Custom Chroot Commands
echo -e '${COLOR}$0:${NO_COLOR} Performing custom chroot commands..'
$(declare -f custom_chroot_commands)
custom_chroot_commands

echo -e '${COLOR}$0:${NO_COLOR} Exiting chroot..'

" > $mount_drive/root/chroot-script.sh
chmod +x $mount_drive/root/chroot-script.sh

# Running Chroot Script
echo -e '${COLOR}$0:${NO_COLOR} Going into chroot..'
arch-chroot $mount_drive $mount_drive/root/chroot-script.sh

# Unmounting
if [ '$do_unmount' == 'true' ]; then
	echo -e '${COLOR}$0:${NO_COLOR} Unmounting drives..'
	unmount_drives
fi

echo -e '${COLOR}$0:${NO_COLOR} Arch Linux is now installed.'
