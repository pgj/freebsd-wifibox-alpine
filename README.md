# FreeBSD Wifibox/Alpine

The purpose of this repository is to maintain all the configuration
files and scripts that are used for rolling out a [FreeBSD Wifibox]
guest based on [Alpine Linux].

## Warning

*This is a work-in-progress experimental software project without any
guarantees or warranties.  It is shared in the hope that is going to
be useful and inspiring for others.  Please report issues at the
[FreeBSD Wifibox] repository directly.*

## Prerequisites

For building the virtual disk image, the following third-party
software is employed, which must be installed beforehand.

- [SquashFS Tools NG] or the `sysutils/squashfs-tools-ng` FreeBSD
  package.
- [GNU Tar] or the `archivers/gtar` FreeBSD package.
- [PatchELF] or the `sysutils/patchelf` FreeBSD package.

Note that the build process also uses native 64-bit Linux binaries,
that is why the [Linuxulator] must be activated by loading the
`linux64` kernel module.

```console
# kldload linux64
```

## Installation

Whenever possible, use the `net/wifibox-alpine` FreeBSD port from the
[freebsd-wifibox-port] repository, which aims to automate the tasks
described below and offers proper removal of the install files.

### Manual Installation

There is a `Makefile` present in the root of the repository that could
be used to drive the installation process.  It is mostly recommended
for development and testing.

```console
# make install \
	PREFIX=<prefix> \
	LOCALBASE=<prefix of third-party software> \
	MINIROOTFS=<Alpine minimal root file system tarball> \
	PACKAGES=<Alpine package set> \
	BOOT_SERVICES=<services to launch on boot> \
	DEFAULT_SERVICES=<default services> \
	SYSINIT_SERVICES=<system initialization services> \
	ETC_SRCS=<location of application-specific configuration files> \
	EXTRA_VIRTFS_MOUNTS=<fstab entries for shared file systems> \
	FIRMWARE_FILES=<List of firmware files to keep> \
	SQUASHFS_COMP=<Squashfs compression type>
```

The following `make(1)` variables are available to control the build
process:

- `PREFIX` is optional, it is set to `/usr/local` by default.  This is
  the prefix under which the guest's file system will be constructed,
  in the `share/wifibox/guest` sub-directory.  It is possible to set
  the `LOCALBASE` variable as well to tell if the prefix under which
  various third-party utilities, such as `git` and `mksquashfs` were
  installed is different.

- `MINIROOTFS` should point to the Alpine minimal root file system
  tarball for the `x86_64` architecture, which is going to be used in
  the bootstrapping phase.  Such tarballs can be retrieved from the
  Alpine Linux [web site](https://alpinelinux.org/downloads/).  By
  default, that is set to `alpine-minirootfs.tar.gz`.

- `PACKAGES` should tell which Alpine Linux packages to install for
  the guest.  Those are all must be local files with the `.apk`
  extension.  By default, that is `*.apk`, which means that all
  available packages are looked up in the current directory and
  utilized during the installation process.

- `BOOT_SERVICES` should specify which [OpenRC] services have to be
  launched on booting the guest.  They greatly depend on what the
  installed packages provide.

- `DEFAULT_SERVICES` should set which services are launched by
  default.  Their actual set depends on the contents of the installed
  packages.

- `SYSINIT_SERVICES` should tell which services are launched as part
  of the guest system initialization phase, along with the kernel.
  They have to be sync with the installed packages.

- `ETC_SRCS` should point to a location where the guest's generic
  configuration files could be found.  This helps to choose between
  application-specific configuration defaults.  Currently, such files
  are offered for `wpa_supplicant` and `hostapd`, see the `etc`
  directory in the repository.

- `EXTRA_VIRTFS_MOUNTS` can optionally contain information about
  further 9P/VirtFS entries for the guest's `/etc/fstab` file.  First,
  the VirtFS share has to be named, which is then followed by the
  location where it should be mounted in the guest.  These are
  separated by a `:`, visually:

	  share:/target/directory

- `FIRMWARE_FILES` is to tell which exact firmware files to keep to
  reduce further the size of the disk image.  It is optional, mostly
  recommended in case of `iwlwifi`.

- `SQUASHFS_COMP` configures the compression method used for building
  the Squashfs file system.  By default, that is the rather
  conservative `lzo` setting, but `lz4`, `gzip`, `xz`, and `zstd` are
  also available.

Besides these, it is considered that a directory named `guest` might
be present for holding further files and directories that shall be
added to the virtual disk image, under its root.

## Documentation

There is a manual page available that describes how the guest can be
used once installed.

```console
# man wifibox-alpine
```

[FreeBSD Wifibox]: https://github.com/pgj/freebsd-wifibox
[Alpine Linux]: https://alpinelinux.org/
[SquashFS Tools NG]: https://infraroot.at/projects/squashfs-tools-ng/
[GNU Tar]: https://www.gnu.org/software/tar/
[PatchELF]: https://github.com/NixOS/patchelf
[Linuxulator]: https://docs.freebsd.org/en/books/handbook/linuxemu/
[freebsd-wifibox-port]: https://github.com/pgj/freebsd-wifibox-port/
[OpenRC]: https://github.com/OpenRC/openrc
