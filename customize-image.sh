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

FILESYSTEM_SIZE="15500000s"

Main() {
	set_platform

	display_alert "ReARM.it customization script" "customize-image.sh" "Info"
	display_alert "BOARD" "$BOARD" "Info"

	display_alert "User configuration start..."
	config_root_user
	config_pi_user

	display_alert "Configure uboot start..."
	config_uboot

	display_alert "RetroPi installation start..."
	clone_retropie
	install_retropie

#	set_filesystem_size

	install_overlay

} # Main

install_overlay()
{
	cp -r /tmp/overlay/usr/ /

	systemctl enable rearmit-video.service
	systemctl enable rearmit-hdmi-audio.service
}

set_filesystem_size()
{
	echo $FILESYSTEM_SIZE > /root/.rootfs_resize
} # set_filesystem_size

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

config_root_user() {
	# remove armbian first login flag
	rm /root/.not_logged_in_yet
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

config_uboot() {
	sed -i 's/^bootlogo.*/bootlogo=true/' /boot/armbianEnv.txt || echo 'bootlogo=true' >> /boot/armbianEnv.txt
	sed -i 's/hdmi.audio=EDID:0 disp.screen0_output_mode=${disp_mode}/video=${disp_mode}/' /boot/boot.cmd
	sed -i 's/1920x1080p60/1920x1080@60/' /boot/boot.cmd
	echo '#disp_mode=1920x1080@60' >> /boot/armbianEnv.txt
	mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
} # config_uboot

config_audio() {
	local hw="1"
	case $BOARDFAMILY in
		sun50iw6)
			hw="0"
			;;
  	esac

	# create asound.conf
	cat > /etc/asound.conf << _EOF_
pcm.!default {
  type plug
  slave.pcm "dmixer"
}

pcm.dmixer  {
  type dmix
  ipc_key 1024
  slave {
    pcm "hw:$hw,0"
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 44100
  }
  bindings {
    0 0
    1 1
  }
}

ctl.dmixer {
  type hw
  card 0
}

ctl.!default {
    type hw
    card 0
}
_EOF_
} # config_audio

clone_retropie() {
	git clone --recurse-submodules https://github.com/rearmit/RetroPie-Setup /home/pi/RetroPie-Setup
	chown -R pi /home/pi/RetroPie-Setup
} # clone_retropie

install_retropie() {
	if [ ! -z "$platform" ]; then
		modules=(
			'mesa3d'
			'setup basic_install'
			'bluetooth depends'
			'raspbiantools enable_modules'
			'autostart enable'
			'usbromservice'
			'samba depends'
			'samba install_shares'
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
	case $BOARDFAMILY in
		sun8i)
			platform=sun8i-h3
			;;
		sun50iw6)
			platform=sun50i-h6
			;;
		sun50iw9)
			platform=sun50i-h616
			;;
		rk3399)
			platform=rk3399
			;;
	esac
} # set_platform

Main "$@"
