# Operators de OKD

Operadores nativos que componen OKD:
* Cluster Version Operator (CVO): El "jefe de jefes". Se encarga de supervisar a todos los demás operadores y gestionar las actualizaciones de versión de la plataforma.
* Machine Config Operator (MCO): Gestiona Fedora CoreOS. Si necesitas cambiar una regla de Kernel, un archivo en /etc o la configuración de cri-o/kubelet, creas un objeto MachineConfig y el MCO se encarga de aplicarlo y reiniciar el nodo de forma ordenada.
* Network Operator / OVN-Kubernetes: Se encarga de desplegar y mantener la red CNI, las NetworkPolicies, EgressIPs, etc.
* Storage Operator: Mantiene los controladores CSI (como el de vSphere) para el aprovisionamiento dinámico de volúmenes.
* Cluster Monitoring Operator (CMO): Despliega y mantiene Prometheus, Alertmanager y los dashboards de la consola.
* Ingress / Router Operator: Despliega y escala los routers HAProxy internos para exponer las aplicaciones hacia el exterior.
* Authentication / OAuth Operator: Gestiona la integración con proveedores de identidad (LDAP, OIDC, HTPasswd) y la emisión de tokens.

# KubeSpary vs OKD

Diferencias:
* MCP (Machine Config Pools)
* SCC (Security Context Constraints)
* OLM (Operator Lifecycle Manager)
* ArgoCD (Red Hat OpenShift GitOps)

# MCP (Machine Config Pools)

En OpenShift/OKD, las MCP (Machine Config Pools):
* Representan el grupo de nodos (master y worker) y la configuración a nivel de sistema operativo (RHEL CoreOS) que deben tener aplicada.
* El MCP te garantiza homogeneidad absoluta e inmutabilidad en la infraestructura
* Cuando actualizas el clúster de OKD, no solo se actualiza la versión de Kubernetes, también se actualiza el sistema operativo de las máquinas. El MCP se encarga de coordinar la actualización de los nodos de 1 en 1 (haciendo cordon, drain, reboot si aplica, y uncordon).
* Personalización masiva: Si necesitas, por ejemplo, que todos tus workers tengan un valor concreto en sysctl (net.ipv4.ip_forward=1), en lugar de ir nodo por nodo, creas un MachineConfig, lo vinculas al pool worker, y el MCP se encarga de desplegarlo en los 50 workers que pudieras tener.

```
[root@bastion ~]# oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-f394f6962b5c73d456b82f7f879702c4   False     True       False      3              0                   0                     0                      28h
worker   rendered-worker-3c14a25be6380feebd1c35292aeeb2b1   False     True       False      2              0                   0                     0                      28h
```

# Security Context Constraints (SCC)

OKD prohíbe que un pod corra como root y le asigna un UID aleatorio dentro de un rango específico del namespace.

```
[root@bastion ~]# oc adm policy add-scc-to-user anyuid -z default -n test-hello-world
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:anyuid added: "default"

[root@bastion ~]# oc rollout restart deployment -n test-hello-world
```

OKD viene con un conjunto de SCCs predefinidas con distintos niveles de restricción:
* restricted-v2 (default) -> No permite ejecutar como root, asigna UIDs aleatorios en un rango alto asignado al namespace y prohíbe anotaciones inseguras (seccomp).
* anyuid -> Permite que los contenedores se ejecuten con cualquier UID definido en la imagen (por ejemplo, UID 1000 o root), pero mantiene restricciones sobre el host.
* privileged -> Otorga acceso total. El contenedor puede ejecutar como root, acceder a dispositivos del host, ignorar comprobaciones de seccomp y aplicar cualquier configuración de red o volumen.

# Operator Lifecycle Manager (OLM)

Arquitectura:

CatalogSource -> Subscription -> InstallPlan -> ClusterServiceVersion

* CatalogSource: El repositorio o catálogo que expone la lista de Operators disponibles y sus versiones para el cluster.
* Subscription: El recurso donde indicas qué Operator del catálogo quieres instalar, en qué canal y cómo actualizarlo.
* InstallPlan: La lista de ejecución generada por OLM con los manifests exactos (CRDs, RBAC, Deployments) pendientes de aplicar.
* ClusterServiceVersion (CSV): El estado activo de la instalación que contiene los metadatos y despliega el pod del Operator.

## CatalogSource

```
[root@bastion ~]# oc get catalogsource -n openshift-marketplace
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     2d22h
```

```
[root@bastion ~]# oc get packagemanifests | grep -iE "logging|vector|fluent"
neuvector-community-operator                Community Operators   2d23h
ack-s3vectors-controller                    Community Operators   2d23h
logging-operator                            Community Operators   2d23h
```

## Subscription

Le indica a OLM que deje de rastrear, reconciliar o buscar actualizaciones para ese paquete.

```
$ oc delete sub logging-operator -n openshift-operators
```

## InstallPlan

## ClusterServiceVersion

Al borrar el CSV, el controller de OLM detecta su ausencia y elimina en cascada los recursos de ejecución asociados: el Deployment del Controller, sus ServiceAccounts, Roles y ClusterRoleBindings.

```
oc delete csv logging-operator.v0.4.0 -n openshift-operators
```