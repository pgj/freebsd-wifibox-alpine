PREFIX?=/usr/local
LOCALBASE?=/usr/local
MINIROOTFS?=$(PWD)/alpine-minirootfs.tar.gz
PACKAGES?=$(PWD)/*.apk
INITRD_FILES?=$(PWD)/guest/initrd.files

ROOT=$(PREFIX)/share/wifibox
SHAREDIR=$(DESTDIR)$(ROOT)
ETCDIR=$(DESTDIR)$(PREFIX)/etc/wifibox
MANDIR=$(DESTDIR)$(PREFIX)/man
RUNDIR=$(DESTDIR)/var/run/wifibox

WORKDIR?=$(PWD)/work
GUESTDIR?=$(WORKDIR)/image-contents
INITRDDIR?=$(WORKDIR)/initrd-contents

BOOTDIR=$(GUESTDIR)/boot
MKINITFSDIR=$(GUESTDIR)/usr/share/mkinitfs

SHAREMODE?=0644

ENV=/usr/bin/env
MKDIR=/bin/mkdir
CAT=/bin/cat
CP=/bin/cp
MV=/bin/mv
SED=/usr/bin/sed
TAR=/usr/bin/tar
CPIO=/usr/bin/cpio
FIND=/usr/bin/find
RM=/bin/rm
LN=/bin/ln
GZIP=/usr/bin/gzip
INSTALL_DATA=/usr/bin/install -m $(SHAREMODE)
TOUCH=/usr/bin/touch
GIT=$(LOCALBASE)/bin/git
PATCHELF=$(LOCALBASE)/bin/patchelf
BRANDELF=/usr/bin/brandelf
MKSQUASHFS=$(LOCALBASE)/bin/mksquashfs

ELF_INTERPRETER=	/lib/ld-musl-x86_64.so.1
APK=			sbin/apk

_APK=			$(GUESTDIR)/$(APK)

INITRD_IMG=		$(BOOTDIR)/initramfs

SQUASHFS_COMP?=		lzo
SQUASHFS_IMG=		$(PWD)/alpine-$(VERSION).squashfs.img
SQUASHFS_VMLINUZ=	$(BOOTDIR)/vmlinuz*

BOOT_SERVICES=		networking urandom bootmisc modules hostname hwclock sysctl syslog \
			wpa_supplicant wpa_passthru
DEFAULT_SERVICES=	acpid crond iptables udhcpd
SYSINIT_SERVICES=	devfs dmesg hwdrivers mdev

BUSYBOX_EXTRAS=		usr/sbin/dnsd usr/bin/dumpleases usr/sbin/fakeidentd \
			usr/sbin/ftpd usr/bin/ftpget usr/bin/ftpput usr/sbin/httpd \
			usr/sbin/inetd usr/bin/telnet usr/sbin/telnetd \
			usr/bin/tftp usr/sbin/tftpd usr/sbin/udhcpd

.if !defined(VERSION)
VERSION!=	$(GIT) describe --tags --always
.endif

SUB_LIST=	PREFIX=$(PREFIX) \
		LOCALBASE=$(LOCALBASE) \
		ROOT=$(ROOT)

_SUB_LIST_EXP=  ${SUB_LIST:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/}

APPLIANCEDIR=	$(RUNDIR)/appliance

$(GUESTDIR)/.done:
	$(RM) -rf $(GUESTDIR)
	$(MKDIR) -p $(GUESTDIR)
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR)
	# add customizations
	$(CP) -R guest/etc/* $(GUESTDIR)/etc/
	$(CP) -R guest/sbin/* $(GUESTDIR)/sbin/
	$(LN) -s /dev/null $(GUESTDIR)/root/.ash_history
	$(LN) -s /tmp/resolv.conf $(GUESTDIR)/etc
	$(RM) $(GUESTDIR)/etc/motd
	$(MKDIR) -p $(GUESTDIR)/media/etc
	$(MKDIR) -p $(GUESTDIR)/media/wpa
	# passwd -d
	$(CAT) $(GUESTDIR)/etc/shadow \
		| $(SED) 's@root:!::0:::::@root:::0:::::@' \
		> $(GUESTDIR)/etc/shadow.fixed
	$(MV) $(GUESTDIR)/etc/shadow.fixed $(GUESTDIR)/etc/shadow
	# add packages without chroot(8)
	$(PATCHELF) \
		--set-interpreter $(GUESTDIR)$(ELF_INTERPRETER) \
		$(_APK)
	$(BRANDELF) -t Linux $(_APK)
	$(ENV) LD_LIBRARY_PATH=$(GUESTDIR)/lib \
		$(_APK) add \
			--no-network \
			--force-non-repository \
			--no-progress \
			--clean-protected \
			--root $(GUESTDIR) \
			--no-scripts \
			--no-chown \
			$(PACKAGES)
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR) $(APK)
	# busybox-extras.post-install
.for binary in $(BUSYBOX_EXTRAS)
	$(LN) -s /bin/busybox-extras $(GUESTDIR)/${binary}
.endfor
	# rc-update add
.for runlevel in boot default sysinit
.for service in $(${runlevel:tu}_SERVICES)
	$(LN) -s /etc/init.d/${service} $(GUESTDIR)/etc/runlevels/${runlevel}
.endfor
.endfor
	$(TOUCH) $(GUESTDIR)/.done

image-contents: $(GUESTDIR)/.done

$(INITRD_IMG): image-contents $(INITRD_FILES)
	$(RM) -rf $(INITRDDIR)
	(cd $(GUESTDIR) \
		&& $(FIND) $$($(CAT) $(INITRD_FILES)) -depth 0 \
		| $(CPIO) -pdmu $(INITRDDIR))
	$(MKDIR) -p $(INITRDDIR)/newroot
	$(MKDIR) -p $(INITRDDIR)/.modloop
	$(CP) \
		$(MKINITFSDIR)/fstab \
		$(MKINITFSDIR)/group \
		$(MKINITFSDIR)/passwd \
		$(INITRDDIR)/etc
	$(CP) $(MKINITFSDIR)/initramfs-init $(INITRDDIR)/init
	(cd $(INITRDDIR) \
		&& $(FIND) . \
			| $(CPIO) -o -y --format newc --owner root:wheel \
			> $(INITRD_IMG))

$(SQUASHFS_IMG): image-contents $(INITRD_IMG)
	$(MKSQUASHFS) \
		$(GUESTDIR) \
		$(SQUASHFS_IMG) \
		-all-root \
		-comp $(SQUASHFS_COMP) \
		-wildcards -e boot -e .done -e "var/*"

all:	$(SQUASHFS_IMG)

install:
	$(MKDIR) -p $(SHAREDIR)
	$(INSTALL_DATA) $(INITRD_IMG) $(SHAREDIR)
	$(INSTALL_DATA) $(SQUASHFS_VMLINUZ) $(SHAREDIR)/vmlinuz
	$(INSTALL_DATA) $(SQUASHFS_IMG) $(SHAREDIR)/disk.img
	$(SED) ${_SUB_LIST_EXP} share/grub.cfg > $(SHAREDIR)/grub.cfg

	$(MKDIR) -p $(ETCDIR)
	$(CP) etc/* $(ETCDIR)/

	$(MKDIR) -p $(MANDIR)/man5
	$(SED) ${_SUB_LIST_EXP} man/wifibox-alpine.5 \
	  | $(GZIP) -c > $(MANDIR)/man5/wifibox-alpine.5.gz

	$(MKDIR) -p $(APPLIANCEDIR)
	$(CP) -R $(GUESTDIR)/var/* $(APPLIANCEDIR)/

clean:
	$(RM) -rf $(GUESTDIR)
	$(RM) -rf $(INITRDDIR)
	$(RM) -f $(SQUASHFS_IMG)

.MAIN:	all
