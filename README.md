# Documentación de Ilba

## OKD

> **Filosofía principal:** *"Everything is an Operator"* — Equipo de Ingeniería de Red Hat.

### Recursos y Referencias
* Documentación de la Comunidad: [okd.io](https://okd.io)
* Documentación Oficial del Producto: [docs.okd.io](https://docs.okd.io)

### Índice de Contenidos

#### Introducción y Comparativas
* :construction: [KubeSpray vs OKD](./OKD/KubeSpary-vs-OKD/README.md) *(En construcción)*
* :construction: [Mantenimiento diario](./OKD/mantenimiento-diario/README.md) *(En construcción)*

#### Documentación

* [Project vs Namespace](./OKD/DOC/Project_vs_NS/README.md)

#### Instalación y Gestión de Nodos
* [Instalación: UPI (User-Provisioned Infrastructure)](./OKD/Install-UPI/README.md) :one:
* [Añadir nodo al clúster de OKD](./OKD/add_worker/README.md)
* [Configuración de nodos mediante MachineConfig (MCO)](./OKD/MachineConfig/README.md)
* [Cluster Version Operator (CVO)](./OKD/CVO/README.md)

#### Interfaz y Operaciones
* [Identity providers](./OKD/identity_providers/README.md) (Usuarios)
* [Consola Web (GUI)](./OKD/GUI/README.md)
* [Personalización de errores del Ingress](./OKD/Custom_Ingress/README.md)
* [Registry](./OKD/registry/README.md)
* [Insights](./OKD/insights/README.md)
* [SCC (Security Context Constraints)](./OKD/SCC/README.md)
* [Thanos](./OKD/Thanos/README.md)
* Alertmanager
  * [AlertmanagerReceiversNotConfigured](./OKD/Alertmanager/AlertmanagerReceiversNotConfigured/README.md)
  * [ClusterOperatorDown](./OKD/Alertmanager/ClusterOperatorDown/README.md) :two:
* CI/CD
  * [ArgoCD](./OKD/CI_CD/ArgoCD/README.md)
  * [Tekton](./OKD/CI_CD/Tekton/README.md)
* Instalar Apps
  * [LibreNMS](./OKD/APPS/LibreNMS/README.md)
  * [MinIO](./OKD/APPS/MinIO/README.md)
* [KubeVirt](./OKD/KubeVirt/README.md)
* [User Workload Monitoring (UWM)](./OKD/UWM/README.md)

#### Almacenamiento
* [Configuración de vSphere CSI Driver](./OKD/CSI-vSphere/README.md) :three:

#### Redes (OVN-Kubernetes)
* :construction: [NetworkPolicies](./OKD/OVN-Kubernetes/NetworkPolicy/README.md) *(En construcción)*
* [Egress IP Address](./OKD/OVN-Kubernetes/egressIPaddress/README.md)

#### :construction: Cosas a estudiar (sacado del documento PDF) :construction:

* [ODF (OpenShift Data Foundation)](https://docs.redhat.com/en/documentation/red_hat_openshift_data_foundation/4.22) con LSO (Local Storage Operator)
* I/O Scheduler (elevator=none)
* Chronyd (Servicio NTP) con MachineConfig (MCO)
* Pruning
  * ImagePruner
  * Automatizar la limpieza de recursos (oc adm prune / oc adm prune builds)
* KubeletConfig (SystemReserved, Eviction & GarbageCollection)
* Comando "butane"
* [File Integrity Operator](https://docs.okd.io/4.22/security/file_integrity_operator/fio-overview.html)
* [Post-install](https://docs.okd.io/4.22/post_installation_configuration/configuring-private-cluster.html)
* ETCD (disc performance)

```
podman run --volume /var/lib/etcd:/var/lib/etcd:Z quay.io/openshift-scale/etcd-perf:latest
```