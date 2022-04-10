# FreeBSD Wifibox/Alpine

The purpose of this repository is to maintain all the configuration
files and scripts that are used for rolling out a [FreeBSD Wifibox]
guest based on [Alpine Linux].

## Warning

*This is a work-in-progress experimental software project without any
guarantees or warranties.  It is shared in the hope that is going to
be useful and inspiring for others.*

## Prerequisites

For building the virtual disk image, the following third-party
software is employed, which must be installed beforehand.

- [Squashfs-tools] or the `sysutils/squashfs-tools` FreeBSD package.
- [PatchELF] or the `sysutils/patchelf` FreeBSD package.

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

- `FIRMWARE_FILES` is tell which exact firmware files to keep to
  reduce further the size of the disk image.  It is optional, mostly
  recommended in case of `iwlwifi`.

- `SQUASHFS_COMP` configures the compression method used for building
  the Squashfs file system.  By default, that is the rather
  conservative `lzo` setting, but `lz4`, `gzip`, `xz`, and `zstd` are
  also available.

Besides these, it is considered that the `guest/lib/firmware`
directory may be present for holding further firmware files that shall
be added to the virtual disk image, under `/lib/firmware`.

## Documentation

There is a manual page available that describes how the guest can be
used once installed.

```console
# man wifibox-alpine
```

[FreeBSD Wifibox]: https://github.com/pgj/freebsd-wifibox
[Alpine Linux]: https://alpinelinux.org/
[Squashfs-tools]: https://github.com/plougher/squashfs-tools
[PatchELF]: https://github.com/NixOS/patchelf
[freebsd-wifibox-port]: https://github.com/pgj/freebsd-wifibox-port/tree/squashfs-root

