#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4
BOARDFAMILY=$6
BUILDBINARY=$7

Main() {
	display_alert "ReARM.it customization script" "customize-image.sh" "Info"
	display_alert "BOARD" "$BOARD" "Info"

	display_alert "User configuration start..."
	config_root_password
	config_pi_user

	display_alert "Configure uboot start..."
	config_uboot

	display_alert "Set host name..."
	set_hostname

	display_alert "RetroPi installation start..."
	clone_retropie

	install_retropie

} # Main

display_alert()
{
	local tmp=""
	[[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

	case $3 in
		err)
		echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
		;;

		wrn)
		echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
		;;

		ext)
		echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
		;;

		info)
		echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
		;;

		*)
		echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
		;;
	esac
} # display_alert

config_root_password() {
	# remove armbian first login flag
	rm /root/.not_logged_in_yet

	# assign rearm password to root user
	echo root:rearm | chpasswd
} # config_root_password

config_pi_user() {
	# create pi user
	adduser pi --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password

	# assign rearm password to pi user
	echo pi:rearm | chpasswd

	# add pi user to video e input group
	usermod -a -G video pi
	usermod -a -G audio pi
	usermod -a -G input pi

	#
	rm -f /etc/systemd/system/getty@.service.d/override.conf
	rm -f /etc/systemd/system/serial-getty@.service.d/override.conf

	# add pi user to sudoers
	echo 'pi ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
} # config_pi_user

set_hostname() {
	echo 'rearmit' > /etc/hostname
} # set_hostname

config_uboot() {
	sed -i 's/^bootlogo.*/bootlogo=true/' /boot/armbianEnv.txt || echo 'bootlogo=true' >> /boot/armbianEnv.txt
} # config_uboot

clone_retropie() {
	git clone https://github.com/rearmit/RetroPie-Setup /home/pi/RetroPie-Setup
	chown -R pi /home/pi/RetroPie-Setup
} # clone_retropie

install_retropie() {
	platform="sun50i-h6"
	if [ ! -z "$platform" ]; then
		modules=(
			'setup basic_install'
			'bluetooth depends'
			'raspbiantools enable_modules'
			'autostart enable'
			'usbromservice'
			'samba depends'
			'samba install_shares'
			'xpad'
		)
		for module in "${modules[@]}"; do
			su -c "sudo -S __platform=${platform} __nodialog=1 /home/pi/RetroPie-Setup/retropie_packages.sh ${module}" - pi
		done
	fi
	rm -rf /home/pi/RetroPie-Setup/tmp
	chown -R pi /home/pi/RetroPie-Setup
	sudo apt-get clean
} # install_retropie

set_platform() {
	case $BOARD in
		sun50iw6)
			platform=sun50i-h6
			;;
	esac
} # set_platform

Main "$@"
