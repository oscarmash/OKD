

[root@bastion ~]#  oc get clusterversion
NAME      VERSION              AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.22.0-okd-scos.10   True        False         11m     Cluster version is 4.22.0-okd-scos.10

[root@bastion ~]# oc adm release extract --command=openshift-install --to=/tmp/
[root@bastion ~]# /tmp/openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats.iso.disk.location'
https://rhcos.mirror.openshift.com/art/storage/prod/streams/c10s/builds/10.0.20251103-0/x86_64/scos-10.0.20251103-0-live-iso.x86_64.iso

$ ssh root@172.26.0.6
[root@esxi-r630:~] cd /vmfs/volumes/stg-1500GB/ISOs/
[root@esxi-r630:/vmfs/volumes/6a5a2cc4-f9a95ed2-7982-801844f2b768/ISOs] wget https://rhcos.mirror.openshift.com/art/storage/prod/streams/c10s/builds/10.0.20251103-0/x86_64/scos-10.0.20251103-0-live-iso.x86_64.iso