PREFIX?=/usr/local
LOCALBASE?=/usr/local
MINIROOTFS?=alpine-minirootfs.tar.gz
PACKAGES?=*.apk

ROOT=$(PREFIX)/share/wifibox
SHAREDIR=$(DESTDIR)$(ROOT)
ETCDIR=$(DESTDIR)$(PREFIX)/etc/wifibox
MANDIR=$(DESTDIR)$(PREFIX)/man
RUNDIR=$(DESTDIR)/var/run/wifibox

GUESTDIR?=work/image-contents
PACKAGEDIR=$(GUESTDIR)/packages
BOOTDIR=$(GUESTDIR)/boot

SHAREMODE?=0644

MKDIR=/bin/mkdir
CP=/bin/cp
SED=/usr/bin/sed
TAR=/usr/bin/tar
CHROOT=/usr/sbin/chroot
RM=/bin/rm
GZIP=/usr/bin/gzip
INSTALL_DATA=/usr/bin/install -m $(SHAREMODE)
TOUCH=/usr/bin/touch
GIT=$(LOCALBASE)/bin/git

MKSQUASHFS=$(LOCALBASE)/bin/mksquashfs
SQUASHFS_COMP?=		lzo
SQUASHFS_IMG=		alpine-$(VERSION).squashfs.img
SQUASHFS_INITRAMFS=	$(BOOTDIR)/initramfs*
SQUASHFS_VMLINUZ=	$(BOOTDIR)/vmlinuz*

.if !defined(VERSION)
VERSION!=	$(GIT) describe --tags --always
.endif

SUB_LIST=	PREFIX=$(PREFIX) \
		LOCALBASE=$(LOCALBASE) \
		ROOT=$(ROOT)

_SUB_LIST_EXP=  ${SUB_LIST:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/}

APPLIANCEDIR=	$(RUNDIR)/appliance

image-contents: $(GUESTDIR)/.done

$(GUESTDIR)/.done:
	$(RM) -rf $(GUESTDIR)
	$(MKDIR) -p $(GUESTDIR)
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR)
	$(CP) -R guest/etc/* $(GUESTDIR)/etc/
	$(CP) -R guest/sbin/* $(GUESTDIR)/sbin/
	$(MKDIR) -p $(PACKAGEDIR)
	$(CP) -R $(PACKAGES) $(PACKAGEDIR)/
	$(CP) guest/setup.sh $(GUESTDIR)/
	$(CHROOT) $(GUESTDIR) /bin/ash setup.sh
	$(RM) -rf $(PACKAGEDIR)
	$(RM) $(GUESTDIR)/setup.sh
	$(RM) -f $(GUESTDIR)/busybox.core
	$(TOUCH) $(GUESTDIR)/.done

$(SQUASHFS_IMG): image-contents
	$(MKSQUASHFS) \
		$(GUESTDIR) \
		$(SQUASHFS_IMG) \
		-comp $(SQUASHFS_COMP) \
		-wildcards -e boot -e .done -e "var/*"

all:	$(SQUASHFS_IMG)

install:
	$(MKDIR) -p $(SHAREDIR)
	$(INSTALL_DATA) $(SQUASHFS_INITRAMFS) $(SHAREDIR)/initramfs
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
	$(RM) $(SQUASHFS_IMG)

.MAIN:	all
