# Container Conjurer (conconj): containers with Docker and dedicated IP address support on Linux

Container Conjurer (conconj) is a Linux command-line tool to start and manage containers. It's built on top of systemd tools systemd-nspawn and machinectl. It adds the ability to run Docker (including dockerd) within the container and easy-to-configure dedicated IP address support (optional) for each container, and it works around and hides compatibility issues with older systemd versions.

Advantages over systemd-nspawn:

* conconj containers are able to run Docker (both docker and dockerd).
* conconj containers can have a a dedicated IP address visible to the host, each other and other hosts on the network.
* conconj containers can run in single-user mode (shell, PID 1 is an /interactive bin/sh) or multiuser mode (usually systemd), and it's convinient to get a root shell either way.
* conconj containers have networking even in single-user mode (shell).
* conconj works on hosts running an older Linux system, e.g. Debian 8 and Ubuntu 16.06.
* conconj works around compatibility issues with different versions of systemd, and works equivalently on old and new host operating systems.
* conconj detects the DNS servers used by the host better, and propagates this info better to the container.
* conconj starts containers in the background
* (disadvantage) no easy way to automate conconj container startup at system startup time

## Tutorial

Download conconj (run without leading `$`s):

```
$ cd ~/Downloads
$ wget -nv -O conconj-master.zip https://github.com/pts/conconj/archive/master.zip
...
$ unzip -o conconj-master.zip
...
$ cd conconj-master
$ ./conconj
...
```

Download and install stretch (Debian 9) to a container filesystem (rootfs) (it takes a few minutes):

```
$ ./conconj pts-debootstrap mydeb9 stretch
...
```

Start the container:

```
$ ./conconj start mydeb9
...
```

Run a command:

```
$ ./conconj shell mydeb9 /bin/ping example.org
Connected to machine mydeb9. Press ^] three times within 1s to exit session.
PING example.org (93.184.216.34) 56(84) bytes of data.
64 bytes from 93.184.216.34 (93.184.216.34): icmp_seq=1 ttl=53 time=245 ms
64 bytes from 93.184.216.34 (93.184.216.34): icmp_seq=3 ttl=53 time=277 ms
^C
...
```

Stop the container:

```
$ ./conconj stop mydeb9
...
```

Similarly, download iand install xenial (Ubuntu 16.04) to a container filesystem (rootfs):

```
$ ./conconj pts-debootstrap myub164 xenial
...
```

Run a command even if the container is not running (also works if the container is Debian above):

```
$ ./conconj shell myub164 /bin/ping example.org
Spawning container myub164 on /home/pts/Downloads/conconj/myub164.container/rootfs.
Press ^] three times within 1s to kill container.
PING example.org (93.184.216.34) 56(84) bytes of data.
64 bytes from 93.184.216.34: icmp_seq=1 ttl=53 time=161 ms
64 bytes from 93.184.216.34: icmp_seq=2 ttl=53 time=134 ms
^C
...
```

## Requirements and compatibility

Host requirements:

* Linux system running a recent amd64 kernel.
* Linux system running systemd. (This is a requirement of systemd-nspawn.)
* systemd-nspwan. (On Debian/buntu: sudo apt-get install systemd-container) Minimum version which is known to work is systemd 215.

Operating system compatibility on the host:

* Ubuntu 14.04: It doesn't work. It has package for systemd 204 containing systemd-nspawn, but not machinectl or systemd-run. By default Ubuntu 14.04 uses upstart (rather than systemd or sysvinit), only parts of systemd are installed.
* Ubuntu 16.04: It works with patch_nspawn.pl for systemd 229.
* Ubuntu 18.04: It works. It has systemd 237.
* Ubuntu 20.04: It works. It has systemd 245.4.
* Debian 7: It doesn't work, because the OS has systemd 44 available, which is too old, and systemd-nspawn doesn't have some important flags (e.g. --bind). By default, systemd isn't even installed, and installing it to Debian 7 is dangerous.
* Debian 8: It works, with patch_nspawn.pl for systemd 215, Limitations: network doesn't work over wifi (silently drops everything, even packets within host and container, this is because there is no ipvlan support), no shell when the container is already running (use login instead), shell appeared in systemd 224).
* Debian 9: It works, with patch_nspawn.pl for systemd 232.
* Debian 10: It works. It has systemd 241.

Operating system compatibility in the container:

* Alpine Linux 3.12 (and earlier): It works, but the shell and login commands don't work after the container has been started (because it doesn't have systemd).
* Ubuntu 14.04: It works, but the stop command is slow in the background (it takes more than 10 seconds for upstart to halt gracefully), and the shell and login command don't work after the container has been started (because systemd 204 is too old).
* Ubuntu 16.04: It works.
* Ubuntu 18.04: It works.
* Ubuntu 20.04: It works.
* Debian 7: It works, but the stop command is a bit slow (3 seconds) (it takes 3 seconds for sysvinit to halt gracefully), and the shell command doesn't work after the container has been started (because it doesn't have systemd).
* Debian 8: It works, but the shell command doesn't work after the container has been started (because systemd 215 is too old), use the login command instead.
* Debian 9: It works.
* Debian 10: It works.

To use the login command and log in successfully, first you have to set the password for the user root. To do so, stop the container (`conconj stop CONTAINER`), change the password with `conconj shell CONTAINER /usr/bin/passwd root`, then start the container (`conconj start CONTAINER`), and then log in again (`conconj login CONTAINER`).

## Networking

Only IPv4 and Unix domain socket networking is supported in the containers. On IPv4, unicast, broadcast and multicast are supported.

**TL;DR** If you have some free IP addresses on your local network (called *hostnet* below), then use *hostnet* mode for your containers (with a dedicated IP address each), otherwise use *localnet* mode with *forwarding* enabled.

Networks:

* The *loopback* network contains IP addresses 127.0.0.0/8, with localhost being 127.0.0.1. It also has the network device *lo*. Except for containers in *shared* mode (see below), the host and each container has its own loopback network.

* The *hostnet* network is the network containing the host, with the default route. conconj can add containers to the hostnet network, each with their own, dedicated IP address. (This is implemented by network devices of type *ipvlan mode l2* (preferred) or *macvlan*.) Other hosts on the hostnet network can also connect to containers on the hostnet network.

* The *localnet* network is a virtual network created by conconj, initially containing the host only. conconj can add containers to the localnet network, each with their own IP address. (This is implemented by a network bridge and network devices of type *veth*.) Other hosts can't connect to containers on the localnet network. As a global setting, *forwarding* may be enabled or disabled on the localnet network. Forwarding is implemented by netfilter (iptables), and it also includes network address translation (NAT, `-j MASQUERADE`) wherever needed.

Each container can be started in one of the following container networking modes:

* *private*: Apart from its own loopback network, the container isn't connected to any network. To configure it, write the word *private* to the *ipaddr* file of the container.

* *shared*: The container shares the networking (all devices) of the host. Thus it's impossible for two machines (host or container) on the shared network to listen on the same (IP-address, port) pair. The loopback network is also shared. To configure it, write the word *shared* to the *ipaddr* file of the container.

* *hostnet*: The container is connected to the hostnet network (with bidirectional connectivity to the host, other hosts and other containers on the hostnet network) with a dedicated IP address. It also has it's own loopback network. If forwarding is enabled, there is additional connectivity from hostnet containers to localnet containers, see below. To configure it, write the dedicated IP address of the container to the *ipaddr* file of the container; also reserve a helper IP address for the host (must be on the same network, but different from the real one), and write it to the *conconj.hostnet* file.

* *localnet*: The container is connected to the localnet network (with bidirectional connectivity to the host and other containers on the localnet network). It also has it's own loopback network. If forwarding is enabled, there is additional connectivity for these containers, see below. To configure it, write *local.X* of the container to the *ipaddr* file of the container, where *X* is the last byte of the IP address of the designated IP address of the container; also reserve a helper IP address for the host (must be on a different network than the real one, will be on a /24 network), and write it to the *conconj.localnet* file; to enable forwading, write *1* to the *conconj.localfwd* file.

Machine legend for the connectivity matrix below:

* H is the host, it's on the hostnet and localnet networks
* OH is another host on the hostnet network
* IH is a host on the internet (e.g. Debian package repository, Docker Hub)
* PC is a container started in private networking mode
* SC is a container started in shared networking mode, it's on the hostnet and localnet networks
* HC is a container started in hostnet networking mode, it's on the hostnet network
* LC is a container started in localnet networking mode with forwarding disabled globally, it's on the localnet network
* FC is a container started in localnet networking mode with forwarding eanbled globally, it's on the localnet network

Connectivity matrix (e.g. for new TCP connections and pings):

|             | to H  | to OH | to IH | to PC | to SC | to HC | to LC | to FC |
| ----------- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| **from H**  | yes   | yes   | yes   | no    | yes   | yes   | yes   | yes   |
| **from OH** | yes   | yes   | yes   | no    | yes   | yes   | no    | no    |
| **from IH** | maybe | maybe | maybe | no    | maybe | maybe | no    | no    |
| **from PC** | no    | no    | no    | no    | no    | no    | no    | no    |
| **from SC** | yes   | yes   | yes   | no    | yes   | yes   | yes   | yes   |
| **from HC** | yes   | yes   | yes   | no    | yes   | yes   | no    | yes   |
| **from LC** | yes   | no    | no    | no    | yes   | no    | yes   | n/a   |
| **from FC** | yes   | yes   | yes   | no    | yes   | yes   | n/a   | yes   |

For convenience, at container startup, the entries for hostnames *localhost* (always points to 127.0.0.1) and *host* (points to an IP address of the host visible from the container) are updated in `/etc/hosts`, thus `ping host` will always work. DNS settings are copied from the host, thus they work as usual (except in containers in private networking mode). Containers are currently identified by their IP addresses; to make it more convenient, you can add entries to */etc/hosts* (on the host and in containers) manually.

Typical networking setup at home:

* Let's suppose that your home network is 192.168.0.0/24, with IP addresses 192.168.0.100 ... 192.168.0.254 automatically assigned via DHCP by the router.
* Let's suppose that the host has IP address 192.168.0.140, and connects to the network over wifi.
* For hostnet, you assign the helper IP address 192.168.0.80 to the host (the *conconj.hostnet* file contains: *192.168.0.80*), and 192.168.0.81 ... 192.168.0.99 to containers on the hostnet network (an example *ipaddr* file contains: *192.168.0.81*).
* For localnet, you choose 192.168.66.0/24, and you assign the helper IP address 192.168.66.1 to the host (the *conconj.localnet* file contains: *192.168.66.1*), and 192.168.66.2 ... 192.168.66.254 to containers on the localnet network (an example *ipaddr* file contains: *local.2*). To make `apt-get install ...` work in the containers, you enable forwarding (the *conconj.localfwd* file contains *1*).

## Similar software

* [Sysbox](https://github.com/nestybox/sysbox) can also run systemd, Docker and Kubernetes in a container. It provides much better isolation than *conconj*, but it requires a [recent Linux kernel](https://github.com/nestybox/sysbox/blob/master/docs/distro-compat.md) (>=5.4).
* Docker can run Docker (and dockerd), see the *old-fashioned way* in [this article](https://medium.com/faun/docker-in-docker-the-real-one-e54133639c55). See also the [original article](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/).
* *runc* isn't able to run systemd, see [this bug](https://github.com/opencontainers/runc/issues/2703).
