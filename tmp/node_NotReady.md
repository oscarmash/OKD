[root@bastion ~]# oc get nodes
NAME               STATUS     ROLES                  AGE   VERSION
master1.ilba.cat   Ready      control-plane,master   40d   v1.35.5
master2.ilba.cat   Ready      control-plane,master   40d   v1.35.5
master3.ilba.cat   Ready      control-plane,master   40d   v1.35.5
worker1.ilba.cat   Ready      worker                 41d   v1.35.5
worker2.ilba.cat   NotReady   worker                 41d   v1.35.5
worker3.ilba.cat   Ready      worker                 41d   v1.35.5
worker4.ilba.cat   Ready      worker                 41d   v1.35.5

[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# ssh core@worker2
[core@worker2 ~]$ sudo bash
[root@worker2 core]# systemctl status kubelet

