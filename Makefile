PREFIX?=/usr/local
LOCALBASE?=/usr/local
MINIROOTFS?=alpine-minirootfs.tar.gz
PACKAGES?=*.apk

ROOT=$(PREFIX)/share/wifibox/guest
SHAREDIR=$(DESTDIR)$(PREFIX)/share/wifibox
GUESTDIR=$(SHAREDIR)/guest
PACKAGEDIR=$(GUESTDIR)/packages
ETCDIR=$(DESTDIR)$(PREFIX)/etc/wifibox
MANDIR=$(DESTDIR)$(PREFIX)/man

MKDIR=/bin/mkdir
CP=/bin/cp
SED=/usr/bin/sed
TAR=/usr/bin/tar
CHROOT=/usr/sbin/chroot
RM=/bin/rm
GZIP=/usr/bin/gzip
GIT=$(LOCALBASE)/bin/git

.if !defined(VERSION)
VERSION!=	$(GIT) describe --tags --always
.endif

SUB_LIST=	PREFIX=$(PREFIX) \
		LOCALBASE=$(LOCALBASE) \
		ROOT=$(ROOT)

_SUB_LIST_EXP=  ${SUB_LIST:S/$/!g/:S/^/ -e s!%%/:S/=/%%!/}

install:
	$(MKDIR) -p $(GUESTDIR)
	$(SED) ${_SUB_LIST_EXP} share/grub.cfg > $(SHAREDIR)/grub.cfg
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR)
	$(CP) -R guest/etc/* $(GUESTDIR)/etc/
	$(MKDIR) -p $(PACKAGEDIR)
	$(CP) -R $(PACKAGES) $(PACKAGEDIR)/
	$(CP) guest/setup.sh $(GUESTDIR)/
	$(CHROOT) $(GUESTDIR) /bin/ash setup.sh
	$(RM) -rf $(PACKAGEDIR)
	$(RM) $(GUESTDIR)/setup.sh
	$(RM) $(GUESTDIR)/busybox.core

	$(MKDIR) -p $(ETCDIR)
	$(CP) etc/* $(ETCDIR)/

	$(MKDIR) -p $(MANDIR)/man5
	$(SED) ${_SUB_LIST_EXP} man/wifibox-alpine.5 \
	  | $(GZIP) -c > $(MANDIR)/man5/wifibox-alpine.5.gz

.MAIN: clean

clean: ;
