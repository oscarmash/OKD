# Guía de Ampliación de Clúster OKD / OpenShift (Añadir Nodo Worker3)

Esta guía detalla el procedimiento completo para añadir un nuevo nodo de computación (`worker3.ilba.cat`) a un clúster de OKD / OpenShift desplegado mediante **UPI (User-Provisioned Infrastructure)** sobre VMware vSphere.

El proceso requiere registrar la nueva máquina virtual en los servicios de red del bastión (DNS, DHCP y HAProxy), desplegar el sistema operativo RHCOS/SCOS usando el archivo `worker.ign` generado durante la instalación inicial y aprobar los certificados (CSR) desde el plano de control.

## Índice

* [1. Preparación de los Servicios de Red en el Bastión](#1-preparación-de-los-servicios-de-red-en-el-bastión)
  * [1.1. Configuración de DNS (Bind)](#11-configuración-de-dns-bind)
  * [1.2. Configuración de DHCP](#12-configuración-de-dhcp)
  * [1.3. Actualización del Balanceador de Carga (HAProxy)](#13-actualización-del-balanceador-de-carga-haproxy)
* [2. Creación y Configuración de la Máquina Virtual en vSphere](#2-creación-y-configuración-de-la-máquina-virtual-en-vsphere)
  * [2.1. Especificaciones de Hardware](#21-especificaciones-de-hardware)
  * [2.2. Habilitación del flag disk.EnableUUID](#22-habilitación-del-flag-diskenableuuid)
* [3. Despliegue del Sistema Operativo RHCOS / SCOS](#3-despliegue-del-sistema-operativo-rhcos--scos)
  * [3.1. Ejecución de coreos-installer con worker.ign](#31-ejecución-de-coreos-installer-con-workerign)
  * [3.2. Primer arranque y monitorización del bootstrap local](#32-primer-arranque-y-monitorización-del-bootstrap-local)
* [4. Integración y Aprobación de Certificados (CSR) en OpenShift](#4-integración-y-aprobación-de-certificados-csr-en-openshift)
  * [4.1. Monitorización y aprobación del primer CSR (Cliente)](#41-monitorización-y-aprobación-del-primer-csr-cliente)
  * [4.2. Monitorización y aprobación del segundo CSR (Servidor/Kubelet)](#42-monitorización-y-aprobación-del-segundo-csr-servidorkubelet)
* [5. Verificación del Nodo y Rebalanceo de Cargas](#5-verificación-del-nodo)


## 1. Preparación de los Servicios de Red en el Bastión

### 1.1. Configuración de DNS (Bind)

```
[root@bastion ~]# vim /var/named/ilba.cat.db
[root@bastion ~]# vim /var/named/ilba.cat.reverse
[root@bastion ~]# named-checkconf /etc/named.conf
[root@bastion ~]# systemctl restart named
```

### 1.2. Configuración de DHCP

```
[root@bastion ~]# vim /etc/dhcp/dhcpd.conf
[root@bastion ~]# systemctl restart dhcpd
```

### 1.3. Actualización del Balanceador de Carga (HAProxy)

```
[root@bastion ~]# vim /etc/haproxy/haproxy.cfg
[root@bastion ~]# systemctl restart haproxy
```

## 2. Creación y Configuración de la Máquina Virtual en vSphere

### 2.1. Especificaciones de Hardware

| Parámetro | Valor |
| :--- | :--- |
| **Nombre VM** | `worker3.ilba.cat` |
| **vCPU** | 4 vCPU |
| **Memoria RAM** | 16 GB |
| **Disco** | 120 GB (Thin Provisioning) |
| **Red** | Red de infraestructura OKD ( `10.26.0.0/24` ) |
| **ISO de arranque** | ISO Live de RHCOS / SCOS |

### 2.2. Habilitación del flag disk.EnableUUID

Para que el aprovisionador CSI de vSphere monte almacenamiento de forma dinámica en este nodo, habilita el flag de UUID:

* Apaga la VM (si está encendida).
* Haz clic derecho sobre la VM -> Edit Settings.
* Ve a VM Options -> Advanced -> Configuration Parameters -> Edit Configuration.
* Añade un nuevo parámetro:
  * Key: disk.EnableUUID
  * Value: TRUE
* Guarda los cambios.

## 3. Despliegue del Sistema Operativo RHCOS / SCOS

### 3.1. Ejecución de coreos-installer con worker.ign

Arranca la VM montando la ISO Live de RHCOS/SCOS.
Una vez cargada la consola interactiva en vivo, ejecuta el instalador apuntando al archivo Ignition de los workers alojado en el servidor HTTP del bastión:

```
sudo coreos-installer install /dev/sda \
--ignition-url=http://10.26.0.5:8080/worker.ign \
--insecure-ignition

sudo reboot
```

### 3.2. Primer arranque y monitorización del bootstrap local

Seguir la descarga de paquetes e inicialización del sistema accediendo por SSH desde el bastión:

```
[root@bastion ~]# ssh core@worker3
core@worker3:~$ journalctl -u rpm-ostreed -f      <- Aquí es donde venmos que se va descargando las cosas
```
## 4. Integración y Aprobación de Certificados (CSR) en OpenShift

### 4.1. Monitorización y aprobación del primer CSR (Cliente)

```
[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# oc get nodes
NAME               STATUS     ROLES                  AGE    VERSION
master1.ilba.cat   Ready      control-plane,master   2d2h   v1.34.4
master2.ilba.cat   Ready      control-plane,master   2d2h   v1.34.4
master3.ilba.cat   Ready      control-plane,master   2d2h   v1.34.4
worker1.ilba.cat   Ready      worker                 2d1h   v1.34.4
worker2.ilba.cat   Ready      worker                 2d1h   v1.34.4
worker3.ilba.cat   NotReady   worker                 81s    v1.34.4
```

### 4.2. Monitorización y aprobación del segundo CSR (Servidor/Kubelet)

```
[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve
```

```
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE    VERSION
master1.ilba.cat   Ready    control-plane,master   2d2h   v1.34.4
master2.ilba.cat   Ready    control-plane,master   2d2h   v1.34.4
master3.ilba.cat   Ready    control-plane,master   2d2h   v1.34.4
worker1.ilba.cat   Ready    worker                 2d1h   v1.34.4
worker2.ilba.cat   Ready    worker                 2d1h   v1.34.4
worker3.ilba.cat   Ready    worker                 14m    v1.34.4
```
