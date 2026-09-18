```
[root@bastion ~]# oc adm upgrade
Cluster version is 4.21.0-okd-scos.9

Upgradeable=False

  Reason: AdminAckRequired
  Message: This cluster is Azure or vSphere but lacks a boot image configuration. OCP will automatically opt this cluster into boot image management in 4.22. Please add a configuration to disable boot image updates if this is not desired. See https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/machine_configuration/mco-update-boot-images#mco-update-boot-images-disable_machine-configs-configure for more details.

Upstream: https://amd64.origin.releases.ci.openshift.org/graph
Channel: stable-scos-4

Recommended updates:

  VERSION            IMAGE
  4.22.0-okd-scos.0  registry.ci.openshift.org/origin/release-scos@sha256:018b65c9bd7fb045c7557e46665dacfa979ebe31d112c82b7c551ffe04e7f70f
  4.21.0-okd-scos.11 registry.ci.openshift.org/origin/release-scos@sha256:4b930ee653c7e7671cf2d69e50a1898330556a09ac58b255fbe4b8addd53b290
  4.21.0-okd-scos.10 registry.ci.openshift.org/origin/release-scos@sha256:6e55d5ec331e548bd7698e04b5e1459bc4f840c1d155858cc7e42364bd77a595
```

```
[root@bastion ~]# ssh core@worker1.ilba.cat "sudo cat /etc/redhat-release"
CentOS Stream release 10 (Coughlan)
```

Aceptamos conforme aceptamos subir de versión:

```
cat << 'EOF' | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-acks
  namespace: openshift-config
data:
  ack-4.21-boot-image-management: "true"
EOF
```



oc adm upgrade


oc adm upgrade --to=4.22.0-okd-scos.0

oc get clusterversion -w