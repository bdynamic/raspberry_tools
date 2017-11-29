#!/bin/bash

#system_readonly_prep.sh


##### Warning this still development and doesn't work completely!




function PREP_SYSTEM {
	##
	#### Patch the Fstab
	###
	echo ""
	echo "Preparing the system to be readonly"

	echo "Patching fstab (org at /etc/fstab.org)"
	cp /etc/fstab /etc/fstab.org

	#extend  fstab
	cat << 'EOF' >> /etc/fstab

\#for readonly system --------------------------------------------------
tmpfs      /tmp                 tmpfs           defaults,noatime,nodev,nosuid,mode=1777    0 0
tmpfs      /var/lib/dhcp        tmpfs           defaults,size=1m,noatime,nodev,nosuid,mode=1777    0 0             
tmpfs      /var/spool           tmpfs           defaults,noatime,nodev,nosuid,mode=1777    0 0
tmpfs      /var/lock            tmpfs           defaults,size=1m,noatime,nodev,nosuid,mode=1777    0 0
tmpfs      /run                 tmpfs           defaults,size=10m,noatime,nodev,nosuid,mode=1777    0 0
EOF

	echo "Changing mounts of existing mountpoints"
	#make main and boot filesystems readonly
	cat /etc/fstab |sed 's/defaults,noatime,discard/ro,defaults,noatime,discard/g' >/tmp/fstab.tmp
	cat /tmp/fstab.tmp >/etc/fstab
	rm /tmp/fstab.tmp

	##
	#### Ready the resolve.conf
	###
	#echo "Changing resolve.conf (org backup at /etc/resolvconf/run/resolv.conf.org)"

	#original resolve.conf is also a link! /etc/resolv.conf -> /etc/resolvconf/run/resolv.conf
	#no need for linking because /etc/resolvconf/run is a link to /etc/resolvconf/run -> /run/resolvconf
	#cp -a /etc/resolvconf/run/resolv.conf /etc/resolvconf/run/resolv.conf.org
	#mv /etc/resolvconf/run/resolv.conf /tmp/resolv.conf
	#ln -s /tmp/resolv.conf /etc/resolvconf/run/resolv.conf


	#link resolv.conf to tmp fs



#   solution try one
#	cp /etc/resolv.conf /etc/resolv.conf.org
#	mv /etc/resolv.conf /tmp/resolv.conf
#	ln -s /tmp/resolv.conf /etc/resolv.conf
#	echo -e '#!/bin/bash\ntouch /tmp/resolve.conf' >/etc/dhcp/dhclient-enter-hooks.d/create_resolveconf
#

#   solution try 2
#	cp /etc/resolv.conf /etc/resolv.conf.org
#	mv /etc/resolv.conf /tmp/resolv.conf
#	ln -s /tmp/resolv.conf /etc/resolv.conf
#	echo "patch the systemd resolfe file (org at /lib/systemd/system/resolvconf.service.org)"
#	cp /lib/systemd/system/resolvconf.service /lib/systemd/system/resolvconf.service.org
#	cat /lib/systemd/system/resolvconf.service |sed 's/RemainAfterExit=yes/RemainAfterExit=yes\nExecStartPre=\/bin\/echo "" >\/tmp\/resolv.conf/g' >/tmp/resolvconf.service
#	cat /tmp/resolvconf.service >/lib/systemd/system/resolvconf.service
#	rm /tmp/resolvconf.service

	# #solution try 3
	# #https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=62705#p465352
	# mv /etc/resolv.conf /tmp/resolv.conf
	# ln -s /tmp/resolv.conf /etc/resolv.conf
	# cp -a /sbin/dhclient-script /sbin/dhclient-script.org
	# cat /sbin/dhclient-script|sed 's/\/etc\/resolv.conf/\/tmp\/resolv.conf/g' >/tmp/dhclient-script
	# cat /tmp/dhclient-script >/sbin/dhclient-script
	# rm /tmp/dhclient-script



## apt helper - put into /etc/apt/apt.conf 
# SRC: https://wiki.debian.org/ReadonlyRoot
#DPkg {
#    // Auto re-mounting of a readonly /
#    Pre-Invoke { "mount -o remount,rw /"; };
#    Post-Invoke { "test ${NO_APT_REMOUNT:-no} = yes || mount -o remount,ro / || true"; };
#};






	##
	#### patch /boot/commandln
	###
	echo "Patching /boot/commandln (org at /boot/cmdline.txt.org)"
	cp /boot/cmdline.txt /boot/cmdline.txt.org
	TMPVAR=$(cat /boot/cmdline.txt)
	echo "$TMPVAR fastboot noswap" >/boot/cmdline.txt

	##
	#### patch random seed service so we don't get an error on startup
	###
	echo "relinking random seed file"
	/bin/echo "" >/tmp/random-seed
	rm /var/lib/systemd/random-seed
	ln -s /tmp/random-seed /var/lib/systemd/random-seed
	#patch the systemd file
	echo "patch the systemd randomseed file (org at /lib/systemd/system/systemd-random-seed.service.org)"
	cp /lib/systemd/system/systemd-random-seed.service /lib/systemd/system/systemd-random-seed.service.org
	cat /lib/systemd/system/systemd-random-seed.service |sed 's/RemainAfterExit=yes/RemainAfterExit=yes\nExecStartPre=\/bin\/echo "" >\/tmp\/random-seed/g' >/tmp/systemd-random-seed.service
	cat /tmp/systemd-random-seed.service >/lib/systemd/system/systemd-random-seed.service
	rm /tmp/systemd-random-seed.service
}

function CLEANUP_SYSTEM {

	##
	#### clean up apt
	###
	echo ""
	echo "Cleaning up system"
	apt-get autoremove -y
	apt-get clean
}


function INSTALL_HELPERS {
	echo ""
	echo "Creating Helper scripts"
	echo "/usr/local/sbin/system_set_ro.sh"
	echo "/usr/local/sbin/system_set_rw.sh"
	##
	#### install helper scripts
	###
	cat << 'EOF' > /usr/local/sbin/system_set_ro.sh
#!/bin/bash
#This script restores the system ro statesystem_set_ro
apt-get autoremove 
apt-get clean
echo “Will reboot for making system ro again”
read -p "Press enter to continue"
reboot

EOF



	cat << 'EOF' > /usr/local/sbin/system_set_rw.sh
#!/bin/bash
#This script makes the system writeable again
mount -o remount,rw /
mount -o remount,rw /boot
echo “System is now writable – please use the command system_set_ro.sh again when finished”

EOF

	#make them executabel
	chmod +x /usr/local/sbin/system_set_rw.sh
	chmod +x /usr/local/sbin/system_set_ro.sh
}


function FINISH {
	##
	#### Work finished
	###
	echo ""
	echo "Work is finished - time for a reboot"
	if [ "$1" = "scripted" ]; then
		echo "Rebooting now"
		reboot
		exit 0
	else
		echo "Running interactive - no auto reboot"
		exit 0
	fi
}

PREP_SYSTEM
#CLEANUP_SYSTEM
INSTALL_HELPERS
FINISH $1


