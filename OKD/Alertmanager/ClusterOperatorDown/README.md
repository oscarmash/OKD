## Índice

- [ClusterOperatorDown](#clusteroperatordown)
  - [control-plane-machine-set](#control-plane-machine-set)
  - [dns](#dns)
  - [csi-snapshot-controller](#csi-snapshot-controller)
  - [service-ca](#service-ca)
  - [olm](#olm)
  - [monitoring](#monitoring)
  - [machine-config](#machine-config)
  - [kube-apiserver](#kube-apiserver)

# ClusterOperatorDown

En el Dashboard de la consola GUI de OKD, podemos ver el siguiente mensajes: **"ClusterOperatorDown"**

![ClusterOperatorDown](images/ClusterOperatorDown.png)

## control-plane-machine-set

```
[root@bastion ~]# oc get co control-plane-machine-set
NAME                        VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
control-plane-machine-set   4.21.0-okd-scos.9   False       False         True       19h     Missing 3 available replica(s)

[root@bastion ~]# oc delete controlplanemachineset cluster -n openshift-machine-api

[root@bastion ~]# oc get co control-plane-machine-set
NAME                        VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
control-plane-machine-set   4.21.0-okd-scos.9   True        False         False      16s
```

## dns

```
[root@bastion ~]#  oc get co dns
NAME   VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
dns    4.21.0-okd-scos.9   True        True          False      19h     DNS "default" reports Progressing=True: "Have 6 available DNS pods, want 7."

[root@bastion ~]# oc get pods -n openshift-dns -o wide
NAME                  READY   STATUS    RESTARTS      AGE   IP            NODE               NOMINATED NODE   READINESS GATES
dns-default-4lx7d     2/2     Running   4             18h   10.130.2.7    worker4.ilba.cat   <none>           <none>
dns-default-6zrrb     2/2     Running   4             18h   10.128.2.7    worker1.ilba.cat   <none>           <none>
dns-default-7v4rn     2/2     Running   4             18h   10.129.2.7    worker3.ilba.cat   <none>           <none>
dns-default-drq7n     1/2     Running   23 (5s ago)   19h   10.128.0.18   master3.ilba.cat   <none>           <none>
dns-default-kd82l     2/2     Running   4             19h   10.129.0.56   master1.ilba.cat   <none>           <none>
dns-default-qdwl7     2/2     Running   4             18h   10.131.0.6    worker2.ilba.cat   <none>           <none>
dns-default-znn74     2/2     Running   2             65m   10.130.0.23   master2.ilba.cat   <none>           <none>
node-resolver-58qh5   1/1     Running   2             18h   10.26.0.21    worker1.ilba.cat   <none>           <none>
node-resolver-5hx2r   1/1     Running   2             18h   10.26.0.22    worker2.ilba.cat   <none>           <none>
node-resolver-8x69t   1/1     Running   2             18h   10.26.0.23    worker3.ilba.cat   <none>           <none>
node-resolver-9pfld   1/1     Running   2             19h   10.26.0.13    master3.ilba.cat   <none>           <none>
node-resolver-lgtxp   1/1     Running   2             19h   10.26.0.11    master1.ilba.cat   <none>           <none>
node-resolver-n8dzr   1/1     Running   2             18h   10.26.0.24    worker4.ilba.cat   <none>           <none>
node-resolver-tmkrn   1/1     Running   1             68m   10.26.0.12    master2.ilba.cat   <none>           <none>

[root@bastion ~]# oc delete pod dns-default-drq7n -n openshift-dns

[root@bastion ~]# oc get co dns
NAME   VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
dns    4.21.0-okd-scos.9   True        False         False      19h
```

## csi-snapshot-controller

```
[root@bastion ~]# oc get co csi-snapshot-controller
NAME                      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
csi-snapshot-controller   4.21.0-okd-scos.9   False       False         False      3m14s   CSISnapshotControllerAvailable: Waiting for Deployment

[root@bastion ~]# oc delete pods -n openshift-cluster-storage-operator -l app=csi-snapshot-controller

[root@bastion ~]# oc get co csi-snapshot-controller
NAME                      VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
csi-snapshot-controller   4.21.0-okd-scos.9   True        False         False      14s
```

## service-ca

```
[root@bastion ~]# oc get co service-ca
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
service-ca   4.21.0-okd-scos.9   True        True          False      19h     Progressing: ...

[root@bastion ~]# oc rollout restart deployment/service-ca-operator -n openshift-service-ca-operator
[root@bastion ~]# oc rollout restart deployment/service-ca -n openshift-service-ca

[root@bastion ~]# oc get co service-ca
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
service-ca   4.21.0-okd-scos.9   True        False         False      19h
```

## olm

El operador olm gestiona dos componentes independientes:
* catalogd
* operator-controller

```
[root@bastion ~]# oc get co olm
NAME   VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
olm    4.21.0-okd-scos.9   False       False         False      74m     CatalogdDeploymentCatalogdControllerManagerAvailable: Waiting for Deployment...
```

**catalogd**

```
[root@bastion ~]# oc rollout restart deployment/catalogd-controller-manager -n openshift-catalogd

[root@bastion ~]# oc get pods -n openshift-catalogd
NAME                                          READY   STATUS    RESTARTS   AGE
catalogd-controller-manager-b5b8c6b9f-r8lpd   1/1     Running   0          3m50s
```

**openshift-operator-controller**

```
[root@bastion ~]# oc rollout restart deployment/operator-controller-controller-manager -n openshift-operator-controller

[root@bastion ~]# oc get pods -n openshift-operator-controller
NAME                                                     READY   STATUS    RESTARTS   AGE
operator-controller-controller-manager-f88b988bc-878gh   1/1     Running   0          35s

[root@bastion ~]# oc get co olm
NAME   VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
olm    4.21.0-okd-scos.9   True        False         False      68s
```

## monitoring


```
[root@bastion ~]# oc get co monitoring
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
monitoring   4.21.0-okd-scos.9   False       True          True       68m     UpdatingPrometheusOperator: reconciling Prometheus Operator Admission Webhook Deployment failed: updating Deployment object failed: waiting for DeploymentRollout of openshift-monitoring/prometheus-operator-admission-webhook: context deadline exceeded: got 1 unavailable replicas

[root@bastion ~]# oc delete pod -n openshift-monitoring -l app=cluster-monitoring-operator
[root@bastion ~]# oc rollout restart deployment/prometheus-operator-admission-webhook -n openshift-monitoring
[root@bastion ~]# oc rollout restart deployment/cluster-monitoring-operator -n openshift-monitoring

[root@bastion ~]# oc get pods -n openshift-monitoring | grep -E 'webhook|prometheus-operator'
prometheus-operator-6b8c6fc988-hzqrz                    2/2     Running            0                13s
prometheus-operator-admission-webhook-9d5d9d98b-hfplw   1/1     Running            0                55s
prometheus-operator-admission-webhook-9d5d9d98b-vw2k2   1/1     Running            0                55s

[root@bastion ~]# oc get co monitoring
NAME         VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
monitoring   4.21.0-okd-scos.9   True        False         False      28s
```

## machine-config

```
[root@bastion ~]# oc get co machine-config
NAME             VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
machine-config   4.21.0-okd-scos.9   True        False         True       20h     Failed to resync 4.21.0-okd-scos.9 because: error during waitForControllerConfigToBeCompleted: [context deadline exceeded, controllerconfig is not completed: status for ControllerConfig machine-config-controller is being reported for 2, expecting it for 3]

[root@bastion ~]# oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-40e731a6229544cde9d572c9816da07a   False     True       False      3              1                   1                     0                      20h
worker   rendered-worker-35819a03217b78066601f159b430dcea   True      False      False      4              4                   4                     0                      20h
```

## kube-apiserver

```
[root@bastion ~]# oc get co kube-apiserver
NAME             VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
kube-apiserver   4.21.0-okd-scos.9   True        True          False      22h     NodeInstallerProgressing: 1 node is at revision 9; 2 nodes are at revision 10
```

Este mensaje no es un error crítico, sino un estado informativo normal de OpenShift/OKD.

Indica que el operador de la API de Kubernetes (kube-apiserver) está realizando un despliegue progresivo (rollout) de una nueva configuración en los nodos del plano de control (control-plane / másters).