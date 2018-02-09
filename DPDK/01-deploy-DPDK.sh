#!/bin/bash
openstack overcloud deploy --templates /home/stack/DPDK/openstack-tripleo-heat-templates \
-r ./templates/roles_data.yaml \
-e ./templates/node-info.yaml \
-e ./templates/network-isolation.yaml \
-e ./openstack-tripleo-heat-templates/environments/neutron-ovs-dpdk.yaml \
-e ./templates/network-environment.yaml \
-e ./templates/storage-environment.yaml \
-e ./templates/timezone-environment.yaml \
--stack overcloud  $1 | tee  ./openstack-deployment.log