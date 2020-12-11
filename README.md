# Container Conjurer (conconj): containers with Docker and dedicated IP address support on Linux

Container Conjurer (conconj) is a Linux command-line tool to start and manage containers. It's built on top of systemd tools systemd-nspawn and machinectl. It adds the ability to run Docker (including dockerd) within the container and easy-to-configure dedicated IP address support (optional) for each container, and it works around and hides compatibility issues with older systemd version.

Advantages over systemd-nspawn:

* conconj containers are able to run Docker (both docker and dockerd).
* conconj containers can have a a dedicated IP address visible to the host, each other and other computers on the network.
* conconj containers can run in single-user mode (shell, PID 1 is an /interactive bin/sh) or multiuser mode (usually systemd), and it's convinient to get a root shell either way.
* conconj containers have networking even in single-user mode (shell).
* conconj works on older Linux systems, e.g. Debian 8 and Ubuntu 16.06.
* conconj works around compatibility issues with different versions of systemd, and works equivalently on old and new host operating systems.
* conconj detects the DNS servers used by the host better, and propagates this info better to the container.

Host requirements:

* Linux system running a recent amd64 kernel.
* Linux system running systemd. (This is a requirement of systemd-nspawn.)
* systemd-nspwan. (On Debian/buntu: sudo apt-get install systemd-container) Minimum version which is known to work is systemd 215.

Operating system compatibility on host:

* Ubuntu 14.04: It doesn't work, because the OS doesn't have systemd-nspawn. The OS has systemd-204, but only parts are installed, the OS doesn't have systemd-sysv.
* Ubuntu 16.04: It works with patch_nspawn.pl for systemd 229.
* Ubuntu 18.04: It works. It has systemd 237.
* Ubuntu 20.04: It works.
* Debian 7: It doesn't work, because the OS has systemd 44 available, which is too old, and systemd-nspawn doesn't have some important flags (e.g. --bind). By default, systemd isn't even installed, and installing it to Debian 7 is dangerous.
* Debian 8: It works, with patch_nspawn.pl for systemd 215, Limitations: network doesn't work over wifi (silently drops everything, even packets within host and container, this is because there is no ipvlan support), no shell when the container is already running (use login instead after `... shell ... /usr/bin/passwd root').
* Debian 9: It works, with patch_nspawn.pl for systemd 232.
* Debian 10: It works.

Similar software:

* [Sysbox](https://github.com/nestybox/sysbox) can also run systemd, Docker and Kubernetes in a container. It provides much better isolation than *conconj*, but it requires a [recent Linux kernel](https://github.com/nestybox/sysbox/blob/master/docs/distro-compat.md) (>=5.4).
* Docker can run Docker (and dockerd), see the *old-fashioned way* in [this article](https://medium.com/faun/docker-in-docker-the-real-one-e54133639c55). See also the [original article](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/).
* *runc* isn't able to run systemd, see [this bug](https://github.com/opencontainers/runc/issues/2703).
