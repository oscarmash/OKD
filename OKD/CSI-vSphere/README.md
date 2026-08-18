# Configuración de vSphere CSI Driver en OpenShift / OKD

* [Habilitar `disk.EnableUUID` en vSphere](#habilitar-diskenableuuid-en-vsphere)
* [Verificación del Estado del Clúster y StorageClass](#verificación-del-estado-del-clúster-y-storageclass)
* [Despliegue de Prueba (PVC y Pod)](#despliegue-de-prueba-pvc-y-pod)
* [Procedimientos de Troubleshooting](#procedimientos-de-troubleshooting)
  * [VSphereCSIDriverOperatorCRDegraded](#vspherecsidriveroperatorcrdegraded)

## Habilitar `disk.EnableUUID` en vSphere

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

## Verificación del Estado del Clúster y StorageClass

Verificamos que el operador de almacenamiento responda correctamente y que la StorageClass por defecto (`thin-csi`) esté disponible:

```
[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         False      53s

[root@bastion ~]# oc get sc
NAME                 PROVISIONER              RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
thin-csi (default)   csi.vsphere.vmware.com   Delete          WaitForFirstConsumer   true                   3m32s
```

## Despliegue de Prueba (PVC y Pod)

Todos los datos de los PVCs, se guardaran en la carpeta "fcd" (First Class Disk) del storage: "stg-1500GB"

Para verificar que todo funciona correctamente, crearemos un proyecto dedicado y desplegaremos un Pod con su correspondiente PersistentVolumeClaim (PVC):

```
[root@bastion ~]# oc new-project test-storage \
--display-name="Proyecto prueba almacenamiento" \
--description="Este proyecto es para pruebas almacenamiento."
```

```
[root@bastion ~]# vim manifest/test-storage.yaml
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
```

Aplicamos la configuración y comprobamos el estado de los recursos:

```
[root@bastion ~]# oc apply -f manifest/test-storage.yaml
```

```
[root@bastion ~]# oc -n test-storage get pods
NAME       READY   STATUS    RESTARTS   AGE
test-pod   1/1     Running   0          30s

[root@bastion ~]# oc -n test-storage get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
test-pvc   Bound    pvc-8e308c36-cde7-4ffb-9352-981862fb246d   1Gi        RWO            thin-csi       <unset>                 33s
```
![PVC to Storage VMWare](images/PVC-VMWare.png)

## Procedimientos de Troubleshooting

### VSphereCSIDriverOperatorCRDegraded

**Problema:**

El operador de almacenamiento muestra un estado DEGRADED=True indicando que los nodos no tienen el formato de providerID esperado por vSphere (vsphere://<UUID>):

```
[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         True       22h     VSphereCSIDriverOperatorCRDegraded: VMwareVSphereOperatorCheckDegraded: node master1.ilba.cat is not a vSphere node: providerID "" does not have the expected vSphere prefix "vsphere://"
```

**Solución:**

En instalaciones manuales (UPI), Kubelet puede no asignar automáticamente el providerID de vSphere si la VM no tenía inicialmente habilitado el parámetro disk.EnableUUID="TRUE". Vamos que no está marcado en el VMWare el parámetro disk.EnableUUID con valor "TRUE" al desplegar los equipos.


Ejecutaremos el siguiente script para extraer el systemUUID del nodo e inyectar o actualizar el campo spec.providerID en la API de OKD:

```
[root@bastion ~]# vim fix-diskEnableUUID.sh
#!/bin/bash

for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== Procesando $node ==="
    UUID=$(oc get node $node -o jsonpath='{.status.nodeInfo.systemUUID}')

    if [ -n "$UUID" ]; then
        oc patch node $node -p "{\"spec\":{\"providerID\":\"vsphere://${UUID}\"}}"
        echo "OK: providerID asignado a $node ($UUID)"
    else
        echo "ERROR: No se pudo obtener el systemUUID de $node"
    fi
done
```

```
[root@bastion ~]# chmod 755 fix-diskEnableUUID.sh
[root@bastion ~]# ./fix-diskEnableUUID.sh
[root@bastion ~]# oc rollout restart deployment/cluster-storage-operator -n openshift-cluster-storage-operator

[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.21.0-okd-scos.9   True        False         False      53s
```