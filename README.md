# FreeBSD Wifibox/Alpine

The purpose of this repository is to maintain all the configuration
files and scripts that are used for rolling out a [FreeBSD Wifibox]
guest based on [Alpine Linux] on top of its vanilla distribution.

## Warning

*This is a work-in-progress experimental software project without any
guarantees or warranties.  It is shared in the hope that is going to
be useful and inspiring for others.*

## Installation

Whenever possible, use the `net/wifibox-alpine` FreeBSD port from the
[freebsd-wifibox-port] repository, which aims to automate the tasks
described below and offers proper removal of the install files.

### Manual Installation

There is a `Makefile` present in the root of the repository that could
be used to drive the installation process.  It is mostly recommended
for development and testing.

```console
# make install PREFIX=<prefix>
```

The `PREFIX` variable is optional, it is set to `/usr/local` by
default.  This is the prefix under which the guest's file system will
be constructed, in the `share/wifibox/guest` sub-directory.

## Documentation

There is a manual page available that describes how the guest can be
used once installed.

```console
# man wifibox-alpine
```

[FreeBSD Wifibox]: https://github.com/pgj/freebsd-wifibox
[Alpine Linux]: https://alpinelinux.org/
[freebsd-wifibox-port]: https://github.com/pgj/freebsd-wifibox-port

