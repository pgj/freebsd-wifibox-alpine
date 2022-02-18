PREFIX?=/usr/local
LOCALBASE?=/usr/local
MINIROOTFS?=alpine-minirootfs.tar.gz
PACKAGES?=*.apk

ROOT=$(PREFIX)/share/wifibox/guest
SHAREDIR=$(DESTDIR)$(PREFIX)/share/wifibox
GUESTDIR=$(SHAREDIR)/guest
PACKAGEDIR=$(GUESTDIR)/packages
MANDIR=$(DESTDIR)$(PREFIX)/man

MKDIR=/bin/mkdir
CP=/bin/cp
SED=/usr/bin/sed
TAR=/usr/bin/tar
CHROOT=/usr/sbin/chroot
RM=/bin/rm
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
	$(SED) ${_SUB_LIST_EXP} grub.cfg > $(SHAREDIR)/grub.cfg
	$(TAR) -xf $(MINIROOTFS) -C $(GUESTDIR)
	$(CP) -R etc/* $(GUESTDIR)/etc/
	$(MKDIR) -p $(PACKAGEDIR)
	$(CP) -R $(PACKAGES) $(PACKAGEDIR)/
	$(CP) setup.sh $(GUESTDIR)/
	$(CHROOT) $(GUESTDIR) /bin/ash setup.sh
	$(RM) -rf $(PACKAGEDIR)
	$(RM) $(GUESTDIR)/setup.sh
	$(RM) $(GUESTDIR)/busybox.core

.MAIN: clean

clean: ;
