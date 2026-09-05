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

#### Instalación y Gestión de Nodos
* [Instalación: UPI (User-Provisioned Infrastructure)](./OKD/Install-UPI/README.md) :one:
* [Añadir nodo al clúster de OKD](./OKD/add_worker/README.md)
* [Configuración de nodos mediante MachineConfig (MCO)](./OKD/MachineConfig/README.md)

#### Interfaz y Operaciones
* [Creación de usuarios](./OKD/users/README.md)
* [Consola Web (GUI)](./OKD/GUI/README.md)
* [Insights](./OKD/insights/README.md)
* Alertmanager
  * [AlertmanagerReceiversNotConfigured](./OKD/Alertmanager/AlertmanagerReceiversNotConfigured/README.md)
  * [ClusterOperatorDown](./OKD/Alertmanager/ClusterOperatorDown/README.md) :two:
* Instalar Apps
  * [LibreNMS](./OKD/APPS/LibreNMS/README.md)
  * [MinIO](./OKD/APPS/MinIO/README.md)

#### Almacenamiento
* [Configuración de vSphere CSI Driver](./OKD/CSI-vSphere/README.md) :three:

#### Redes (OVN-Kubernetes)
* :construction: [NetworkPolicies](./OKD/OVN-Kubernetes/NetworkPolicy/README.md) *(En construcción)*
* [Egress IP Address](./OKD/OVN-Kubernetes/egressIPaddress/README.md)
