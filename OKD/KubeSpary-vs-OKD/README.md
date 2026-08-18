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