# Redhat Openstack 10 deployment and Intergration with ScaleIO

During the openstack deployment, i will cater for OVS-DPDK as virtual forwarding plane with Neutron. And we will deploy a full DellEMC software defined storage ScaleIO in two modes:
1. Two tiers => dedicated storage node
2. hypered-converged where compute node will be a storage nodes as well

## Getting Started

These instructions will reflect the RHOSP10 on a CIP blueprint along with scaleIO integration with cinder volume.

### Network Prerequisites

   Seq  | Name | Network Address | VLAN_ID | Switch
------------- | ------------- | ------------- | ------------- | -------------
1  | Public/Floating/IPMI Network  | 172.17.84.0/24| 3084 | mgmt/Global
2  | Undercloud Private  | 10.30.100.0/24 | 100 | mgmt/Internal
3 | Internal network | 10.30.200.0/24 | 200 | ToR Switches/Internal
4| Tenant network | 10.30.201.0/24 | 201 | ToR Switches/Internal
5| Storage network | 10.30.202.0/24 | 202 | ToR Switches/Internal
6| Storage management | 10.30.203.0/24 | 203 | ToR Switches/Internal
7 | Data network01 | 10.30.220.0/24 | 220 | ToR Switches/Internal
8 | Data Network02 | 10.30.221.0/24 | 221 | ToR Switches/Internal
9 | Data Network Range | | 220:230 |ToR Switches/Internal	


> Network Topology
> ![](https://i.imgur.com/xt5TWOT.png)
### Installation

A step by step deployment

> **Undercloud Preparation** 
```
[root@undercloud ~]# hostname
undercloud.sio.lab
[root@undercloud ~]# more  /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
172.17.84.10            undercloud.sio.lab undercloud
172.17.84.6             siorhn.sio.lab  siorhn

[root@undercloud ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 00:50:56:92:c8:b8 brd ff:ff:ff:ff:ff:ff
    inet 172.17.84.10/24 brd 172.17.84.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe92:c8b8/64 scope link
       valid_lft forever preferred_lft forever
3: ens34: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 00:50:56:92:53:0f brd ff:ff:ff:ff:ff:ff
    inet 10.30.100.2/24 brd 10.30.100.255 scope global ens34
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe92:530f/64 scope link
       valid_lft forever preferred_lft forever
[root@undercloud ~]# ls  -ltr  /etc/yum.repos.d/
total 8
-rw-r--r--. 1 root root  358 Nov 19 12:38 redhat.repo
-rw-r--r--  1 root root 1547 Dec  4 05:03 mylocalrepo.repo
[root@undercloud ~]# more  /etc/yum.repos.d/mylocalrepo.repo
[MoeLocal-server-openstack10]
name=vlab Repo-RHOPS10
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-openstack-10-rpms
enabled=1
gpgcheck=0

[MoeLocal-server-extras]
name=vlab Repo-extras
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-extras-rpms
enabled=1
gpgcheck=0

[MoeLocal--server-rh-common]
name=vlab Repo-common
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-rh-common-rpms
enabled=1
gpgcheck=0

[MoeLocal-server]
name=vlab Repo-server
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-rpms
enabled=1
gpgcheck=0

[MoeLocal-server-satellite-tools]
name=vlab Repo-sattool
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-satellite-tools-6.2-rpms
enabled=1
gpgcheck=0

[MoeLocal-ha-for-rhel-7-server]
name=vlab Repo-HA
baseurl=http://siorhn.sio.lab/repo/repos/rhel-ha-for-rhel-7-server-rpms
enabled=1
gpgcheck=0

[MoeLocal-openstack-10-devtools]
name=vlab devtools
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-openstack-10-devtools-rpms
enabled=1
gpgcheck=0

[MoeLocal-ceph-mon]
name=vlab Repo-Ceph-Mon
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-rhceph-2-mon-rpms
enabled=1
gpgcheck=0

[MoeLocal-ceph-tools]
name=vlab Repo-CEPH-Tools
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-rhceph-2-tools-rpms
enabled=1
gpgcheck=0

[MoeLocal-NFV]
name=vlab Repo-NFV
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-nfv-rpms
enabled=1
gpgcheck=0

[MoeLocal-rhel-optional]
name=vlab Repo-RHEL-Optional
baseurl=http://siorhn.sio.lab/repo/repos/rhel-7-server-optional-rpms
enabled=1
gpgcheck=0

[root@undercloud ~]# more  /etc/selinux/config

# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=permissive
# SELINUXTYPE= can take one of three two values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
```


And reboot

> **Undercloud Installation** 

Refer to the redhat openstack documentation, link is shown below (Chanpter 4):
[https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/10/html-single/director_installation_and_usage/](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/10/html-single/director_installation_and_usage/ "RHOPS10 Undercloud deployment")

1. Install the Director Packages
```
[stack@undercloud ~]$ sudo yum install -y python-tripleoclient
..
..
..
[Truncated]
..

Complete!

```
2. Configure the Director
The director installation process requires certain settings to determine your network configurations. The settings are stored in a template located in the stack user’s home directory as undercloud.conf
```
[stack@undercloud ~]$ cp /usr/share/instack-undercloud/undercloud.conf.sample ~/undercloud.conf
```
a modified version the undercloud.conf is shown hereunder:
```
[stack@undercloud ~]$ egrep  -v "^$|#" undercloud.conf
[DEFAULT]
local_ip = 172.17.84.10/24
network_gateway = 172.17.84.254
undercloud_public_vip = 172.17.84.20
undercloud_admin_vip = 172.17.84.21
local_interface = ens33
network_cidr = 172.17.84.0/24
masquerade_network = 172.17.84.0/24
dhcp_start = 172.17.84.45
dhcp_end = 172.17.84.79
inspection_iprange = 172.17.84.100,172.17.84.120
enable_ui = true
[auth]
undercloud_admin_password = Dell@123

[stack@undercloud ~]$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.17.84.254   0.0.0.0         UG        0 0          0 ens33
10.30.100.0     0.0.0.0         255.255.255.0   U         0 0          0 ens34
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens34
172.17.84.0     0.0.0.0         255.255.255.0   U         0 0          0 ens33
```
deploy the undercloud by running the below command, using the undercloud.conf file
```
[stack@undercloud ~]$ openstack undercloud install
..
..
..
[Truncated]
..
dib-run-parts Mon Dec  4 11:35:39 EST 2017 99-refresh-completed completed
dib-run-parts Mon Dec  4 11:35:39 EST 2017 ----------------------- PROFILING -----------------------
dib-run-parts Mon Dec  4 11:35:39 EST 2017
dib-run-parts Mon Dec  4 11:35:39 EST 2017 Target: post-configure.d
dib-run-parts Mon Dec  4 11:35:39 EST 2017
dib-run-parts Mon Dec  4 11:35:39 EST 2017 Script                                     Seconds
dib-run-parts Mon Dec  4 11:35:39 EST 2017 ---------------------------------------  ----------
dib-run-parts Mon Dec  4 11:35:39 EST 2017
dib-run-parts Mon Dec  4 11:35:39 EST 2017 10-iptables                                   0.025
dib-run-parts Mon Dec  4 11:35:39 EST 2017 80-seedstack-masquerade                       0.029
dib-run-parts Mon Dec  4 11:35:39 EST 2017 98-undercloud-setup                          27.322
dib-run-parts Mon Dec  4 11:35:39 EST 2017 99-refresh-completed                          0.407
dib-run-parts Mon Dec  4 11:35:39 EST 2017
dib-run-parts Mon Dec  4 11:35:39 EST 2017 --------------------- END PROFILING ---------------------
[2017-12-04 11:35:39,483] (os-refresh-config) [INFO] Completed phase post-configure
os-refresh-config completed successfully
Generated new ssh key in ~/.ssh/id_rsa
Created flavor "baremetal" with profile "None"
Created flavor "control" with profile "control"
Created flavor "compute" with profile "compute"
Created flavor "ceph-storage" with profile "ceph-storage"
Created flavor "block-storage" with profile "block-storage"
Created flavor "swift-storage" with profile "swift-storage"

#############################################################################
Undercloud install complete.

The file containing this installation's passwords is at
/home/stack/undercloud-passwords.conf.

There is also a stackrc file at /home/stack/stackrc.

These files are needed to interact with the OpenStack services, and should be
secured.

#############################################################################
```
## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc

