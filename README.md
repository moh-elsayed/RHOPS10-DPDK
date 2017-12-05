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
In case of HCI "Hyper-Converged Infrastructure, SDS will be co-exist with the SDC on the compute nodes.

## Deployment Guide
### Undercloud

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

### Overcloud
> **Overcloud Basic Configuration**

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
Started Mistral Workflow. Execution ID: c5845bda-d4a5-4aeb-a2f7-8ee315a31f83
Successfully registered node UUID 87f93584-e3ff-42cb-a3b8-d1336a725ab1
Successfully registered node UUID 9a0f0450-6aed-45f0-ae58-2cf603ce8d01
Successfully registered node UUID 991aca8b-2f1f-49c5-ad4c-c5b93c31e3a2
Successfully registered node UUID 7e5bf215-0f9b-48f6-90e0-2442b2cb6d6e
Successfully registered node UUID 8a184931-abb7-4268-8fd8-a73313eed598
Successfully registered node UUID 256f06d4-0cd3-4209-b0b1-89017670711f
Successfully registered node UUID 874b1450-670e-4ef9-a3c0-e2915274ad5c
Successfully registered node UUID 7e0653d3-f975-48b0-9761-cad834479cdb
Successfully registered node UUID bf1b4bd8-273e-4495-8a6f-6eb338645c6c

[stack@undercloud ~]$ openstack baremetal node list
+--------------------------------------+------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+------+---------------+-------------+--------------------+-------------+
| 87f93584-e3ff-42cb-a3b8-d1336a725ab1 | None | None          | None        | enroll             | False       |
| 9a0f0450-6aed-45f0-ae58-2cf603ce8d01 | None | None          | None        | enroll             | False       |
| 991aca8b-2f1f-49c5-ad4c-c5b93c31e3a2 | None | None          | None        | enroll             | False       |
| 7e5bf215-0f9b-48f6-90e0-2442b2cb6d6e | None | None          | power off   | manageable         | False       |
| 8a184931-abb7-4268-8fd8-a73313eed598 | None | None          | power off   | manageable         | False       |
| 256f06d4-0cd3-4209-b0b1-89017670711f | None | None          | power off   | manageable         | False       |
| 874b1450-670e-4ef9-a3c0-e2915274ad5c | None | None          | power off   | manageable         | False       |
| 7e0653d3-f975-48b0-9761-cad834479cdb | None | None          | power off   | manageable         | False       |
| bf1b4bd8-273e-4495-8a6f-6eb338645c6c | None | None          | power off   | manageable         | False       |
+--------------------------------------+------+---------------+-------------+--------------------+-------------+
```
As noticed above, i have three nodes in an enroll status: this status is due to failed IPMI communication:
1) Either password and username is incorrect.
2) the iDrac version needs to be updated ( Driver issues )

In my case, my iDRAC driver was old and different than the other 6 servers. I have updated the nodes to the latest driver, using a bootable media, refer the below link for further details
[https://www.dell.com/support/article/us/en/04/sln156799/how-to-subscribe-to-receive-dell-driver-and-firmware-update-notifications?lang=en](https://www.dell.com/support/article/us/en/04/sln156799/how-to-subscribe-to-receive-dell-driver-and-firmware-update-notifications?lang=en)
## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc

