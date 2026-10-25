# Índice de contenidos

- [Labels i Taints](#labels-i-taints)
- [Migración de cargas](#migración-de-cargas)
  - [Ingress Controller (HAProxy / Routers)](#ingress-controller-haproxy--routers)
  - [Image Registry](#image-registry)
  - [Stack de Monitorización (Prometheus, Alertmanager, etc...)](#stack-de-monitorización-prometheus-alertmanager-etc)
  - [Stack de Monitorización (UWM)](#stack-de-monitorización-uwm)
  - [Consola web](#consola-web)
- [Validación final](#validación-final)

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

```
[root@bastion ~]# oc get co ingress
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
ingress   4.21.0-okd-scos.9   True        False         False      23m
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

```
[root@bastion ~]# oc get co image-registry
NAME             VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
image-registry   4.21.0-okd-scos.9   True        False         False      19h
```

## Stack de Monitorización (Prometheus, Alertmanager, etc...)

```
[root@bastion ~]# vim infra/manifest/cluster-monitoring-infra.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    thanosQuerier:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    openshiftStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    monitoringPlugin:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    metricsServer:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
```

```
[root@bastion ~]# oc apply -f infra/manifest/cluster-monitoring-infra.yaml
```

```
[root@bastion ~]# oc delete pod -l app.kubernetes.io/name=monitoring-plugin -n openshift-monitoring
[root@bastion ~]# oc delete pod -l app.kubernetes.io/name=metrics-server -n openshift-monitoring
[root@bastion ~]# oc rollout restart deployment/cluster-monitoring-operator -n openshift-monitoring
```

Los siguientes pods han  de estar es el worker1.ilba.cat y el worker2.ilba.cat:


```
[root@bastion ~]# oc get pods -n openshift-monitoring -o wide | grep -E "alertmanager-main|metrics-server|openshift-state-metrics"
alertmanager-main-0                                      6/6     Running   0          5m35s   10.129.2.19   worker2.ilba.cat   <none>           <none>
alertmanager-main-1                                      6/6     Running   0          6m58s   10.128.2.11   worker1.ilba.cat   <none>           <none>
metrics-server-6c66fb5c49-gv25l                          0/1     Running   0          2m35s   10.128.2.16   worker1.ilba.cat   <none>           <none>
metrics-server-6c66fb5c49-vnc9h                          0/1     Running   0          2m35s   10.129.2.21   worker2.ilba.cat   <none>           <none>
openshift-state-metrics-b5c8dc674-lv24v                  3/3     Running   0          3m14s   10.128.2.14   worker1.ilba.cat   <none>           <none>
```

```
[root@bastion ~]# oc get co monitoring
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
monitoring   4.21.0-okd-scos.9   True        False         False      12m
```

## Stack de Monitorización (UWM)

```
[root@bastion ~]# vim infra/manifest/uwm-infra.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    prometheus:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
    thanosRuler:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
        - key: "node-role.kubernetes.io/infra"
          operator: "Exists"
          effect: "NoSchedule"
```

```
[root@bastion ~]# oc apply -f infra/manifest/uwm-infra.yaml
```

```
[root@bastion ~]# oc rollout restart deployment/prometheus-operator -n openshift-user-workload-monitoring

[root@bastion ~]# oc get pods -n openshift-user-workload-monitoring -o wide
NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
prometheus-operator-b599b67c8-wgskl   2/2     Running   0          16s   10.128.2.21   worker1.ilba.cat   <none>           <none>
prometheus-user-workload-0            5/6     Running   0          9s    10.129.2.23   worker2.ilba.cat   <none>           <none>
prometheus-user-workload-1            6/6     Running   0          28s   10.128.2.19   worker1.ilba.cat   <none>           <none>
thanos-ruler-user-workload-0          4/4     Running   0          23s   10.129.2.22   worker2.ilba.cat   <none>           <none>
thanos-ruler-user-workload-1          4/4     Running   0          26s   10.128.2.20   worker1.ilba.cat   <none>           <none>

[root@bastion ~]# oc get co monitoring
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
monitoring   4.21.0-okd-scos.9   True        False         False      51m
```

## Consola web

```
[root@bastion ~]# vim infra/manifest/console-infra.yaml
apiVersion: operator.openshift.io/v1
kind: Console
metadata:
  name: cluster
spec:
  nodePlacement:
    nodeSelector:
      node-role.kubernetes.io/infra: ""
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"
```

```
[root@bastion ~]# oc apply -f infra/manifest/console-infra.yaml
```

```
[root@bastion ~]# oc rollout restart deployment/console -n openshift-console
[root@bastion ~]# oc rollout restart deployment/downloads -n openshift-console
```

```
[root@bastion ~]# oc get pods -n openshift-console -o wide
NAME                         READY   STATUS    RESTARTS   AGE    IP            NODE               NOMINATED NODE   READINESS GATES
console-8654b4546c-gmmn8     1/1     Running   2          35h    10.129.0.41   master2.ilba.cat   <none>           <none>
console-8654b4546c-q52xz     1/1     Running   0          103s   10.130.0.9    master1.ilba.cat   <none>           <none>
downloads-7c48fc4584-lkn4f   1/1     Running   0          8s     10.130.0.10   master1.ilba.cat   <none>           <none>
downloads-7c48fc4584-r7ws7   1/1     Running   2          35h    10.129.0.27   master2.ilba.cat   <none>           <none>

[root@bastion ~]# oc get co console
NAME      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
console   4.21.0-okd-scos.9   True        False         False      43h
```

# Validación final

```
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   35h   v1.34.4
master2.ilba.cat   Ready    control-plane,master   35h   v1.34.4
master3.ilba.cat   Ready    control-plane,master   35h   v1.34.4
worker1.ilba.cat   Ready    infra                  43h   v1.34.4
worker2.ilba.cat   Ready    infra                  43h   v1.34.4
worker3.ilba.cat   Ready    worker                 43h   v1.34.4
worker4.ilba.cat   Ready    worker                 43h   v1.34.4
```

```
[root@bastion ~]# oc get co
NAME                                       VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
authentication                             4.21.0-okd-scos.9   True        False         False      14m
baremetal                                  4.21.0-okd-scos.9   True        False         False      44h
cloud-controller-manager                   4.21.0-okd-scos.9   True        False         False      44h
cloud-credential                           4.21.0-okd-scos.9   True        False         False      44h
cluster-autoscaler                         4.21.0-okd-scos.9   True        False         False      44h
config-operator                            4.21.0-okd-scos.9   True        False         False      44h
console                                    4.21.0-okd-scos.9   True        False         False      43h
control-plane-machine-set                  4.21.0-okd-scos.9   True        False         False      39h
csi-snapshot-controller                    4.21.0-okd-scos.9   True        False         False      44h
dns                                        4.21.0-okd-scos.9   True        False         False      44h
etcd                                       4.21.0-okd-scos.9   True        False         False      43h
image-registry                             4.21.0-okd-scos.9   True        False         False      19h
ingress                                    4.21.0-okd-scos.9   True        False         False      14m
insights                                   4.21.0-okd-scos.9   True        False         False      44h
kube-apiserver                             4.21.0-okd-scos.9   True        False         False      43h
kube-controller-manager                    4.21.0-okd-scos.9   True        False         False      43h
kube-scheduler                             4.21.0-okd-scos.9   True        False         False      43h
kube-storage-version-migrator              4.21.0-okd-scos.9   True        False         False      14m
machine-api                                4.21.0-okd-scos.9   True        False         False      43h
machine-approver                           4.21.0-okd-scos.9   True        False         False      44h
machine-config                             4.21.0-okd-scos.9   True        False         False      44h
marketplace                                4.21.0-okd-scos.9   True        False         False      44h
monitoring                                 4.21.0-okd-scos.9   True        False         False      5m
network                                    4.21.0-okd-scos.9   True        False         False      44h
node-tuning                                4.21.0-okd-scos.9   True        False         False      35h
olm                                        4.21.0-okd-scos.9   True        False         False      39h
openshift-apiserver                        4.21.0-okd-scos.9   True        False         False      15m
openshift-controller-manager               4.21.0-okd-scos.9   True        False         False      43h
openshift-samples                          4.21.0-okd-scos.9   True        False         False      43h
operator-lifecycle-manager                 4.21.0-okd-scos.9   True        False         False      44h
operator-lifecycle-manager-catalog         4.21.0-okd-scos.9   True        False         False      44h
operator-lifecycle-manager-packageserver   4.21.0-okd-scos.9   True        False         False      14m
service-ca                                 4.21.0-okd-scos.9   True        False         False      44h
storage                                    4.21.0-okd-scos.9   True        False         False      12m
```