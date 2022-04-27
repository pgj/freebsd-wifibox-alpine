PREFIX?=/usr/local
LOCALBASE?=/usr/local
MINIROOTFS?=alpine-minirootfs.tar.gz
PACKAGES?=*.apk

SHAREDIR=$(DESTDIR)$(PREFIX)/share/wifibox
ETCDIR=$(DESTDIR)$(PREFIX)/etc/wifibox
MANDIR=$(DESTDIR)$(PREFIX)/man
RUNDIR=$(DESTDIR)/var/run/wifibox

WORKDIR?=$(PWD)/work
GUESTDIR?=$(WORKDIR)/image-contents
PACKAGEDIR=$(GUESTDIR)/packages

MKDIR=/bin/mkdir
CP=/bin/cp
EXPR=/bin/expr
LN=/bin/ln
FGREP=/usr/bin/fgrep
SED=/usr/bin/sed
TAR=/usr/bin/tar
FIND=/usr/bin/find
CHROOT=/usr/sbin/chroot
RM=/bin/rm
TOUCH=/usr/bin/touch
TRUNCATE=/usr/bin/truncate
TRUE=/usr/bin/true
GZIP=/usr/bin/gzip
MDCONFIG=/sbin/mdconfig
GPART=/sbin/gpart
MOUNT=/sbin/mount
UMOUNT=/sbin/umount
GIT=$(LOCALBASE)/bin/git
MKE2FS=$(LOCALBASE)/sbin/mkfs.ext2
DUMPE2FS=$(LOCALBASE)/sbin/dumpe2fs
RESIZE2FS=$(LOCALBASE)/sbin/resize2fs

DISK_IMAGE=	disk.$(VERSION).img
DISK_INIT_SIZE=	1G

.if !defined(VERSION)
VERSION!=	$(GIT) describe --tags --always
.endif

SUB_LIST=	PREFIX=$(PREFIX) \
		LOCALBASE=$(LOCALBASE) \

_SUB_LIST_EXP=  ${SUB_LIST:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/}

APPLIANCE_DIR=	$(RUNDIR)/appliance

$(DISK_IMAGE):
	$(TRUNCATE) -s $(DISK_INIT_SIZE) $(DISK_IMAGE)
	_MD=$$($(MDCONFIG) -a -t vnode -f $(DISK_IMAGE)); \
	$(GPART) create -s MBR $$_MD; \
	$(GPART) add -t linux-data -i 1 $$_MD; \
	$(MKE2FS) -O ^has_journal -m 0 /dev/$${_MD}s1; \
	$(MKDIR) -p $(GUESTDIR); \
	$(MOUNT) -t ext2fs /dev/$${_MD}s1 $(GUESTDIR); \

	$(FIND) $(GUESTDIR) -mindepth 1 -delete
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

	$(MKDIR) -p $(APPLIANCE_DIR)
	$(CP) -R $(GUESTDIR)/var/* $(APPLIANCE_DIR)/
	$(RM) -rf $(APPLIANCE_DIR)/lock
	$(LN) -s /run/lock $(APPLIANCE_DIR)/lock

	$(RM) -rf $(GUESTDIR)/var/*

	$(UMOUNT) $(GUESTDIR)

	_MD=$$($(MDCONFIG) -l -f $(DISK_IMAGE) | $(SED) -E 's@[[:blank:]]*$$@@'); \
	$(RESIZE2FS) -M /dev/$${_MD}s1; \
	_BLOCKS=$$($(DUMPE2FS) /dev/$${_MD}s1 2>&1 \
		| $(FGREP) "Block count:" \
		| $(SED) -E 's@[^0-9]*([0-9]+)@\1@'); \
	_SIZE=$$($(EXPR) 8 \* $$_BLOCKS); \
	$(GPART) resize -i 1 -s $$_SIZE $$_MD; \
	_END=$$($(GPART) list $$_MD | $(FGREP) "end:" | $(SED) -E 's@[^0-9]*([0-9]+)@\1@'); \
	_NEWSIZE=$$($(EXPR) 512 \* \( 1 + $$_END \)); \
	$(MDCONFIG) -d -u $$_MD; \
	$(TRUNCATE) -s $$_NEWSIZE $(DISK_IMAGE)

all: $(DISK_IMAGE)

install:
	$(MKDIR) -p $(SHAREDIR)
	$(SED) ${_SUB_LIST_EXP} share/device.map > $(SHAREDIR)/device.map
	$(CP) share/grub.cfg $(SHAREDIR)
	$(CP) $(DISK_IMAGE) $(SHAREDIR)

	$(MKDIR) -p $(ETCDIR)
	$(CP) etc/* $(ETCDIR)/

	$(MKDIR) -p $(MANDIR)/man5
	$(SED) ${_SUB_LIST_EXP} man/wifibox-alpine.5 \
	  | $(GZIP) -c > $(MANDIR)/man5/wifibox-alpine.5.gz

.MAIN: all

clean:
	if $(MOUNT) | $(FGREP) -q $(GUESTDIR); then $(UMOUNT) $(GUESTDIR); fi
	$(RM) -rf $(GUESTDIR)
	if [ -f "$(DISK_IMAGE)" ]; then _MD=$$($(MDCONFIG) -l -f $(DISK_IMAGE) || $(TRUE)); fi; \
	if [ -n "$$_MD" ]; then $(MDCONFIG) -d -u $$_MD; fi
	$(RM) -f $(DISK_IMAGE)
