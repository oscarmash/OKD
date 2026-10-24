# Labels i Taints

```
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   13h   v1.34.4
master2.ilba.cat   Ready    control-plane,master   14h   v1.34.4
master3.ilba.cat   Ready    control-plane,master   13h   v1.34.4
worker1.ilba.cat   Ready    worker                 22h   v1.34.4
worker2.ilba.cat   Ready    worker                 22h   v1.34.4
worker3.ilba.cat   Ready    worker                 22h   v1.34.4
worker4.ilba.cat   Ready    worker                 22h   v1.34.4
```

No es aconsejable quitar el rol worker, de lo contrario, worker1 y worker2 se quedarían "huérfanos" de configuraciones del Machine Config Operator y no recibirían actualizaciones ni configuraciones del sistema operativo. Por eso crearemos una nueva MCP (MachineConfigPool)

```
[root@bastion ~]# oc label node worker1.ilba.cat node-role.kubernetes.io/infra=""
[root@bastion ~]# oc label node worker2.ilba.cat node-role.kubernetes.io/infra=""

[root@bastion ~]# oc label node worker1.ilba.cat node-role.kubernetes.io/worker-
[root@bastion ~]# oc label node worker2.ilba.cat node-role.kubernetes.io/worker-

[root@bastion ~]# oc adm taint nodes worker1.ilba.cat node-role.kubernetes.io/infra:NoSchedule --overwrite
[root@bastion ~]# oc adm taint nodes worker2.ilba.cat node-role.kubernetes.io/infra:NoSchedule --overwrite
```

```
[root@bastion ~]# mkdir infra/manifest -p
[root@bastion ~]# vim infra/manifest/mcp_infra.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: infra
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,infra]}
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/infra: ""

[root@bastion ~]# oc apply -f infra/manifest/mcp_infra.yaml
```

```
[root@bastion ~]# oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
infra    rendered-infra-35819a03217b78066601f159b430dcea    True      False      False      2              2                   2                     0                      99s
master   rendered-master-40e731a6229544cde9d572c9816da07a   True      False      False      3              3                   3                     0                      23h
worker   rendered-worker-35819a03217b78066601f159b430dcea   True      False      False      4              4                   4                     0                      23h
```

```
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   14h   v1.34.4
master2.ilba.cat   Ready    control-plane,master   14h   v1.34.4
master3.ilba.cat   Ready    control-plane,master   14h   v1.34.4
worker1.ilba.cat   Ready    infra                  22h   v1.34.4
worker2.ilba.cat   Ready    infra                  22h   v1.34.4
worker3.ilba.cat   Ready    worker                 22h   v1.34.4
worker4.ilba.cat   Ready    worker                 22h   v1.34.4
```

# Migración de cargas

## Ingress Controller (HAProxy / Routers)

```
[root@bastion ~]# vim infra/manifest/ingresscontroller-infra.yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"

[root@bastion ~]# oc apply -f infra/manifest/ingresscontroller-infra.yaml
```

```
[root@bastion ~]# oc get pods -n openshift-ingress -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
router-default-78c7b64799-pjmsw   1/1     Running   0          55s   10.26.0.21   worker1.ilba.cat   <none>           <none>
router-default-78c7b64799-znlw2   1/1     Running   0          93s   10.26.0.22   worker2.ilba.cat   <none>           <none>
```

```
[root@bastion ~]# dnf install -y socat

[root@bastion ~]# echo "show stat" | socat stdio /var/lib/haproxy/stats | grep -E "^okd_http_ingress_backend|^okd_https_ingress_backend" | grep -v ",BACKEND," | awk -F',' '{printf "%-28s %-10s %s\n", $1, $2, $18}'
okd_http_ingress_backend     worker1    UP
okd_http_ingress_backend     worker2    UP
okd_http_ingress_backend     worker3    DOWN
okd_http_ingress_backend     worker4    DOWN
okd_https_ingress_backend    worker1    UP
okd_https_ingress_backend    worker2    UP
okd_https_ingress_backend    worker3    DOWN
okd_https_ingress_backend    worker4    DOWN
```

## Image Registry

Para ver el comportamiento del operator del registry, lanzaremos el siguiente comando

```
[root@bastion ~]# oc get configs.imageregistry.operator.openshift.io/cluster -o jsonpath='{.spec.managementState}{"\n"}'
Removed
```

Posibles salidas:
* Removed: el operador no debe crear ni mantener activo el servicio. Si hubiera pods o despliegues del registro creados, los eliminaría automáticamente.
* Managed: le ordena al operador: "Toma el control, crea el Deployment/Pod del registro, monitoriza su salud y asegúrate de que esté siempre en ejecución".
* Unmanaged: el operador se desentiende y deja que el administrador gestione los manifiestos manualmente sin intervenir.

Activamos el registro de imágenes:

```
[root@bastion ~]# oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"managementState":"Managed"}}'
```

```
[root@bastion ~]# vim infra/manifest/image-registry-infra.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: thin-csi
---
apiVersion: imageregistry.operator.openshift.io/v1
kind: Config
metadata:
  name: cluster
spec:
  managementState: Managed
  replicas: 1
  rolloutStrategy: Recreate
  nodeSelector:
    node-role.kubernetes.io/infra: ""
  tolerations:
    - key: "node-role.kubernetes.io/infra"
      operator: "Exists"
      effect: "NoSchedule"
  storage:
    pvc:
      claim: "image-registry-storage"

[root@bastion ~]# oc apply -f infra/manifest/image-registry-infra.yaml

[root@bastion ~]# oc get pvc -n openshift-image-registry
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
image-registry-storage   Bound    pvc-278202e3-70ef-4273-b22b-2293f85cf263   100Gi      RWO            thin-csi       <unset>                 5
```

```
[root@bastion ~]# oc get pods -n openshift-image-registry -o wide
NAME                                               READY   STATUS    RESTARTS   AGE    IP            NODE               NOMINATED NODE   READINESS GATES
...
image-registry-7d4645b44f-k78xf                    1/1     Running   0          2m1s   10.129.2.12   worker2.ilba.cat   <none>           <none>
...
```

## Stack de Monitorización (Prometheus, Alertmanager, etc...)
































[root@bastion ~]# oc get co monitoring
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
monitoring   4.21.0-okd-scos.9   False       True          True       19m     UpdatingThanosQuerier: reconciling Thanos Querier Deployment failed: updating Deployment object failed: waiting for DeploymentRollout of openshift-monitoring/thanos-querier: context deadline exceeded: got 1 unavailable replicas, UpdatingConsolePluginComponents: reconciling Console Plugin Deployment failed: updating Deployment object failed: waiting for DeploymentRollout of openshift-monitoring/monitoring-plugin: context deadline exceeded: got 1 unavailable replicas

