#!/bin/bash
openstack overcloud deploy --templates \
-r ./template/roles_data.yaml \
-e ./template/node-info.yaml \
-e ./template/network-isolation.yaml \
-e ./template/network-environment.yaml \
-e ./template/storage-environment.yaml \
-e ./template/timezone-environment.yaml \
--stack overcloud  $1 | tee  ./openstack-deployment.log
