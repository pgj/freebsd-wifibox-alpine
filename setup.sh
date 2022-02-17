apk add --no-network /packages/*.apk
passwd -d root
rm /etc/motd
rc-update add networking boot
rc-update add urandom boot
rc-update add acpid default
rc-update add modules boot
rc-update add chronyd default
rc-update add crond default
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add hostname boot
rc-update add hwclock boot
rc-update add hwdrivers sysinit
rc-update add iptables default
rc-update add killprocs shutdown
rc-update add mdev sysinit
rc-update add savecache shutdown
rc-update add sysctl boot
rc-update add syslog boot
rc-update add udhcpd default
rc-update add wpa_supplicant boot
mkdir -p /media/etc
