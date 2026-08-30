[root@bastion ~]# oc get clusteroperators
...
control-plane-machine-set                  4.21.0-okd-scos.9   False       False         True       45h     Missing 3 available replica(s)
...

[root@bastion ~]# oc get machines -n openshift-machine-api
NAME                 PHASE    TYPE   REGION   ZONE   AGE
okd-xwrjz-master-0   Failed                          45h
okd-xwrjz-master-1   Failed                          45h
okd-xwrjz-master-2   Failed                          45h

