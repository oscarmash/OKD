
Para que el driver CSI de vSphere funcione, las Máquinas Virtuales de los nodos (Control Plane y Workers) deben tener habilitada la propiedad disk.EnableUUID. 
Sin esto, Linux no expone los UUIDs /dev/disk/by-id/ que necesita Kubernetes para identificar el volumen.

Como solucionarlo:
* Apaga los equipos
* En vCenter, haz clic derecho sobre la VM del Worker -> Edit Settings
* Ve a VM Options -> Advanced -> Configuration Parameters -> Edit Configuration.
* Revisa si existe la clave disk.EnableUUID:
  * Si no existe, añádela con el valor TRUE.
  * Si está en FALSE, cámbiala a TRUE.
* Enciende la VM de nuevo.

![Enable disk.EnableUUID](images/disk_EnableUUID.png)

```
[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         False      7d10h
```


Crearemos el storage class:

```
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: thin-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.vsphere.vmware.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  datastore: "stg-1500GB"
EOF
```

```
[root@bastion ~]# oc get sc
NAME                 PROVISIONER              RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
thin-csi (default)   csi.vsphere.vmware.com   Delete          WaitForFirstConsumer   true                   6s
```

Todos los datos de los PVCs, se guardaran en la carpeta "fcd" (First Class Disk) del storage: "stg-1500GB"

Para verificar que todo funciona correctamente, crearemos un pod con su PVC:

```
[root@bastion ~]# oc new-project test-storage \
--display-name="Proyecto prueba almacenamiento" \
--description="Este proyecto es para pruebas almacenamiento."
```

```
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: test-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: thin-csi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test-storage
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:alpine
    volumeMounts:
    - mountPath: "/data"
      name: my-volume
  volumes:
  - name: my-volume
    persistentVolumeClaim:
      claimName: test-pvc
EOF
```








## Troubleshooting

### No hay drivers de vsphere:

El siguiente comando no puede salir vacio:

```
[root@bastion ~]# oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.type}'
None
```

El clúster no sabe que está en vSphere y por no hay pods del driver CSI.

```
oc create secret generic vsphere-creds \
-n openshift-config \
--from-literal=vcsa.ilba.cat.username='administrator@vsphere.local' \
--from-literal=vcsa.ilba.cat.password='C@dinor1988'
```

```
cat <<EOF | oc apply -f -
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  name: cluster
spec:
  platformSpec:
    type: VSphere
    vsphere:
      vcenters:
      - server: vcsa.ilba.cat
        port: 443
        datacenters:
        - HomeLab
EOF
```

```
[root@bastion ~]# oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.type}'
VSphere
```















[root@bastion ~]# oc -n test-storage get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc   Bound    pvc-674fb09e-787d-4012-9365-63cda564603f   1Gi        RWO            thin-csi       81s

[root@bastion ~]# oc -n test-storage get pods
NAME       READY   STATUS    RESTARTS   AGE
test-pod   1/1     Running   0          27m

Ver el PVC en el VC
* Menú superior izquierdo de vSphere, vista de Almacenamiento
* Selecciona tu datastore (stg-1500GB).
* Haz clic en la pestaña Supervisar.
* En el menú lateral de esa pestaña, haz clic en Volúmenes de contenedor.

¡¡¡¡¡¡¡¡¡¡¡¡¡¡ PVC-enlace-VMWare.png !!!!!!!!!!!!!!

------------------------------------------------------------------------------------------------------------------------------------------------------------------

[root@bastion ~]# wget https://get.helm.sh/helm-v4.2.3-linux-amd64.tar.gz
[root@bastion ~]# tar -zxvf helm-v4.2.3-linux-amd64.tar.gz
[root@bastion ~]# mv linux-amd64/helm /usr/local/bin/helm
[root@bastion ~]# rm -rf linux-amd64/

helm repo add netbox https://netbox-community.github.io/netbox-chart/
helm repo update

oc new-project netbox \
--display-name="NetBox IPAM/DCIM" \
--description="Plataforma de gestión de infraestructura e IPAM"

[root@bastion ~]# vim values-netbox.yaml
podAnnotations: {}
podSecurityContext:
  enabled: false
securityContext:
  enabled: false
superuser:
  name: admin
  email: admin@ilba.cat
  password: "C@dinor1988"
secretKey: "una-cadena-aleatoria-y-larga-para-seguridad-de-netbox"
persistence:
  enabled: true
  storageClass: "thin-csi"
  size: 10Gi
ingress:
  enabled: false
postgresql:
  enabled: true
  primary:
    persistence:
      enabled: true
      storageClass: "thin-csi"
      size: 10Gi
redis:
  enabled: true
  master:
    persistence:
      enabled: true
      storageClass: "thin-csi"
      size: 5Gi


helm install netbox netbox/netbox -f values-netbox.yaml -n netbox

[root@bastion ~]# helm -n netbox ls
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
netbox  netbox          1               2026-08-02 07:15:37.35125869 +0200 CEST deployed        netbox-8.3.47   v4.6.7

oc create route edge netbox-web \
--service=netbox \
--port=http \
--hostname=netbox.apps.okd.ilba.cat  \
-n netbox

[root@bastion ~]# oc get route netbox-web -n netbox
NAME         HOST/PORT                  PATH   SERVICES   PORT   TERMINATION   WILDCARD
netbox-web   netbox.apps.okd.ilba.cat          netbox     http   edge          None

[root@bastion ~]# oc get endpoints netbox -n netbox
NAME     ENDPOINTS          AGE
netbox   10.131.0.27:8080   17m


[root@bastion ~]# oc describe rs -l app.kubernetes.io/name=netbox -n netbox | tail -n 25


[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:netbox
[root@bastion ~]# oc rollout restart deployment/netbox -n netbox
[root@bastion ~]# oc rollout restart deployment/netbox-worker -n netbox
[root@bastion ~]# oc adm policy add-scc-to-user privileged -z netbox -n netbox
[root@bastion ~]# oc adm policy add-scc-to-user privileged -z netbox-netbox -n netbox
[root@bastion ~]# oc adm policy add-scc-to-user privileged -z default -n netbox


[root@bastion ~]# helm -n netbox uninstall netbox
[root@bastion ~]# oc delete pvc --all -n netbox
[root@bastion ~]# oc delete project netbox