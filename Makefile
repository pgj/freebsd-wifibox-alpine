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
GUESTDIR=$(WORKDIR)/image-contents

.if !empty(INITRD_FILES)
INITRDDIR=$(WORKDIR)/initrd-contents
.endif

BOOTDIR=$(GUESTDIR)/boot

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

.if !empty(INITRD_FILES)
INITRD_IMG=		$(BOOTDIR)/initramfs
.endif

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
			--allow-untrusted \
			--no-progress \
			--clean-protected \
			--root $(GUESTDIR) \
			--no-scripts \
			--no-chown \
			$(PACKAGES)
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR) $(APK)
	# install extra firmware files manually
	[ -d guest/lib/firmware ] \
		&& $(CP) -R guest/lib/firmware/ $(GUESTDIR)/lib/firmware
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

.if defined(INITRD_IMG)
MKINITFSDIR=$(GUESTDIR)/usr/share/mkinitfs

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
.endif

.if defined(EXCLUDED_FILES)
_EXCLUDE_FILES=	-ef $(EXCLUDED_FILES)
.else
_EXCLUDE_FILES=
.endif

EXCLUDE_FIRMWARE_FILES=	$(WORKDIR)/exclude_firmware.files

.if defined(FIRMWARE_FILES)
.for fw_file in $(FIRMWARE_FILES)
__FW_FILES+=		-name ${fw_file} -or
.endfor
_FW_FILES=		-not \( ${__FW_FILES:S/ -or$//W} \)
_EXCLUDE_FW_FILES= 	-ef $(EXCLUDE_FIRMWARE_FILES)
.else
_EXCLUDE_FW_FILES=
.endif

$(SQUASHFS_IMG): image-contents
.if defined(_FW_FILES)
	(cd $(GUESTDIR) \
		&& $(FIND) lib/firmware -not -type d -and $(_FW_FILES) \
		> $(EXCLUDE_FIRMWARE_FILES))
.endif
	$(MKSQUASHFS) \
		$(GUESTDIR) \
		$(SQUASHFS_IMG) \
		-all-root \
		-comp $(SQUASHFS_COMP) \
		-wildcards \
		$(_EXCLUDE_FILES) \
		$(_EXCLUDE_FW_FILES) \
		-e boot -e .done -e "var/*"

_TARGETS=	$(SQUASHFS_IMG)
.if defined(INITRD_IMG)
_TARGETS+=	$(INITRD_IMG)
.endif

all:	$(_TARGETS)

install:
	$(MKDIR) -p $(SHAREDIR)
.if defined(INITRD_IMG)
	$(INSTALL_DATA) $(INITRD_IMG) $(SHAREDIR)
.endif
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
	$(RM) -rf $(APPLIANCEDIR)/lock
	$(LN) -s /run/lock $(APPLIANCEDIR)/lock

clean:
	$(RM) -rf $(GUESTDIR)
.if defined(INITRDDIR)
	$(RM) -rf $(INITRDDIR)
.endif
	$(RM) -f $(SQUASHFS_IMG)

.MAIN:	all
