# Verisones

[root@bastion ~]# oc get clusterversion
NAME      VERSION            AVAILABLE   PROGRESSING   SINCE   STATUS
version   5.0.0-okd-scos.6   True        False         19h     Cluster version is 5.0.0-okd-scos.6

[root@bastion ~]# oc get nodes
NAME                 STATUS   ROLES                  AGE   VERSION
infra01.ilba.cat     Ready    infra                  21h   v1.36.5
infra02.ilba.cat     Ready    infra                  21h   v1.36.5
master01.ilba.cat    Ready    control-plane,master   22h   v1.36.5
master02.ilba.cat    Ready    control-plane,master   22h   v1.36.5
master03.ilba.cat    Ready    control-plane,master   22h   v1.36.5
storage01.ilba.cat   Ready    storage                20h   v1.36.5
storage02.ilba.cat   Ready    storage                20h   v1.36.5
storage03.ilba.cat   Ready    storage                20h   v1.36.5
worker01.ilba.cat    Ready    worker                 20h   v1.36.5
worker02.ilba.cat    Ready    worker                 20h   v1.36.5
worker03.ilba.cat    Ready    worker                 20h   v1.36.5
worker04.ilba.cat    Ready    worker                 20h   v1.36.5

host5:~# lsblk
NAME                                  MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda                                     8:0    0 447.1G  0 disk
sdb                                     8:16   0 447.1G  0 disk
sdc                                     8:32   0 447.1G  0 disk
...

# Proxmox Disk Passthrough

Obtenemos los identificadores únicos de los discos sda, sdb y sdc que están en el equipo de Proxmox:

host5:~# ls -l /dev/disk/by-id/ | grep -E "sd[a-c]$"
lrwxrwxrwx 1 root root  9 Nov 14 08:06 ata-INTEL_SSDSC2KG480G8_PHYG002400TT480BGN -> ../../sdc
lrwxrwxrwx 1 root root  9 Nov 14 08:06 ata-INTEL_SSDSC2KG480G8_PHYG002400UU480BGN -> ../../sdb
lrwxrwxrwx 1 root root  9 Nov 14 08:06 ata-LK0480GFJSK_BTHC719109UM480MGN -> ../../sda
lrwxrwxrwx 1 root root  9 Nov 14 08:06 wwn-0x55cd2e414dc30661 -> ../../sda
lrwxrwxrwx 1 root root  9 Nov 14 08:06 wwn-0x55cd2e415216e03d -> ../../sdc
lrwxrwxrwx 1 root root  9 Nov 14 08:06 wwn-0x55cd2e415216e060 -> ../../sdb

host5:~# qm list | grep -i storage
     20031 storage01.ilba.cat   running    16384            120.00 2301
     20032 storage02.ilba.cat   running    16384            120.00 2384
     20033 storage03.ilba.cat   running    16834            120.00 2484
    
host5:~# qm set 20031 -scsi1 /dev/disk/by-id/ata-LK0480GFJSK_BTHC719109UM480MGN,discard=on,ssd=1,iothread=1
host5:~# qm set 20032 -scsi1 /dev/disk/by-id/ata-INTEL_SSDSC2KG480G8_PHYG002400UU480BGN,discard=on,ssd=1,iothread=1
host5:~# qm set 20033 -scsi1 /dev/disk/by-id/ata-INTEL_SSDSC2KG480G8_PHYG002400TT480BGN,discard=on,ssd=1,iothread=1

[root@bastion ~]# oc debug node/storage01.ilba.cat -- chroot /host lsblk -d -o NAME,SIZE,MODEL,ROTA
NAME   SIZE MODEL         ROTA
sda  447.1G QEMU HARDDISK    0
sr0    876M QEMU DVD-ROM     1
vda    120G                  1

[root@bastion ~]# oc debug node/storage02.ilba.cat -- chroot /host lsblk -d -o NAME,SIZE,MODEL,ROTA
NAME   SIZE MODEL         ROTA
sda  447.1G QEMU HARDDISK    0
sr0    876M QEMU DVD-ROM     1
vda    120G                  1

[root@bastion ~]# oc debug node/storage03.ilba.cat -- chroot /host lsblk -d -o NAME,SIZE,MODEL,ROTA
NAME   SIZE MODEL         ROTA
sda  447.1G QEMU HARDDISK    0
sr0    876M QEMU DVD-ROM     1
vda    120G                  1


# Creación NS

[root@bastion ~]# oc create namespace rook-ceph
[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:rook-ceph

# Operador rook-ceph

[root@bastion ~]# dnf install -y helm
[root@bastion ~]# helm repo add rook-release https://charts.rook.io/release
[root@bastion ~]# helm repo update

[root@bastion manifests]# mkdir -p ~/manifests/02-rook
[root@bastion manifests]# cd ~/manifests/02-rook

[root@bastion 02-rook]# vim rook-operator-values.yaml
crds:
  enabled: true

nodeSelector:
  node-role.kubernetes.io/storage: ""

tolerations:
  - key: node-role.kubernetes.io/storage
    operator: Exists
    effect: NoSchedule
  - key: node.ocs.openshift.io/storage
    operator: Exists
    effect: NoSchedule

csi:
  enableRbdDriver: true
  enableCephfsDriver: true
  pluginTolerations:
    - key: node-role.kubernetes.io/infra
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule
  provisionerNodeAffinity: node-role.kubernetes.io/storage=
  provisionerTolerations:
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule

hostpathRequiresPrivileged: true

[root@bastion 02-rook]# helm search repo rook-release/rook-ceph
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
rook-release/rook-ceph          v1.21.2         v1.21.2         File, Block, and Object Storage Services for yo...
rook-release/rook-ceph-cluster  1.21.2          v1.21.2         Manages a single Ceph cluster namespace for Rook

helm upgrade --install \
rook-ceph rook-release/rook-ceph \
--namespace rook-ceph \
--version v1.21.2 \
-f rook-operator-values.yaml

[root@bastion 02-rook]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion 02-rook]# helm ls -n rook-ceph
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
rook-ceph       rook-ceph       1               2026-11-21 09:04:20.64954156 +0100 CET  deployed        rook-ceph-v1.21.2       v1.21.2

[root@bastion 02-rook]# oc -n rook-ceph get pods
NAME                                           READY   STATUS    RESTARTS   AGE
ceph-csi-controller-manager-6dc6ff9685-8c92l   1/1     Running   0          3m11s
rook-ceph-operator-56f9ff5b45-kbkks            1/1     Running   0          3m11s

# Clúster rook-ceph-cluster

[root@bastion 02-rook]# vim rook-cluster-values.yaml
operatorNamespace: rook-ceph

toolbox:
  enabled: true

cephClusterSpec:
  cephVersion:
    image: quay.io/ceph/ceph:v20.2.0
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
    modules:
      - name: pg_autoscaler
        enabled: true
      - name: prometheus
        enabled: false
  dashboard:
    enabled: true
    ssl: false
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/storage
                  operator: Exists
      tolerations:
        - key: node-role.kubernetes.io/storage
          operator: Exists
          effect: NoSchedule
        - key: node.ocs.openshift.io/storage
          operator: Exists
          effect: NoSchedule
  resources:
    mgr:
      requests:
        cpu: "100m"
        memory: "512Mi"
    mon:
      requests:
        cpu: "100m"
        memory: "512Mi"
    osd:
      requests:
        cpu: "250m"
        memory: "2Gi"
    crashcollector:
      requests:
        cpu: "50m"
        memory: "60Mi"
    exporter:
      requests:
        cpu: "50m"
        memory: "50Mi"
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "storage01.ilba.cat"
        devices:
          - name: "sda"
      - name: "storage02.ilba.cat"
        devices:
          - name: "sda"
      - name: "storage03.ilba.cat"
        devices:
          - name: "sda"

cephBlockPools:
  - name: ceph-blockpool
    spec:
      failureDomain: host
      replicated:
        size: 3
    storageClass:
      enabled: true
      name: rook-ceph-block
      isDefault: true
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        csi.storage.k8s.io/fstype: ext4

cephFileSystems:
  - name: ceph-filesystem
    spec:
      metadataPool:
        replicated:
          size: 3
      dataPools:
        - failureDomain: host
          replicated:
            size: 3
          name: data0
      metadataServer:
        activeCount: 1
        activeStandby: true
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: node-role.kubernetes.io/storage
                      operator: Exists
          tolerations:
            - key: node-role.kubernetes.io/storage
              operator: Exists
              effect: NoSchedule
            - key: node.ocs.openshift.io/storage
              operator: Exists
              effect: NoSchedule
    storageClass:
      enabled: true
      isDefault: false
      name: rook-cephfs
      pool: data0
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      parameters:
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph

cephObjectStores: []









helm upgrade --install \
rook-ceph-cluster rook-release/rook-ceph-cluster \
--namespace rook-ceph \
--version v1.21.2 \
-f rook-cluster-values.yaml








[root@bastion 02-rook]# helm ls -n rook-ceph
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
rook-ceph               rook-ceph       1               2026-11-21 09:04:20.64954156 +0100 CET  deployed        rook-ceph-v1.21.2               v1.21.2
rook-ceph-cluster       rook-ceph       1               2026-11-21 09:16:47.888372327 +0100 CET deployed        rook-ceph-cluster-v1.21.2       v1.21.2

[root@bastion 02-rook]# oc -n rook-ceph get pods
NAME                                           READY   STATUS    RESTARTS      AGE
ceph-csi-controller-manager-6dc6ff9685-8c92l   1/1     Running   0             23m
rook-ceph-mon-a-598bd7fbc7-4t6pd               2/2     Running   0             42s
rook-ceph-mon-b-9db6f969-zzb2q                 1/2     Running   1 (13s ago)   6m23s
rook-ceph-mon-c-777bf87777-kzq8k               2/2     Running   0             41s
rook-ceph-operator-7469bc6444-m2mhd            1/1     Running   0             82s
rook-ceph-tools-748887bfd7-m6jkk               1/1     Running   0             18m

[root@bastion 02-rook]# oc -n rook-ceph get cephcluster
NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
rook-ceph   /var/lib/rook     3          20m   Ready   Cluster created successfully   HEALTH_OK              68ab4388-2235-4785-a49f-608749d6707b

[root@bastion 02-rook]# oc -n rook-ceph get pods
NAME                                                           READY   STATUS      RESTARTS        AGE
ceph-csi-controller-manager-6dc6ff9685-8c92l                   1/1     Running     0               26m
rook-ceph-crashcollector-storage01.ilba.cat-77bb4bb86c-vgk5w   1/1     Running     0               21s
rook-ceph-crashcollector-storage02.ilba.cat-7c5bc846fd-9c69f   1/1     Running     0               18s
rook-ceph-crashcollector-storage03.ilba.cat-6d4c97d95-x2g9c    1/1     Running     0               41s
rook-ceph-exporter-storage01.ilba.cat-c9444c85-ndphf           2/2     Running     0               20s
rook-ceph-exporter-storage02.ilba.cat-dbff7d9d-nw4hr           2/2     Running     0               17s
rook-ceph-exporter-storage03.ilba.cat-6948b9b77c-2rfjp         2/2     Running     0               40s
rook-ceph-mds-ceph-filesystem-a-66648f9b9d-rs5ks               2/2     Running     0               21s
rook-ceph-mds-ceph-filesystem-b-569b447b97-wmk6h               2/2     Running     0               18s
rook-ceph-mgr-a-68d5c5dbf9-9dnws                               3/3     Running     0               78s
rook-ceph-mgr-b-5d64878466-54nv8                               3/3     Running     0               77s
rook-ceph-mon-a-598bd7fbc7-4t6pd                               2/2     Running     0               2m52s
rook-ceph-mon-b-9db6f969-zzb2q                                 2/2     Running     1 (2m23s ago)   8m33s
rook-ceph-mon-c-777bf87777-kzq8k                               2/2     Running     1 (2m8s ago)    2m51s
rook-ceph-operator-7469bc6444-m2mhd                            1/1     Running     0               3m32s
rook-ceph-osd-0-78cc8cfbdb-v5nvf                               2/2     Running     0               43s
rook-ceph-osd-1-cd5c97ccc-wfs4j                                2/2     Running     0               43s
rook-ceph-osd-2-64fbfcfc45-shb5w                               2/2     Running     0               41s
rook-ceph-osd-prepare-storage01.ilba.cat-dmzmr                 0/1     Completed   0               54s
rook-ceph-osd-prepare-storage02.ilba.cat-9r4tm                 0/1     Completed   0               53s
rook-ceph-osd-prepare-storage03.ilba.cat-tmvcb                 0/1     Completed   0               52s
rook-ceph-tools-748887bfd7-m6jkk                               1/1     Running     0               20m

[root@bastion ~]# oc get sc
NAME                        PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   50m
rook-cephfs                 rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   50m




































































































































# Local Storage Operator (LSO)

Es un sistema que escanea los discos locales dev cada nodo y los convierte en objetos de Kubernetes (PersistentVolumes).
A partir de aquí podemos hacerlo de dos formas:
* Sin LSO: desplegar Rook directamente sobre tus nodos storage01-03 apuntando al dispositivo bruto /dev/sda (es Rook el que los controla)
* Con LSO: tiene más control de los discos (tamaño, modelo y estado de cada disco desde oc sin entrar a los nodos)

## Catálogo de redhat-operators

Añadiremos el catálogo de redhat-operators para poder instalar LSO, ya que sinó tendriamos que hacer una instalación desde el repositorio de GitHub.

Podremos conseguir el Token de https://console.redhat.com/openshift/install/pull-secret, pero previavemente nos hemos creado una cuenta gratuita en RedHat Developers. De aquí conseguiremos el fichero _pull-secret.txt_

```
[root@bastion 02-rook]# chmod 600 pull-secret.txt && chown root:root pull-secret.txt
```


[root@bastion 02-rook]# oc create secret docker-registry redhat-registry-secret \
  --from-file=.dockerconfigjson=pull-secret.txt \
  -n openshift-marketplace

[root@bastion 02-rook]# vim openshift-marketplace.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  displayName: Red Hat Operators
  image: registry.redhat.io/redhat/redhat-operator-index:v4.22
  publisher: Red Hat
  sourceType: grpc
  secrets:
    - redhat-registry-secret
  grpcPodConfig:
    nodeSelector:
      node-role.kubernetes.io/infra: ""
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"
  updateStrategy:
    registryPoll:
      interval: 15m

[root@bastion 02-rook]# oc apply -f openshift-marketplace.yaml

[root@bastion 02-rook]# oc -n openshift-marketplace get catalogsource
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     26h
redhat-operators      Red Hat Operators     grpc   Red Hat     18m

[root@bastion 02-rook]# oc get pod -n openshift-marketplace
NAME                                    READY   STATUS    RESTARTS      AGE
community-operators-p5tnm               1/1     Running   3             26h
marketplace-operator-6bc6fb58bc-pv4gc   1/1     Running   4 (26h ago)   26h
redhat-operators-pqzsw                  1/1     Running   0             2m9s

[root@bastion 01-labels_taints]# oc get packagemanifest -n openshift-marketplace -l catalog=redhat-operators | grep -i local-storage
local-storage-operator                           Red Hat Operators   26m

## Install LSO

[root@bastion 02-rook]# vim install-lso.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-storage-operatorgroup
  namespace: openshift-local-storage
spec:
  targetNamespaces:
  - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: stable
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace

[root@bastion 02-rook]# oc apply -f install-lso.yaml

[root@bastion 02-rook]# oc create secret docker-registry redhat-registry-secret \
  --from-file=.dockerconfigjson=pull-secret.txt \
  -n openshift-local-storage

[root@bastion 02-rook]# oc secrets link local-storage-operator redhat-registry-secret --for=pull -n openshift-local-storage
[root@bastion 02-rook]# oc secrets link default redhat-registry-secret --for=pull -n openshift-local-storage
[root@bastion 02-rook]# oc delete pod -n openshift-local-storage -l name=local-storage-operator

Pasados unos minutos podremos ver:

[root@bastion 02-rook]# oc -n openshift-local-storage get csv
NAME                                          DISPLAY         VERSION               RELEASE   REPLACES   PHASE
local-storage-operator.v4.22.0-202611031655   Local Storage   4.22.0-202611031655                        Succeeded

[root@bastion 02-rook]# oc -n openshift-local-storage get pods
NAME                                     READY   STATUS    RESTARTS   AGE
local-storage-operator-88c5676cc-d7zhc   1/1     Running   0          45s

## Creación de recursos

El siguiente paso es crear los recursos LocalVolumeDiscovery y LocalVolumeSet para que LSO escanee storage01, storage02 y storage03, detecte los tres discos sda y cree automáticamente los 3 PersistentVolumes en un StorageClass llamado local-block.

[root@bastion 02-rook]# vim lso-disks.yaml
apiVersion: local.storage.openshift.io/v1alpha1
kind: LocalVolumeDiscovery
metadata:
  name: auto-discover-devices
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
      - matchExpressions:
          - key: node-role.kubernetes.io/storage
            operator: Exists
  tolerations:
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule
---
apiVersion: local.storage.openshift.io/v1alpha1
kind: LocalVolumeSet
metadata:
  name: rook-ceph-local-disks
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
      - matchExpressions:
          - key: node-role.kubernetes.io/storage
            operator: Exists
  tolerations:
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule
  storageClassName: local-block
  volumeMode: Block
  deviceInclusionSpec:
    deviceTypes:
      - disk
    minSize: 400Gi
    maxSize: 500Gi

[root@bastion 02-rook]# oc secrets link local-storage-admin redhat-registry-secret --for=pull -n openshift-local-storage
[root@bastion 02-rook]# oc apply -f lso-disks.yaml

[root@bastion 02-rook]# oc -n openshift-local-storage get pods -o wide
NAME                                     READY   STATUS    RESTARTS   AGE     IP            NODE                 NOMINATED NODE   READINESS GATES
diskmaker-discovery-6dns5                2/2     Running   0          21s     10.131.2.16   storage03.ilba.cat   <none>           <none>
diskmaker-discovery-7pdv8                2/2     Running   0          20s     10.130.2.13   storage01.ilba.cat   <none>           <none>
diskmaker-discovery-rdm2f                2/2     Running   0          21s     10.129.2.11   storage02.ilba.cat   <none>           <none>
diskmaker-manager-frs8z                  2/2     Running   0          19s     10.130.2.14   storage01.ilba.cat   <none>           <none>
diskmaker-manager-pv85w                  2/2     Running   0          19s     10.131.2.17   storage03.ilba.cat   <none>           <none>
diskmaker-manager-sgw2z                  2/2     Running   0          19s     10.129.2.12   storage02.ilba.cat   <none>           <none>
local-storage-operator-88c5676cc-d7zhc   1/1     Running   0          6m51s   10.130.2.10   storage01.ilba.cat   <none>           <none>

[root@bastion 02-rook]# oc get localvolumediscoveryresult -n openshift-local-storage
NAME                                  AGE
discovery-result-storage01.ilba.cat   29s
discovery-result-storage02.ilba.cat   29s
discovery-result-storage03.ilba.cat   29s

[root@bastion 02-rook]# oc get sc local-block
NAME          PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-block   kubernetes.io/no-provisioner   Delete          WaitForFirstConsumer   false                  2m53s

[root@bastion 02-rook]# oc get pv
NAME                CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
local-pv-30d965d0   447Gi      RWO            Delete           Available           local-block    <unset>                          2m23s
local-pv-710667e6   447Gi      RWO            Delete           Available           local-block    <unset>                          2m23s
local-pv-db9e4f39   447Gi      RWO            Delete           Available           local-block    <unset>                          2m23s

# Install Rook

En Rook podemos encontrar dos charts:
* rook-ceph (el operador): despliega los CRDs, permisos RBAC y el pod rook-ceph-operator.
* rook-ceph-cluster (el clúster): crea el clúster, o se puede hacer con manifiestos

Hemos escogido sólo instalar el rook-ceph (el operador) y montar el cluster con manifiestos (no instalaremos el rook-ceph-cluster)

## Install rook-ceph (Chart: rook-ceph)

Por desgracia Rook no se puede instalar via OLM porque tienen publicado como paquete OLM y lo hemos de hacer via Helm

[root@bastion ~]# helm repo add rook-release https://charts.rook.io/release
[root@bastion ~]# helm repo update

[root@bastion 02-rook]# helm search repo rook-release/rook-ceph -l | head -n 5
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
rook-release/rook-ceph          v1.21.2         v1.21.2         File, Block, and Object Storage Services for yo...
rook-release/rook-ceph          1.21.2          v1.21.2         File, Block, and Object Storage Services for yo...
rook-release/rook-ceph          1.21.1          v1.21.1         File, Block, and Object Storage Services for yo...
rook-release/rook-ceph          1.21.0          v1.21.0         File, Block, and Object Storage Services for yo...

[root@bastion 02-rook]# vim rook-operator-values.yaml
crds:
  enabled: true

nodeSelector:
  node-role.kubernetes.io/infra: ""

tolerations:
  - key: node-role.kubernetes.io/infra
    operator: Exists
    effect: NoSchedule

csi:
  enableRbdDriver: true
  enableCephfsDriver: true
  csiAddons:
    controller:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: node-role.kubernetes.io/infra
          operator: Exists
          effect: NoSchedule
  provisionerNodeAffinity: node-role.kubernetes.io/infra=
  provisionerTolerations:
    - key: node-role.kubernetes.io/infra
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule
  pluginTolerations:
    - key: node-role.kubernetes.io/infra
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
    - key: node.ocs.openshift.io/storage
      operator: Exists
      effect: NoSchedule


helm upgrade --install \
rook-ceph rook-release/rook-ceph \
--create-namespace \
--namespace rook-ceph \
--version=v1.21.2 \
-f rook-operator-values.yaml

[root@bastion 02-rook]# helm -n rook-ceph ls
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
rook-ceph       rook-ceph       1               2026-11-14 13:52:58.074734303 +0100 CET deployed        rook-ceph-v1.21.2       v1.21.2

[root@bastion 02-rook]# oc -n rook-ceph get pods
NAME                                           READY   STATUS    RESTARTS   AGE
ceph-csi-controller-manager-6dc6ff9685-hq9fw   1/1     Running   0          44s
rook-ceph-operator-65444b79c4-gw4mv            1/1     Running   0          44s

## Desplegar el clúster (Chart: rook-ceph-cluster)

: waring : Se ha de instalar con el Chart rook-ceph-cluster, si lo desplegamos a mano (via manifest), lo que nos pasará es que nos faltará cerar todos los Service Accounts, Role Binding, etc.... así que es mejor hacerlo via este Chart que via manifest

[root@bastion 02-rook]# vim ceph-cluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v20.2.0
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
  dashboard:
    enabled: true
    ssl: true
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/storage
                  operator: Exists
      tolerations:
        - key: node-role.kubernetes.io/storage
          operator: Exists
          effect: NoSchedule
        - key: node.ocs.openshift.io/storage
          operator: Exists
          effect: NoSchedule
  storage:
    storageClassDeviceSets:
      - name: sda-local
        count: 3
        portable: false
        tuneDeviceClass: true
        encrypted: false
        volumeClaimTemplates:
          - metadata:
              name: data
            spec:
              resources:
                requests:
                  storage: 440Gi
              storageClassName: local-block
              volumeMode: Block
              accessModes:
                - ReadWriteOnce

[root@bastion 02-rook]# oc apply -f ceph-cluster.yaml

Pasado un rato:

[root@bastion 02-rook]# oc get pods -n rook-ceph -o wide
NAME                                                           READY   STATUS      RESTARTS   AGE   IP            NODE                 NOMINATED NODE   READINESS GATES
ceph-csi-controller-manager-5bf67f449c-57jhq                   1/1     Running     0          19m   10.128.2.18   infra02.ilba.cat     <none>           <none>
rook-ceph-crashcollector-storage01.ilba.cat-5c968ffdb-swcpl    1/1     Running     0          25m   10.130.2.11   storage01.ilba.cat   <none>           <none>
rook-ceph-crashcollector-storage02.ilba.cat-556ff7dcf7-ccvl7   1/1     Running     0          12m   10.129.2.19   storage02.ilba.cat   <none>           <none>
rook-ceph-crashcollector-storage03.ilba.cat-66d746685b-kmxgc   1/1     Running     0          24m   10.131.2.18   storage03.ilba.cat   <none>           <none>
rook-ceph-exporter-storage01.ilba.cat-7768ccf754-phrfg         1/1     Running     0          25m   10.130.2.12   storage01.ilba.cat   <none>           <none>
rook-ceph-exporter-storage02.ilba.cat-644b4bfcd9-jncjc         1/1     Running     0          12m   10.129.2.20   storage02.ilba.cat   <none>           <none>
rook-ceph-exporter-storage03.ilba.cat-666cd4f7fb-ljcmn         1/1     Running     0          24m   10.131.2.19   storage03.ilba.cat   <none>           <none>
rook-ceph-mgr-a-7fb7f4bd69-n9rw2                               2/2     Running     0          25m   10.131.2.11   storage03.ilba.cat   <none>           <none>
rook-ceph-mgr-b-5d64cc87f6-dg8sk                               2/2     Running     0          25m   10.129.2.13   storage02.ilba.cat   <none>           <none>
rook-ceph-mon-a-5bd8bc7fdc-vhf9z                               1/1     Running     0          27m   10.129.2.10   storage02.ilba.cat   <none>           <none>
rook-ceph-mon-b-6f886d9d64-fgpk5                               1/1     Running     0          26m   10.131.2.10   storage03.ilba.cat   <none>           <none>
rook-ceph-mon-c-78574b757b-xlj5v                               1/1     Running     0          26m   10.130.2.9    storage01.ilba.cat   <none>           <none>
rook-ceph-operator-6f4d5bb4bf-grxzx                            1/1     Running     0          13m   10.131.0.25   infra01.ilba.cat     <none>           <none>
rook-ceph-osd-0-6c9478fcd9-6q277                               1/1     Running     0          24m   10.130.2.16   storage01.ilba.cat   <none>           <none>
rook-ceph-osd-1-566cbc4888-sbx6r                               1/1     Running     0          24m   10.131.2.15   storage03.ilba.cat   <none>           <none>
rook-ceph-osd-2-85bfd47ddb-s2256                               1/1     Running     0          12m   10.129.2.18   storage02.ilba.cat   <none>           <none>
rook-ceph-osd-prepare-sda-local-data-0kjldm-nz95g              0/1     Completed   0          24m   10.130.2.15   storage01.ilba.cat   <none>           <none>
rook-ceph-osd-prepare-sda-local-data-1qpplz-zrd44              0/1     Completed   0          24m   10.131.2.14   storage03.ilba.cat   <none>           <none>
rook-ceph-osd-prepare-sda-local-data-2ngppj-7dl2h              0/1     Completed   0          12m   10.129.2.17   storage02.ilba.cat   <none>           <none>

[root@bastion 02-rook]# oc get cephcluster -n rook-ceph
NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
rook-ceph   /var/lib/rook     3          30m   Ready   Cluster created successfully   HEALTH_OK              219a7698-f9e0-4ec5-aea2-aaae46f6bdc6


[root@bastion 02-rook]# oc patch cm rook-ceph-operator-config -n rook-ceph --type merge -p '{"data":{"ROOK_CREATE_CSI_OPERATOR_RESOURCES":"true"}}'

El siguiente paso es crear los SC para que las aplicaciones puedan consumir volúmenes persistentes dinámicamente:
* Almacenamiento en bloque (RBD) 
* Sistema de archivos compartido (CephFS)

[root@bastion 02-rook]# cat ceph-block-sc.yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 2
    requireSafeReplicaSize: false
  parameters:
    min_size: "1"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-ceph-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-ceph-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-ceph-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate


[root@bastion 02-rook]# cat ceph-filesystem-sc.yaml
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  metadataPool:
    failureDomain: host
    replicated:
      size: 2
      requireSafeReplicaSize: false
    parameters:
      min_size: "1"
  dataPools:
    - name: replicated
      failureDomain: host
      replicated:
        size: 2
        requireSafeReplicaSize: false
      parameters:
        min_size: "1"
  preserveFilesystemOnDelete: true
  metadataServer:
    activeCount: 1
    activeStandby: true
    placement:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/storage
                  operator: Exists
      tolerations:
        - key: node-role.kubernetes.io/storage
          operator: Exists
          effect: NoSchedule
        - key: node.ocs.openshift.io/storage
          operator: Exists
          effect: NoSchedule
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: myfs
  pool: myfs-replicated
  csi.storage.k8s.io/provisioner-secret-name: rook-ceph-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-ceph-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-ceph-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate

[root@bastion 02-rook]# oc apply -f ceph-block-sc.yaml
[root@bastion 02-rook]# oc apply -f ceph-filesystem-sc.yaml

[root@bastion 02-rook]# oc get sc
NAME                        PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-block                 kubernetes.io/no-provisioner    Delete          WaitForFirstConsumer   false                  19h
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com      Delete          Immediate              true                   2m43s
rook-cephfs                 rook-ceph.cephfs.csi.ceph.com   Delete          Immediate              true                   2m38s

[root@bastion 02-rook]# oc -n rook-ceph get cephblockpool
NAME          PHASE   TYPE         FAILUREDOMAIN   AGE
replicapool   Ready   Replicated   host            3m3s

[root@bastion 02-rook]# oc -n rook-ceph get cephfilesystem
NAME   ACTIVEMDS   AGE    PHASE
myfs   1           3m3s   Ready


# Acceso al Dashboard

oc create route passthrough rook-ceph-mgr-dashboard \
  --service=rook-ceph-mgr-dashboard \
  --port=https-dashboard \
  -n rook-ceph

Redirigimos el HTTP al HTTPS:

[root@bastion ~]# oc patch route rook-ceph-mgr-dashboard -n rook-ceph --type merge -p '{"spec":{"tls":{"insecureEdgeTerminationPolicy":"Redirect"}}}'

[root@bastion ~]# oc get secret rook-ceph-dashboard-password -n rook-ceph -o jsonpath='{.data.password}' | base64 -d && echo
8j;sXmnPT$FG1N\j<l@,


[root@bastion ~]# oc get route -n rook-ceph
NAME                      HOST/PORT                                             PATH   SERVICES                  PORT              TERMINATION          WILDCARD
rook-ceph-mgr-dashboard   rook-ceph-mgr-dashboard-rook-ceph.apps.okd.ilba.cat          rook-ceph-mgr-dashboard   https-dashboard   reencrypt/Redirect   None

![default](images/Dashboard_Ceph.png)

# Integración de Dashboard con OKD


[root@bastion 02-rook]# vim ceph-console-link.yaml
apiVersion: console.openshift.io/v1
kind: ConsoleLink
metadata:
  name: ceph-dashboard-link
spec:
  applicationMenu:
    section: Storage
    imageURL: https://rook.io/images/rook-icon.svg
  href: https://rook-ceph-mgr-dashboard-rook-ceph.apps.okd.ilba.cat
  location: ApplicationMenu
  text: Ceph Storage Dashboard

[root@bastion 02-rook]# oc apply -f ceph-console-link.yaml

[root@bastion 02-rook]# oc get consolelink
NAME                  TEXT                     URL                                                           LOCATION          AGE
ceph-dashboard-link   Ceph Storage Dashboard   https://rook-ceph-mgr-dashboard-rook-ceph.apps.okd.ilba.cat   ApplicationMenu   105s


![default](images/Dashboard_Ceph_OKD.png)


# Verificación

## RBD


[root@bastion 02-rook]# oc create ns test-ceph

[root@bastion 02-rook]# oc get sc
[root@bastion 02-rook]# vim test-ceph-rbd.yaml

[root@bastion 02-rook]# oc apply -f test-ceph-rbd.yaml

[root@bastion 02-rook]# oc -n test-ceph get pods
[root@bastion 02-rook]# oc -n test-ceph get pvc

[root@bastion 02-rook]# oc get cephcluster -n rook-ceph












































# Errror Ceph (HEALTH_ERR)

Al desplegar Ceph, nos ha dado el siguiewnte error:

[root@bastion ~]# MGR_POD=$(oc get pod -n rook-ceph -l app=rook-ceph-mgr -o jsonpath='{.items[0].metadata.name}')
[root@bastion ~]# ADMIN_KEY=$(oc get secret rook-ceph-mon -n rook-ceph -o jsonpath='{.data.ceph-secret}' | base64 -d)
[root@bastion ~]# MON_HOSTS=$(oc get cm rook-ceph-mon-endpoints -n rook-ceph -o jsonpath='{.data.data}' | sed 's/[a-z]=//g')
[root@bastion ~]# oc exec -n rook-ceph "$MGR_POD" -c mgr -- ceph -n client.admin --key="$ADMIN_KEY" --mon-host="$MON_HOSTS" health detail
HEALTH_ERR Module 'prometheus' has failed: not all arguments converted during string formatting
[ERR] MGR_MODULE_ERROR: Module 'prometheus' has failed: not all arguments converted during string formatting
    Module 'prometheus' has failed: not all arguments converted during string formatting

Lo hemos solucionado de la siguiente manera:

MGR_POD=$(oc get pod -n rook-ceph -l app=rook-ceph-mgr -o jsonpath='{.items[0].metadata.name}')
ADMIN_KEY=$(oc get secret rook-ceph-mon -n rook-ceph -o jsonpath='{.data.ceph-secret}' | base64 -d)
MON_HOSTS=$(oc get cm rook-ceph-mon-endpoints -n rook-ceph -o jsonpath='{.data.data}' | sed 's/[a-z]=//g')

oc patch cephcluster rook-ceph -n rook-ceph --type merge -p '{"spec":{"mgr":{"modules":[{"name":"prometheus","enabled":false}]}}}'

oc exec -n rook-ceph "$MGR_POD" -c mgr -- bash -c "
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' mgr module disable prometheus
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' config rm mgr mgr/prometheus/server_port 2>/dev/null || true
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' crash archive-all
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' health detail
"

-------------------------------------------------------

[root@bastion 02-rook]# oc exec -it -n rook-ceph deploy/rook-ceph-tools -- ceph status
  cluster:
    id:     7c8bac16-8c17-4ceb-b769-8534197bd6c6
    health: HEALTH_ERR
            Module 'prometheus' has failed: not all arguments converted during string formatting
  ...

[root@bastion 02-rook]# MGR_POD=$(oc get pod -n rook-ceph -l app=rook-ceph-mgr -o jsonpath='{.items[0].metadata.name}')
[root@bastion 02-rook]# ADMIN_KEY=$(oc get secret rook-ceph-mon -n rook-ceph -o jsonpath='{.data.ceph-secret}' | base64 -d)
[root@bastion 02-rook]# MON_HOSTS=$(oc get cm rook-ceph-mon-endpoints -n rook-ceph -o jsonpath='{.data.data}' | sed 's/[a-z]=//g')
[root@bastion 02-rook]# oc exec -n rook-ceph "$MGR_POD" -c mgr -- bash -c "
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' mgr module disable prometheus --force &&
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' crash archive-all &&
  ceph -n client.admin --key='$ADMIN_KEY' --mon-host='$MON_HOSTS' health detail
"


# Al final se ha liado


[root@bastion ~]# oc delete -f ~/manifests/02-rook/ceph-block-sc.yaml
[root@bastion ~]# oc delete -f ~/manifests/02-rook/ceph-filesystem-sc.yaml
[root@bastion ~]# oc delete -f ~/manifests/02-rook/ceph-cluster.yaml

[root@bastion 02-rook]# vim rook-cluster-values.yaml
operatorNamespace: rook-ceph
clusterName: rook-ceph

toolbox:
  enabled: true
  tolerations:
    - key: node-role.kubernetes.io/storage
      operator: Exists
      effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: node-role.kubernetes.io/storage
                operator: Exists

cephClusterSpec:
  cephVersion:
    image: quay.io/ceph/ceph:v20.2.0
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
  dashboard:
    enabled: true
    ssl: true
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/storage
                  operator: Exists
      tolerations:
        - key: node-role.kubernetes.io/storage
          operator: Exists
          effect: NoSchedule
        - key: node.ocs.openshift.io/storage
          operator: Exists
          effect: NoSchedule
  storage:
    storageClassDeviceSets:
      - name: sda-local
        count: 3
        portable: false
        tuneDeviceClass: true
        encrypted: false
        volumeClaimTemplates:
          - metadata:
              name: data
            spec:
              resources:
                requests:
                  storage: 440Gi
              storageClassName: local-block
              volumeMode: Block
              accessModes:
                - ReadWriteOnce

cephBlockPools:
  - name: replicapool
    spec:
      failureDomain: host
      replicated:
        size: 2
        requireSafeReplicaSize: false
      parameters:
        min_size: "1"
    storageClass:
      enabled: true
      name: rook-ceph-block
      isDefault: true
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      volumeBindingMode: Immediate
      parameters:
        imageFormat: "2"
        imageFeatures: layering
        csi.storage.k8s.io/provisioner-secret-name: rook-ceph-csi-rbd-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-ceph-csi-rbd-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-ceph-csi-rbd-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph

cephFileSystems:
  - name: myfs
    spec:
      metadataPool:
        failureDomain: host
        replicated:
          size: 2
          requireSafeReplicaSize: false
        parameters:
          min_size: "1"
      dataPools:
        - name: replicated
          failureDomain: host
          replicated:
            size: 2
            requireSafeReplicaSize: false
          parameters:
            min_size: "1"
      metadataServer:
        activeCount: 1
        activeStandby: true
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: node-role.kubernetes.io/storage
                      operator: Exists
          tolerations:
            - key: node-role.kubernetes.io/storage
              operator: Exists
              effect: NoSchedule
            - key: node.ocs.openshift.io/storage
              operator: Exists
              effect: NoSchedule
    storageClass:
      enabled: true
      name: rook-cephfs
      isDefault: false
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      volumeBindingMode: Immediate
      parameters:
        csi.storage.k8s.io/provisioner-secret-name: rook-ceph-csi-cephfs-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-ceph-csi-cephfs-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-ceph-csi-cephfs-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph

helm upgrade --install \
  rook-ceph-cluster rook-release/rook-ceph-cluster \
  --namespace rook-ceph \
  --version=v1.21.2 \
  -f rook-cluster-values.yaml

for sa in rbd-ctrlplugin-sa rbd-nodeplugin-sa cephfs-ctrlplugin-sa cephfs-nodeplugin-sa; do
  oc adm policy add-scc-to-user privileged -z "$sa" -n rook-ceph
done

