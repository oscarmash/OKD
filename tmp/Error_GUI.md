Solución 2

[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         True       13m     VSphereCSIDriverOperatorCRDegraded: VMwareVSphereOperatorCheckDegraded: unable to find VM master2.ilba.cat by UUID 37021342-7b2b-a5d8-9bf8-c94042a78d4f

[root@bastion ~]# oc adm cordon master3.ilba.cat
[root@bastion ~]# oc delete node master3.ilba.cat
[root@bastion ~]# ssh core@master3.ilba.cat "sudo systemctl restart kubelet"
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# oc get node master3.ilba.cat -o yaml | grep providerID
  providerID: vsphere://4213256d-78e9-7745-9bfd-11b3a8e5a330

[root@bastion ~]# oc adm uncordon master3.ilba.cat

[root@bastion ~]# oc rollout restart deployment/vsphere-problem-detector -n openshift-cluster-storage-operator 2>/dev/null || true
[root@bastion ~]# oc rollout restart deployment/cluster-storage-operator -n openshift-cluster-storage-operator

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                         AGE    VERSION
master1.ilba.cat   Ready    control-plane,master,worker   125m   v1.34.4
master2.ilba.cat   Ready    control-plane,master,worker   125m   v1.34.4
master3.ilba.cat   Ready    control-plane,master,worker   63s    v1.34.4
worker1.ilba.cat   Ready    worker                        71m    v1.34.4
worker2.ilba.cat   Ready    worker                        68m    v1.34.4
worker3.ilba.cat   Ready    worker                        62m    v1.34.4
worker4.ilba.cat   Ready    worker                        59m    v1.34.4

[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         False      19h