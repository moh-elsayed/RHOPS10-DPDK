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
2  | Undercloud Deployment  | 10.30.100.0/24 | 100 | mgmt/Internal
3 | Internal network | 10.30.200.0/24 | 200 | ToR Switches/Internal
4| Tenant network | 10.30.201.0/24 | 201 | ToR Switches/Internal
5| Storage network | 10.30.202.0/24 | 202 | ToR Switches/Internal
6| Storage management | 10.30.203.0/24 | 203 | ToR Switches/Internal
7 | Data network01 | 10.30.220.0/24 | 220 | ToR Switches/Internal
8 | Data Network02 | 10.30.221.0/24 | 221 | ToR Switches/Internal
9 | Data Network Range | | 220:230 |ToR Switches/Internal	
> Note:
> Undercloud deployment network must be untagged network:
> Since i'm using a single 1G interface for my External public network and undercloud deployment network. So VLAN 100 must be untagged and VLAN3084 should be tagged on the Dell management switch. to do that, follow the steps below:
> ```
> ** Show the running configuration for one of the ports **
> 
> $ R3R5-Perimeter/TOR(conf-if-te-1/6)#do show running-config interface tengigabitethernet 1/6
> $ !
> $ interface TenGigabitEthernet 1/6
> $  no ip address
> $  portmode hybrid
> $  switchport
> $  spanning-tree rstp edge-port bpduguard shutdown-on-violation
> $  spanning-tree rstp rootguard
> $  storm-control broadcast 1 in
> $  storm-control unknown-unicast 1 in
> $  storm-control multicast 1 in
> $  no shutdown
>          
> ** Clear the port configuration in order to be able to set the port mode to hybird **
> 
> $ interface tengigabitethernet 1/6
> $ no spanning-tree rstp edge-port bpduguard shutdown-on-violation
> $ no spanning-tree rstp rootguard
> $ no storm-control broadcast 1 in 
> $ no storm-control unknown-unicast 1 in
> $ no storm-control multicast 1 in 
> $ no switchport
> 
> ** Set the correct port configuration**
> 
> $ portmode hybrid
> $ switchport
> $ spanning-tree rstp edge-port bpduguard shutdown-on-violation
> $ spanning-tree rstp rootguard
> $ storm-control broadcast 1 in
> $ storm-control unknown-unicast 1 in
> $ storm-control multicast 1 in
> $ no shut
> 
> ** Set the VLAN information on all ports **
> 
> $ interface Vlan 3084
> $ tagged tengigabitethernet 1/6,1/8,1/10,1/12,1/14,1/16,1/32,1/34,1/36,1/38,1/40,1/42
> $ interface Vlan 100
> $ untagged tengigabitethernet 1/6,1/8,1/10,1/12,1/14,1/16,1/32,1/34,1/36,1/38,1/40,1/42
> ```

### Physical Hardware
   Seq  | Server Role | Model | Storage | Deployment NIC
------------- | ------------- | ------------- | ------------- | -------------
1  |Controller  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E7:FC:24
2 | Controller  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:03:54
3 | Controller  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:02:24
4 | Compute  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:03:5C
5 | Compute  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E7:FC:4C
6 | Compute  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:03:A4
7 | Ceph  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:DA:B4
8 | Ceph  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:DF:8C
9 | Ceph  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E7:FC:74
10 | ScaleIO_SDS  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E7:F8:3C
11 | ScaleIO_SDS  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:03:74
12 | ScaleIO_SDS  | Dell R730 | 2 x 400 SSD & 4 x 1 TB | EC:F4:BB:E8:03:8C

> Rack-Layout:

![](https://i.imgur.com/MQRm0IS.png)

> Server Port assignment:

![](https://i.imgur.com/JCB0GCO.png)

> ToR Topology:

![](https://i.imgur.com/IeQxQW0.png)

> ToR port assignment:

![](https://i.imgur.com/CqFqqrt.png)

Leaf Switches preparation

```
conf t
interface range tengigabitethernet 1/1-1/48
portmode hybrid
switchport
speed auto
no shut
exit

#VLANs: VMware:#
=============
interface vlan 200
description "vMotion-InternalRedhatOSP"
tagged tengigabitethernet 1/1-1/48
interface vlan 300
description "vSAN-ScaleIO"
tagged tengigabitethernet 1/1-1/48
interface vlan 400
description "VM-Replication"
tagged tengigabitethernet 1/1-1/48
interface vlan 500
description "NFV-mgmt"
tagged tengigabitethernet 1/1-1/48
interface vlan 600
description "NFV-Ext"
tagged tengigabitethernet 1/1-1/48
description "VM-VxLAN"
interface vlan 700
description "NFV-Ext"
tagged tengigabitethernet 1/1-1/48
exit

#leaf-Spine:#
==============
interface fortyGigE 1/50
shut
interface fortyGigE 1/52
shut
exit

interface fortyGigE 1/49
switchport
no shut
interface fortyGigE 1/51
switchport
no shut
exit

interface vlan 200
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 300
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 400
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 500
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 600
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 700
tagged fortyGigE 1/49
tagged fortyGigE 1/51
exit

Leaf-Leaf: Shutdown
==============
interface fortyGigE 1/53
shut
interface fortyGigE 1/54
shut
exit

VLANs: Openstack
=============
interface vlan 201
description "Tenant-Network"
tagged tengigabitethernet 1/1-1/48
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 202
description "Storage-Network"
tagged tengigabitethernet 1/1-1/48
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 203
description "Storage-mgmt"
tagged tengigabitethernet 1/1-1/48
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 220
description "Data-Network01"
tagged tengigabitethernet 1/1-1/48
tagged fortyGigE 1/49
tagged fortyGigE 1/51
interface vlan 221
description "Data-Network02"
tagged tengigabitethernet 1/1-1/48
tagged fortyGigE 1/49
tagged fortyGigE 1/51

do wr
do show interfaces status
```
Spine Switches preparation

```
conf t
interface range fortyGigE 1/7-1/14
switchport
no shut


interface vlan 200
description "vMotion-InternalRedhatOSP"
tagged fortyGigE 1/7-1/14
interface vlan 300
description "vSAN-ScaleIO"
tagged fortyGigE 1/7-1/14
interface vlan 400
description "VM-Replication"
tagged fortyGigE 1/7-1/14
interface vlan 500
description "NFV-mgmt"
tagged fortyGigE 1/7-1/14
interface vlan 600
description "NFV-Ext"
tagged fortyGigE 1/7-1/14
description "VM-VxLAN"
interface vlan 700
description "NFV-Ext"
tagged fortyGigE 1/7-1/14
exit


interface vlan 201
description "Tenant-Network"
tagged fortyGigE 1/7-1/14
interface vlan 202
description "Storage-Network"
tagged fortyGigE 1/7-1/14
interface vlan 203
description "Storage-mgmt"
tagged fortyGigE 1/7-1/14
interface vlan 220
description "Data-Network01"
tagged fortyGigE 1/7-1/14
interface vlan 221
description "Data-Network02"
tagged fortyGigE 1/7-1/14
do wr
exit

```

### Virtual Machine
The entire virtual machines are running on tope ESXi R730 server. 

   Seq  | VM Role | OS | vCPU | RAM
------------- | ------------- | ------------- | ------------- | -------------
1 | Redhat Undercloud  | RHEL7.3 | 6 | 14G
2 | Domain Controller | Windows 2012 | 4 | 4G
3 | Local Repo server  | RHEL7.3 | 4 | 2G
4 | ScaleIO Gateway | RHEL7.3 | 4 | 4G

> Solution Logical Diagram
> ![](https://i.imgur.com/EBByxXy.png)
In case of HCI "Hyper-Converged Infrastructure, SDS will be co-exist with the SDC on the compute nodes.

## Deployment Guide
### Undercloud

A step by step deployment

> **Undercloud Preparation** 
```
[root@undercloud ~]# more  /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
172.17.84.10            undercloud.sio.lab undercloud
172.17.84.6             siorhn.sio.lab  siorhn
#192.0.2.6              siorhn.sio.lab  siorhn

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
    inet 192.0.2.10/24 brd 192.0.2.255 scope global ens34
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe92:530f/64 scope link
       valid_lft forever preferred_lft forever

[root@undercloud ~]# netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.17.84.254   0.0.0.0         UG        0 0          0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens34
172.17.84.0     0.0.0.0         255.255.255.0   U         0 0          0 ens33
192.0.2.0       0.0.0.0         255.255.255.0   U         0 0          0 ens34


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

[root@undercloud ~]# reboot
```


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
local_ip = 192.0.2.1/24
network_gateway = 192.0.2.1
undercloud_public_vip = 192.0.2.2
undercloud_admin_vip = 192.0.2.3
local_interface = ens34
network_cidr = 192.0.2.0/24
masquerade_network = 192.0.2.0/24
dhcp_start = 192.0.2.45
dhcp_end = 192.0.2.100
inspection_iprange = 192.0.2.101,192.0.2.120
enable_ui = true
[auth]
undercloud_admin_password = Dell@123

[root@undercloud ~]# netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.17.84.254   0.0.0.0         UG        0 0          0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens33
169.254.0.0     0.0.0.0         255.255.0.0     U         0 0          0 ens34
172.17.84.0     0.0.0.0         255.255.255.0   U         0 0          0 ens33
192.0.2.0       0.0.0.0         255.255.255.0   U         0 0          0 ens34
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

## Overcloud
### Overcloud Basic Configuration

We will got through a step by step verification in order to prepare for overcloud deployment

```
[stack@undercloud ~]$ sudo systemctl list-units openstack-*
UNIT                                       LOAD   ACTIVE SUB     DESCRIPTION
openstack-aodh-evaluator.service           loaded active running OpenStack Alarm evaluator service
openstack-aodh-listener.service            loaded active running OpenStack Alarm listener service
openstack-aodh-notifier.service            loaded active running OpenStack Alarm notifier service
openstack-ceilometer-central.service       loaded active running OpenStack ceilometer central agent
openstack-ceilometer-collector.service     loaded active running OpenStack ceilometer collection service
openstack-ceilometer-notification.service  loaded active running OpenStack ceilometer notification agent
openstack-glance-api.service               loaded active running OpenStack Image Service (code-named Glance) API server
openstack-glance-registry.service          loaded active running OpenStack Image Service (code-named Glance) Registry server
openstack-heat-api-cfn.service             loaded active running Openstack Heat CFN-compatible API Service
openstack-heat-api.service                 loaded active running OpenStack Heat API Service
openstack-heat-engine.service              loaded active running Openstack Heat Engine Service
openstack-ironic-api.service               loaded active running OpenStack Ironic API service
openstack-ironic-conductor.service         loaded active running OpenStack Ironic Conductor service
openstack-ironic-inspector-dnsmasq.service loaded active running PXE boot dnsmasq service for Ironic Inspector
openstack-ironic-inspector.service         loaded active running Hardware introspection service for OpenStack Ironic
openstack-mistral-api.service              loaded active running Mistral API Server
openstack-mistral-engine.service           loaded active running Mistral Engine Server
openstack-mistral-executor.service         loaded active running Mistral Executor Server
openstack-nova-api.service                 loaded active running OpenStack Nova API Server
openstack-nova-cert.service                loaded active running OpenStack Nova Cert Server
openstack-nova-compute.service             loaded active running OpenStack Nova Compute Server
openstack-nova-conductor.service           loaded active running OpenStack Nova Conductor Server
openstack-nova-scheduler.service           loaded active running OpenStack Nova Scheduler Server
openstack-swift-account-reaper.service     loaded active running OpenStack Object Storage (swift) - Account Reaper
openstack-swift-account.service            loaded active running OpenStack Object Storage (swift) - Account Server
openstack-swift-container-updater.service  loaded active running OpenStack Object Storage (swift) - Container Updater
openstack-swift-container.service          loaded active running OpenStack Object Storage (swift) - Container Server
openstack-swift-object-updater.service     loaded active running OpenStack Object Storage (swift) - Object Updater
openstack-swift-object.service             loaded active running OpenStack Object Storage (swift) - Object Server
openstack-swift-proxy.service              loaded active running OpenStack Object Storage (swift) - Proxy Server
openstack-zaqar.service                    loaded active running OpenStack Message Queuing Service (code-named Zaqar) Server
openstack-zaqar@1.service                  loaded active running OpenStack Message Queuing Service (code-named Zaqar) Server Instance 1

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
SUB    = The low-level unit activation state, values depend on unit type.

32 loaded units listed. Pass --all to see loaded but inactive units, too.
To show all installed unit files use 'systemctl list-unit-files'.

[stack@undercloud ~]$ source ~/stackrc

``` 

Refer to the below link to download the redhat openstack overcloud:
[https://access.redhat.com/downloads/content/191/ver=11/rhel---7/11/x86_64/product-software](https://access.redhat.com/downloads/content/191/ver=11/rhel---7/11/x86_64/product-software)

1) Ironic Python Agent Image for RHOSP 10.0.4
2) Overcloud Image for RHOSP 10.0.4

Extract the archives to the images directory on the stack user’s home (/home/stack/images): 
```
[stack@undercloud ~]$ source ~/stackrc
[stack@undercloud ~]$ cd images/
[stack@undercloud images]$ ll
total 1694128
-rw-r--r--. 1 stack stack  366536581 Jun 15 14:28 ironic-python-agent.initramfs
-rwxr-xr-x. 1 stack stack    5394912 Jun 15 14:28 ironic-python-agent.kernel
-rw-r--r--. 1 stack stack   53936058 Jun 15 15:12 overcloud-full.initrd
-rw-r--r--. 1 stack stack 1303512064 Jun 15 15:15 overcloud-full.qcow2
-rwxr-xr-x. 1 stack stack    5394912 Jun 15 15:12 overcloud-full.vmlinuz
[stack@undercloud images]$ openstack overcloud image upload --image-path /home/stack/images/
Image "overcloud-full-vmlinuz" was uploaded.
+--------------------------------------+------------------------+-------------+---------+--------+
|                  ID                  |          Name          | Disk Format |   Size  | Status |
+--------------------------------------+------------------------+-------------+---------+--------+
| 608af3de-128a-4f81-8d4f-b5ca98ac6262 | overcloud-full-vmlinuz |     aki     | 5394912 | active |
+--------------------------------------+------------------------+-------------+---------+--------+
Image "overcloud-full-initrd" was uploaded.
+--------------------------------------+-----------------------+-------------+----------+--------+
|                  ID                  |          Name         | Disk Format |   Size   | Status |
+--------------------------------------+-----------------------+-------------+----------+--------+
| 4eb48023-e865-49ce-a04c-4b90a1d43403 | overcloud-full-initrd |     ari     | 53936058 | active |
+--------------------------------------+-----------------------+-------------+----------+--------+
Image "overcloud-full" was uploaded.
+--------------------------------------+----------------+-------------+------------+--------+
|                  ID                  |      Name      | Disk Format |    Size    | Status |
+--------------------------------------+----------------+-------------+------------+--------+
| 94a4e0f2-4541-459a-9cba-3ccabb2f3e3c | overcloud-full |    qcow2    | 1303512064 | active |
+--------------------------------------+----------------+-------------+------------+--------+
Image "bm-deploy-kernel" was uploaded.
+--------------------------------------+------------------+-------------+---------+--------+
|                  ID                  |       Name       | Disk Format |   Size  | Status |
+--------------------------------------+------------------+-------------+---------+--------+
| 76a87244-66c8-4018-a10e-642711fa6948 | bm-deploy-kernel |     aki     | 5394912 | active |
+--------------------------------------+------------------+-------------+---------+--------+
Image "bm-deploy-ramdisk" was uploaded.
+--------------------------------------+-------------------+-------------+-----------+--------+
|                  ID                  |        Name       | Disk Format |    Size   | Status |
+--------------------------------------+-------------------+-------------+-----------+--------+
| 3a38bd3f-359e-4240-9d70-8c4ab13cc078 | bm-deploy-ramdisk |     ari     | 366536581 | active |
+--------------------------------------+-------------------+-------------+-----------+--------+

```

Add a nameserver to the undercloud neutron subnet:
```
[stack@undercloud images]$ openstack subnet list
+--------------------------------------+------+--------------------------------------+----------------+
| ID                                   | Name | Network                              | Subnet         |
+--------------------------------------+------+--------------------------------------+----------------+
| e07027e6-91a6-49f8-8247-0beb303eaa3d |      | 1b76f686-b92e-40b2-9390-cef258abd6d4 | 172.17.84.0/24 |
+--------------------------------------+------+--------------------------------------+----------------+
[stack@undercloud images]$ openstack subnet set --dns-nameserver 172.17.84.4 --dns-nameserver 8.8.8.8 e07027e6-91a6-49f8-8247-0beb303eaa3d
[stack@undercloud images]$ openstack subnet show e07027e6-91a6-49f8-8247-0beb303eaa3d
+-------------------+----------------------------------------------------------+
| Field             | Value                                                    |
+-------------------+----------------------------------------------------------+
| allocation_pools  | 172.17.84.45-172.17.84.79                                |
| cidr              | 172.17.84.0/24                                           |
| created_at        | 2017-12-04T16:35:18Z                                     |
| description       |                                                          |
| dns_nameservers   | 172.17.84.4, 8.8.8.8                                     |
| enable_dhcp       | True                                                     |
| gateway_ip        | 172.17.84.254                                            |
| host_routes       | destination='169.254.169.254/32', gateway='172.17.84.10' |
| id                | e07027e6-91a6-49f8-8247-0beb303eaa3d                     |
| ip_version        | 4                                                        |
| ipv6_address_mode | None                                                     |
| ipv6_ra_mode      | None                                                     |
| name              |                                                          |
| network_id        | 1b76f686-b92e-40b2-9390-cef258abd6d4                     |
| project_id        | 60ced212c3ae4d889323c41803f1eab4                         |
| project_id        | 60ced212c3ae4d889323c41803f1eab4                         |
| revision_number   | 3                                                        |
| service_types     | []                                                       |
| subnetpool_id     | None                                                     |
| updated_at        | 2017-12-05T15:28:07Z                                     |
+-------------------+----------------------------------------------------------+
```
Ironic service: is the baremetal service used by TripleO to bootstrap the overcloud nodes.
(/home/stack/instackenv.json) is a json template which contains the hardware and power management details for your nodes.

```
[stack@undercloud ~]$ openstack overcloud node import ~/instackenv.json
Started Mistral Workflow. Execution ID: f883f537-7d0d-4da8-8578-43a214926d00
Successfully registered node UUID 931bcdcf-85d9-459c-ac43-828cd779d140
Successfully registered node UUID 0687a312-e431-49d5-94e2-e278a9f9b541
Successfully registered node UUID ac71493d-c575-4e5a-8aef-dc376376bf97
Successfully registered node UUID 47fc4a92-8338-44e2-8d30-614f18da8d5c
Successfully registered node UUID b248739b-f79c-4d0e-b404-19831e40fbf4
Successfully registered node UUID a36835aa-4d9d-42ce-a80d-a576bcb8182e
Successfully registered node UUID e6327431-8571-4355-b095-fc52923d4031
Successfully registered node UUID 74b3376b-6a4e-4e8e-85e2-4032a15e0494
Successfully registered node UUID c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2


[stack@undercloud ~]$ openstack baremetal node list
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| 931bcdcf-85d9-459c-ac43-828cd779d140 | cont01 | None          | None        | enroll             | False       |
| 0687a312-e431-49d5-94e2-e278a9f9b541 | cont02 | None          | None        | enroll             | False       |
| ac71493d-c575-4e5a-8aef-dc376376bf97 | cont03 | None          | None        | enroll             | False       |
| 47fc4a92-8338-44e2-8d30-614f18da8d5c | comp01 | None          | power off   | manageable         | False       |
| b248739b-f79c-4d0e-b404-19831e40fbf4 | comp02 | None          | power off   | manageable         | False       |
| a36835aa-4d9d-42ce-a80d-a576bcb8182e | comp03 | None          | power off   | manageable         | False       |
| e6327431-8571-4355-b095-fc52923d4031 | ceph01 | None          | power off   | manageable         | False       |
| 74b3376b-6a4e-4e8e-85e2-4032a15e0494 | ceph02 | None          | power off   | manageable         | False       |
| c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 | ceph03 | None          | power off   | manageable         | False       |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+

[stack@undercloud log]$ ipmitool -I lanplus -H 172.17.84.5 -L ADMINISTRATOR -U root  power status
Password:
Error: Unable to establish IPMI v2 / RMCP+ session
```
As noticed above, i have three nodes in an enroll status: this status is due to failed IPMI communication:
1) Either password and username is incorrect.
2) Make sure IPMI Over LAN in the iDRAC settings. 
3) the iDrac version needs to be updated ( Driver issues )

In my case, my iDRAC driver was old and different than the other 6 servers. I have updated the nodes to the latest driver, using a bootable media, refer the below link for further details
[https://www.dell.com/support/article/us/en/04/sln156799/how-to-subscribe-to-receive-dell-driver-and-firmware-update-notifications?lang=en](https://www.dell.com/support/article/us/en/04/sln156799/how-to-subscribe-to-receive-dell-driver-and-firmware-update-notifications?lang=en)

![](https://i.imgur.com/N6mF7gf.png)

![](https://i.imgur.com/XtRFed8.png)

After driver update and configuration update:

```
[stack@undercloud ~]$ for node in $(openstack baremetal node list -c UUID -f value) ; do openstack baremetal node manage $node ; done
The requested action "manage" can not be performed on node "931bcdcf-85d9-459c-ac43-828cd779d140" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "0687a312-e431-49d5-94e2-e278a9f9b541" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "ac71493d-c575-4e5a-8aef-dc376376bf97" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "47fc4a92-8338-44e2-8d30-614f18da8d5c" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "b248739b-f79c-4d0e-b404-19831e40fbf4" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "a36835aa-4d9d-42ce-a80d-a576bcb8182e" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "e6327431-8571-4355-b095-fc52923d4031" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "74b3376b-6a4e-4e8e-85e2-4032a15e0494" while it is in state "manageable". (HTTP 400)
The requested action "manage" can not be performed on node "c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2" while it is in state "manageable". (HTTP 400)

[stack@undercloud log]$ openstack baremetal node list
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| 931bcdcf-85d9-459c-ac43-828cd779d140 | cont01 | None          | None        | verifying          | False       |
| 0687a312-e431-49d5-94e2-e278a9f9b541 | cont02 | None          | None        | verifying          | False       |
| ac71493d-c575-4e5a-8aef-dc376376bf97 | cont03 | None          | None        | verifying          | False       |
| 47fc4a92-8338-44e2-8d30-614f18da8d5c | comp01 | None          | power off   | manageable         | False       |
| b248739b-f79c-4d0e-b404-19831e40fbf4 | comp02 | None          | power off   | manageable         | False       |
| a36835aa-4d9d-42ce-a80d-a576bcb8182e | comp03 | None          | power off   | manageable         | False       |
| e6327431-8571-4355-b095-fc52923d4031 | ceph01 | None          | power off   | manageable         | False       |
| 74b3376b-6a4e-4e8e-85e2-4032a15e0494 | ceph02 | None          | power off   | manageable         | False       |
| c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 | ceph03 | None          | power off   | manageable         | False       |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+

[stack@undercloud log]$ openstack baremetal node list
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| 931bcdcf-85d9-459c-ac43-828cd779d140 | cont01 | None          | power off   | manageable         | False       |
| 0687a312-e431-49d5-94e2-e278a9f9b541 | cont02 | None          | power off   | manageable         | False       |
| ac71493d-c575-4e5a-8aef-dc376376bf97 | cont03 | None          | power off   | manageable         | False       |
| 47fc4a92-8338-44e2-8d30-614f18da8d5c | comp01 | None          | power off   | manageable         | False       |
| b248739b-f79c-4d0e-b404-19831e40fbf4 | comp02 | None          | power off   | manageable         | False       |
| a36835aa-4d9d-42ce-a80d-a576bcb8182e | comp03 | None          | power off   | manageable         | False       |
| e6327431-8571-4355-b095-fc52923d4031 | ceph01 | None          | power off   | manageable         | False       |
| 74b3376b-6a4e-4e8e-85e2-4032a15e0494 | ceph02 | None          | power off   | manageable         | False       |
| c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 | ceph03 | None          | power off   | manageable         | False       |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+

```
Run the following command to inspect the hardware attributes of each node:
```
[stack@undercloud ~]$ openstack overcloud node introspect --all-manageable --provide
Started Mistral Workflow. Execution ID: 591e75e9-7f83-43e9-936f-90387260c148
Waiting for introspection to finish...
Introspection for UUID b248739b-f79c-4d0e-b404-19831e40fbf4 finished successfully.
Introspection for UUID 0687a312-e431-49d5-94e2-e278a9f9b541 finished successfully.
Introspection for UUID e6327431-8571-4355-b095-fc52923d4031 finished successfully.
Introspection for UUID ac71493d-c575-4e5a-8aef-dc376376bf97 finished successfully.
Introspection for UUID 931bcdcf-85d9-459c-ac43-828cd779d140 finished successfully.
Introspection for UUID c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 finished successfully.
Introspection for UUID 74b3376b-6a4e-4e8e-85e2-4032a15e0494 finished successfully.
Introspection for UUID a36835aa-4d9d-42ce-a80d-a576bcb8182e finished successfully.
Introspection for UUID 47fc4a92-8338-44e2-8d30-614f18da8d5c finished successfully.
Introspection completed.
Started Mistral Workflow. Execution ID: 288b14f5-f4f6-41d0-aa10-f588d87741fc

```
The command will take about 10 mins to inspect 12 nodes, you can verfiy by openning all nodes's console view to check the PXE boot process:

![](https://i.imgur.com/0ayR17z.png)

During the Inspection all nodes should be powered up:

```
[stack@undercloud ~]$ openstack baremetal node list
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| 931bcdcf-85d9-459c-ac43-828cd779d140 | cont01 | None          | power on    | manageable         | False       |
| 0687a312-e431-49d5-94e2-e278a9f9b541 | cont02 | None          | power on    | manageable         | False       |
| ac71493d-c575-4e5a-8aef-dc376376bf97 | cont03 | None          | power on    | manageable         | False       |
| 47fc4a92-8338-44e2-8d30-614f18da8d5c | comp01 | None          | power on    | manageable         | False       |
| b248739b-f79c-4d0e-b404-19831e40fbf4 | comp02 | None          | power on    | manageable         | False       |
| a36835aa-4d9d-42ce-a80d-a576bcb8182e | comp03 | None          | power on    | manageable         | False       |
| e6327431-8571-4355-b095-fc52923d4031 | ceph01 | None          | power on    | manageable         | False       |
| 74b3376b-6a4e-4e8e-85e2-4032a15e0494 | ceph02 | None          | power on    | manageable         | False       |
| c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 | ceph03 | None          | power on    | manageable         | False       |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+

```

After the inspection: all nodes will be powered-off and Provisioning Stated switched from manageable to **available**. 
```
[stack@undercloud log]$ openstack baremetal node list
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name   | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+
| 931bcdcf-85d9-459c-ac43-828cd779d140 | cont01 | None          | power off   | available          | False       |
| 0687a312-e431-49d5-94e2-e278a9f9b541 | cont02 | None          | power off   | available          | False       |
| ac71493d-c575-4e5a-8aef-dc376376bf97 | cont03 | None          | power off   | available          | False       |
| 47fc4a92-8338-44e2-8d30-614f18da8d5c | comp01 | None          | power off   | available          | False       |
| b248739b-f79c-4d0e-b404-19831e40fbf4 | comp02 | None          | power off   | available          | False       |
| a36835aa-4d9d-42ce-a80d-a576bcb8182e | comp03 | None          | power off   | available          | False       |
| e6327431-8571-4355-b095-fc52923d4031 | ceph01 | None          | power off   | available          | False       |
| 74b3376b-6a4e-4e8e-85e2-4032a15e0494 | ceph02 | None          | power off   | available          | False       |
| c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 | ceph03 | None          | power off   | available          | False       |
+--------------------------------------+--------+---------------+-------------+--------------------+-------------+

```
### Introspection Data Analysis

The following section will show how to check the introspection data collected during the pervious steps:

```
[stack@undercloud ~]$ mkdir swift-data
[stack@undercloud ~]$ cd swift-data
[stack@undercloud swift-data]$ export SWIFT_PASSWORD=`sudo crudini --get /etc/ironic-inspector/inspector.conf swift password`

[stack@undercloud swift-data]$ for node in $(ironic node-list | grep -v UUID| awk '{print $2}'); do swift -U service:ironic -K $SWIFT_PASSWORD download ironic-inspector inspector_data-$node; done
inspector_data-931bcdcf-85d9-459c-ac43-828cd779d140 [auth 0.470s, headers 0.664s, total 0.664s, 0.242 MB/s]
inspector_data-0687a312-e431-49d5-94e2-e278a9f9b541 [auth 0.403s, headers 0.516s, total 0.517s, 0.414 MB/s]
inspector_data-ac71493d-c575-4e5a-8aef-dc376376bf97 [auth 0.388s, headers 0.517s, total 0.518s, 0.248 MB/s]
inspector_data-47fc4a92-8338-44e2-8d30-614f18da8d5c [auth 0.393s, headers 0.513s, total 0.513s, 0.354 MB/s]
inspector_data-b248739b-f79c-4d0e-b404-19831e40fbf4 [auth 0.409s, headers 0.557s, total 0.558s, 0.318 MB/s]
inspector_data-a36835aa-4d9d-42ce-a80d-a576bcb8182e [auth 0.481s, headers 0.700s, total 0.701s, 0.215 MB/s]
inspector_data-e6327431-8571-4355-b095-fc52923d4031 [auth 0.395s, headers 0.523s, total 0.524s, 0.367 MB/s]
inspector_data-74b3376b-6a4e-4e8e-85e2-4032a15e0494 [auth 0.391s, headers 0.520s, total 0.520s, 0.366 MB/s]
inspector_data-c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 [auth 0.399s, headers 0.515s, total 0.516s, 0.405 MB/s]

[stack@undercloud swift-data]$ ll
total 412
-rw-rw-r--. 1 stack stack 47149 Dec  6 07:16 inspector_data-0687a312-e431-49d5-94e2-e278a9f9b541
-rw-rw-r--. 1 stack stack 42540 Dec  6 07:16 inspector_data-47fc4a92-8338-44e2-8d30-614f18da8d5c
-rw-rw-r--. 1 stack stack 47438 Dec  6 07:16 inspector_data-74b3376b-6a4e-4e8e-85e2-4032a15e0494
-rw-rw-r--. 1 stack stack 47126 Dec  6 07:16 inspector_data-931bcdcf-85d9-459c-ac43-828cd779d140
-rw-rw-r--. 1 stack stack 47311 Dec  6 07:16 inspector_data-a36835aa-4d9d-42ce-a80d-a576bcb8182e
-rw-rw-r--. 1 stack stack 32131 Dec  6 07:16 inspector_data-ac71493d-c575-4e5a-8aef-dc376376bf97
-rw-rw-r--. 1 stack stack 47312 Dec  6 07:16 inspector_data-b248739b-f79c-4d0e-b404-19831e40fbf4
-rw-rw-r--. 1 stack stack 47284 Dec  6 07:16 inspector_data-c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2
-rw-rw-r--. 1 stack stack 47422 Dec  6 07:16 inspector_data-e6327431-8571-4355-b095-fc52923d4031

[stack@undercloud swift-data]$ openstack baremetal node list  -f value -c UUID -c Name | tee /tmp/1
931bcdcf-85d9-459c-ac43-828cd779d140 cont01
0687a312-e431-49d5-94e2-e278a9f9b541 cont02
ac71493d-c575-4e5a-8aef-dc376376bf97 cont03
47fc4a92-8338-44e2-8d30-614f18da8d5c comp01
b248739b-f79c-4d0e-b404-19831e40fbf4 comp02
a36835aa-4d9d-42ce-a80d-a576bcb8182e comp03
e6327431-8571-4355-b095-fc52923d4031 ceph01
74b3376b-6a4e-4e8e-85e2-4032a15e0494 ceph02
c7aa3aab-e57a-4936-b55f-e5ce02c7f4b2 ceph03

[stack@undercloud swift-data]$ while read i n; do mv inspector_data-$i inspector_data-$n; done < /tmp/1
[stack@undercloud swift-data]$ ll
total 412
-rw-rw-r--. 1 stack stack 47422 Dec  6 07:16 inspector_data-ceph01
-rw-rw-r--. 1 stack stack 47438 Dec  6 07:16 inspector_data-ceph02
-rw-rw-r--. 1 stack stack 47284 Dec  6 07:16 inspector_data-ceph03
-rw-rw-r--. 1 stack stack 42540 Dec  6 07:16 inspector_data-comp01
-rw-rw-r--. 1 stack stack 47312 Dec  6 07:16 inspector_data-comp02
-rw-rw-r--. 1 stack stack 47311 Dec  6 07:16 inspector_data-comp03
-rw-rw-r--. 1 stack stack 47126 Dec  6 07:16 inspector_data-cont01
-rw-rw-r--. 1 stack stack 47149 Dec  6 07:16 inspector_data-cont02
-rw-rw-r--. 1 stack stack 32131 Dec  6 07:16 inspector_data-cont03

[stack@undercloud swift-data]$ for name in `openstack baremetal node list  -f value -c Name`; do echo "NODE: $name"; echo ============================; cat inspector_data-$name | jq '.inventory.disks' | tee ${name}.disk; echo "---------------------------"; done >all_disk.out

[stack@undercloud swift-data]$ ll
total 468
-rw-rw-r--. 1 stack stack 16489 Dec  6 07:25 all_disk.out
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph01.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph02.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph03.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp01.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp02.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp03.disk
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 cont01.disk
-rw-rw-r--. 1 stack stack  1764 Dec  6 07:25 cont02.disk
-rw-rw-r--. 1 stack stack  1761 Dec  6 07:25 cont03.disk
-rw-rw-r--. 1 stack stack 47422 Dec  6 07:16 inspector_data-ceph01
-rw-rw-r--. 1 stack stack 47438 Dec  6 07:16 inspector_data-ceph02
-rw-rw-r--. 1 stack stack 47284 Dec  6 07:16 inspector_data-ceph03
-rw-rw-r--. 1 stack stack 42540 Dec  6 07:16 inspector_data-comp01
-rw-rw-r--. 1 stack stack 47312 Dec  6 07:16 inspector_data-comp02
-rw-rw-r--. 1 stack stack 47311 Dec  6 07:16 inspector_data-comp03
-rw-rw-r--. 1 stack stack 47126 Dec  6 07:16 inspector_data-cont01
-rw-rw-r--. 1 stack stack 47149 Dec  6 07:16 inspector_data-cont02
-rw-rw-r--. 1 stack stack 32131 Dec  6 07:16 inspector_data-cont03
[stack@undercloud swift-data]$ for name in `openstack baremetal node list  -f value -c Name`; do echo "NODE: $name"; echo ============================; cat inspector_data-$name | jq '.inventory.interfaces' | tee ${name}.int; echo "---------------------------"; done >all_interfaces.out

[stack@undercloud swift-data]$ ll
total 592
-rw-rw-r--. 1 stack stack 16489 Dec  6 07:25 all_disk.out
-rw-rw-r--. 1 stack stack 53409 Dec  6 07:27 all_interfaces.out
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph01.disk
-rw-rw-r--. 1 stack stack  6711 Dec  6 07:27 ceph01.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph02.disk
-rw-rw-r--. 1 stack stack  6637 Dec  6 07:27 ceph02.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 ceph03.disk
-rw-rw-r--. 1 stack stack  6341 Dec  6 07:27 ceph03.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp01.disk
-rw-rw-r--. 1 stack stack  5235 Dec  6 07:27 comp01.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp02.disk
-rw-rw-r--. 1 stack stack  6341 Dec  6 07:27 comp02.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 comp03.disk
-rw-rw-r--. 1 stack stack  6341 Dec  6 07:27 comp03.int
-rw-rw-r--. 1 stack stack  1762 Dec  6 07:25 cont01.disk
-rw-rw-r--. 1 stack stack  6075 Dec  6 07:27 cont01.int
-rw-rw-r--. 1 stack stack  1764 Dec  6 07:25 cont02.disk
-rw-rw-r--. 1 stack stack  6075 Dec  6 07:27 cont02.int
-rw-rw-r--. 1 stack stack  1761 Dec  6 07:25 cont03.disk
-rw-rw-r--. 1 stack stack  3023 Dec  6 07:27 cont03.int
-rw-rw-r--. 1 stack stack 47422 Dec  6 07:16 inspector_data-ceph01
-rw-rw-r--. 1 stack stack 47438 Dec  6 07:16 inspector_data-ceph02
-rw-rw-r--. 1 stack stack 47284 Dec  6 07:16 inspector_data-ceph03
-rw-rw-r--. 1 stack stack 42540 Dec  6 07:16 inspector_data-comp01
-rw-rw-r--. 1 stack stack 47312 Dec  6 07:16 inspector_data-comp02
-rw-rw-r--. 1 stack stack 47311 Dec  6 07:16 inspector_data-comp03
-rw-rw-r--. 1 stack stack 47126 Dec  6 07:16 inspector_data-cont01
-rw-rw-r--. 1 stack stack 47149 Dec  6 07:16 inspector_data-cont02
-rw-rw-r--. 1 stack stack 32131 Dec  6 07:16 inspector_data-cont03

[stack@undercloud swift-data]$ more  ceph01.disk
[
  {
    "size": 400088457216,
    "rotational": false,
    "vendor": "SanDisk",
    "name": "/dev/sda",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x5001e820027f8bf8",
    "model": "LT0400WM",
    "wwn": "0x5001e820027f8bf8",
    "serial": "5001e820027f8bf8"
  },
  {
    "size": 1200243695616,
    "rotational": true,
    "vendor": "SEAGATE",
    "name": "/dev/sdb",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x5000c50093f99c97",
    "model": "ST1200MM0088",
    "wwn": "0x5000c50093f99c97",
    "serial": "5000c50093f99c97"
  },
  {
    "size": 1200243695616,
    "rotational": true,
    "vendor": "SEAGATE",
    "name": "/dev/sdc",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x5000c50093f95e8f",
    "model": "ST1200MM0088",
    "wwn": "0x5000c50093f95e8f",
    "serial": "5000c50093f95e8f"
  },
  {
    "size": 1200243695616,
    "rotational": true,
    "vendor": "SEAGATE",
    "name": "/dev/sdd",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x5000c50093f978b7",
    "model": "ST1200MM0088",
    "wwn": "0x5000c50093f978b7",
    "serial": "5000c50093f978b7"
  },
  {
    "size": 1200243695616,
    "rotational": true,
    "vendor": "SEAGATE",
    "name": "/dev/sde",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x5000c50093f9867f",
    "model": "ST1200MM0088",
    "wwn": "0x5000c50093f9867f",
    "serial": "5000c50093f9867f"
  },
  {
    "size": 375809638400,
    "rotational": true,
    "vendor": "DELL",
    "name": "/dev/sdf",
    "wwn_vendor_extension": "0x21a52208448d24a4",
    "wwn_with_extension": "0x6b083fe0dc84a50021a52208448d24a4",
    "model": "PERC H730P Mini",
    "wwn": "0x6b083fe0dc84a500",
    "serial": "6b083fe0dc84a50021a52208448d24a4"
  }
]

```

**Network interfaces check:**
1) Controller nodes:
```

```
## TO Be Continued ##
## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc

