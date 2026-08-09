
██╗██████╗ ██╗    ██╗   ██╗███████╗       ██╗   ██╗██████╗ ██╗
██║██╔══██╗██║    ██║   ██║██╔════╝       ██║   ██║██╔══██╗██║
██║██████╔╝██║    ██║   ██║███████╗       ██║   ██║██████╔╝██║
██║██╔═══╝ ██║    ╚██╗ ██╔╝╚════██║       ██║   ██║██╔═══╝ ██║
██║██║     ██║     ╚████╔╝ ███████║██╗    ╚██████╔╝██║     ██║
╚═╝╚═╝     ╚═╝      ╚═══╝  ╚══════╝╚═╝     ╚═════╝ ╚═╝     ╚═╝


IPI (Installer-Provisioned Infrastructure) -> El instalador de OKD se conecta a la API de vCenter, crea la red, descarga/clona la plantilla de CoreOS), crea la VM Bootstrap, crea los 3 Masters y los Workers.
UPI (User-Provisioned Infrastructure) -> El administrador (tú) crea y gestiona manualmente toda la infraestructura (redes, balanceador de carga como HAProxy, registros DNS en Bind/Unbound, almacenamiento y las propias máquinas virtuales en vCenter o servidores físicos


███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗ 
████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝ 
██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ ██║██╔██╗ ██║██║  ███╗
██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗ ██║██║╚██╗██║██║   ██║
██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝
╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

NO ES ACONSEJABLE CAMBIAR A CILIUM -> Probado en cada release, integrado con la consola y herramientas nativas.

Por defecto, OpenShift y OKD (desde la versión 4.12+) instalan OVN-Kubernetes (Open Virtual Network).
Es la evolución sobre OpenFlow/OpenvSwitch que soporta políticas de red complejas, cifrado IPSec y aceleración por hardware.

Para poner cilium, hay que modificar el fichero: install-config.yaml

networking:
  networkType: Cilium
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  serviceNetwork:
    - 172.30.0.0/16

OVN-Kubernetes:
* No usa iptables, usa OpenFlow. Esto hace que sea infinitamente más escalable.
* Utilizando iptables en los nodos para ciertas tareas puntuales: MASQUERADE/NAT o NodePort



██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗  ██████╗██╗ ██████╗ ███╗   ██╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██╔══██╗██╔════╝██║██╔═══██╗████╗  ██║
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ███████║██║     ██║██║   ██║██╔██╗ ██║
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██╔══██║██║     ██║██║   ██║██║╚██╗██║
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗██║  ██║╚██████╗██║╚██████╔╝██║ ╚████║
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝

Lo hemos instalado por UPI (User-Provisioned Infrastructure):

dnf install -y haproxy httpd dhcp-server wget open-vm-tools bind-utils

vim /etc/httpd/conf/httpd.conf
vim /etc/haproxy/haproxy.cfg
vim /etc/dhcp/dhcpd.conf

vim /etc/named.conf
vim /var/named/ilba.cat.db
vim /var/named/ilba.cat.reverse

chown named:named /var/named/ilba.cat.db
chown named:named /var/named/ilba.cat.reverse

named-checkconf /etc/named.conf

systemctl disable firewalld
systemctl enable vmtoolsd --now
systemctl enable httpd --now
systemctl enable haproxy --now
systemctl enable dhcpd --now
systemctl enable named --now

mkdir ~/okd-install
cd ~/okd-install/

# Cuidado que se ha de mapear la versión de OKD con K8s (https://github.com/okd-project/okd/releases):
* OpenShift/OKD 4.14 -> Kubernetes 1.27
* OpenShift/OKD 4.15 -> Kubernetes 1.28
* OpenShift/OKD 4.16 -> Kubernetes 1.29
* etc....

wget https://github.com/okd-project/okd/releases/download/4.21.0-okd-scos.9/openshift-client-linux-4.21.0-okd-scos.9.tar.gz
wget https://github.com/okd-project/okd/releases/download/4.21.0-okd-scos.9/openshift-install-linux-4.21.0-okd-scos.9.tar.gz


tar -xvf openshift-client-linux-*.tar.gz
tar -xvf openshift-install-linux-*.tar.gz

mv oc kubectl openshift-install /usr/local/bin/
rm README.md

ssh-keygen -t rsa -b 4096 -C "root@bastion.ilba.cat"

mkdir ~/cluster-okd
cd ~/cluster-okd

vi install-config.yaml

apiVersion: v1
baseDomain: ilba.cat
metadata:
  name: okd
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
platform:
  none: {}
fips: false
pullSecret: '{"auths":{"fake":{"auth":"aG9sYTo="}}}'
sshKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ.........XqriMUSNw== root@bastion.ilba.cat'

cp install-config.yaml install-config.yaml.bak

openshift-install create manifests --dir=.
openshift-install create ignition-configs --dir=.

cp *.ign /var/www/html/
chmod 644 /var/www/html/*.ign

# Verificar que las DNS funcionan correctamente:
# dig +short api.okd.ilba.cat @127.0.0.1      -> 10.26.0.5
# dig +short api-int.okd.ilba.cat @127.0.0.1  -> 10.26.0.5
# dig +short master1.ilba.cat @127.0.0.1      -> 10.26.0.11
# dig +short -x 10.26.0.10 @127.0.0.1         -> bootstrap.ilba.cat.
# dig +short -x 10.26.0.21 @127.0.0.1         -> worker1.ilba.cat.


###################################################################
# Bootstrap                 1     4vCPU     16GB    120GB Disco (thin)    CD ISO
# Control Plane (Master)    3                                     
# Compute (Worker)          2                                     
###################################################################

# Resumen total de ancho de banda consumido:
# * Por cada Worker: Descarga un total aproximado de 4.5 GB a 5.5 GB.
# * Por cada Master: Descarga un total aproximado de 5.0 GB a 6.0 GB.
# Se acaba descargando un total acumulado de unos 25 GB - 30 GB de tráfico de red para montar el clúster entero desde cero.


------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Como saber la ISO del Sistema Operativo que hemos de usar

[root@bastion ~]# openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats.iso.disk.location'
https://rhcos.mirror.openshift.com/art/storage/prod/streams/c10s/builds/10.0.20251103-0/x86_64/scos-10.0.20251103-0-live-iso.x86_64.iso

# Arrancamos bootstrap (recuerda que es un equipo temporal) y lanzamos el siguiente comando:

sudo coreos-installer install /dev/sda \
  --ignition-url=http://10.26.0.5:8080/bootstrap.ign \
  --insecure-ignition

sudo reboot

[root@bastion ~]# ssh core@bootstrap
core@bootstrap:~$ journalctl -u rpm-ostreed -f  <- Aquí es donde venmos que se va descargando las cosas

# Una vez acabado (tarda 10min + o - el comando anterior), se reiniciará solo y una vez arrancado: esperar 20min, sino el master irá dando errores

core@bootstrap:~$ sudo journalctl -b -u bootkube.service -f

# Pasados lo 20 minutos podremos lanzar el siguiente comando
# EL tiempo (until 8:43AM CEST), es indicativo, quiere decir: 
#   Voy a quedarme escuchando a la API durante un máximo de 1 hora. 
#   Si en 60 minutos los 3 másters no han terminado de descargar sus pods, daré el comando por fallado (timeout) y te devolveré el control del prompt

[root@bastion ~]# openshift-install wait-for bootstrap-complete --dir=/root/cluster-okd/ --log-level=info
INFO Waiting up to 20m0s (until 8:03AM CEST) for the Kubernetes API at https://api.okd.ilba.cat:6443...
INFO API v1.28.2-3598+6e2789bbd58938-dirty up
INFO Waiting up to 1h0m0s (until 8:43AM CEST) for bootstrapping to complete...

# La linea anterior que indica: "for bootstrapping to complete...", significa:
#   El nodo bootstrap ha levantado correctamente la API temporal y está listo para recibir a los másters

[root@bastion ~]# curl -k https://10.26.0.10:22623/config/master

# Arrancamos los 3 servidores de master y lanzamos el siguiente comando en cada uno:

sudo coreos-installer install /dev/sda \
  --ignition-url=http://10.26.0.5:8080/master.ign \
  --insecure-ignition

sudo reboot

# Una vez arrancados los equipos, empezaran a aparecer (ha tardado unos 30 minutos)
# Los equipos Masters. se reiniciaran solos

[root@bastion ~]# export KUBECONFIG=/root/cluster-okd/auth/kubeconfig

[root@bastion ~]# oc get nodes
NAME               STATUS     ROLES                  AGE     VERSION
master1.ilba.cat   NotReady   control-plane,master   2m35s   v1.34.4
master2.ilba.cat   NotReady   control-plane,master   2m35s   v1.34.4
master3.ilba.cat   NotReady   control-plane,master   2m17s   v1.34.4

[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

# Quitamos la marca de "uninitialized" de los masters para que pueda desplegar los pods de sistema (red, DNS, etc...)

[root@bastion ~]# oc adm taint nodes master1.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-
[root@bastion ~]# oc adm taint nodes master2.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-
[root@bastion ~]# oc adm taint nodes master3.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-

# El siguiente contenedor tarda unos 5m desde aprovar los certificados en aparecer

[root@bastion ~]# oc get pods -n openshift-network-operator
NAME                                READY   STATUS    RESTARTS   AGE
iptables-alerter-5dnmc              1/1     Running   0          30s
iptables-alerter-f2fd4              1/1     Running   0          30s
iptables-alerter-q4znf              1/1     Running   0          30s
network-operator-76d496774c-ms7j8   1/1     Running   0          89s

# El siguiente contenedor tarda unos 10m desde aprovar los certificados en aparecer

[root@bastion ~]# oc get pods -n openshift-ovn-kubernetes
NAME                                     READY   STATUS    RESTARTS   AGE
ovnkube-control-plane-68798d4445-bck2t   2/2     Running   0          27m
ovnkube-control-plane-68798d4445-lbhft   2/2     Running   0          27m
ovnkube-node-c6nr8                       8/8     Running   0          94s
ovnkube-node-drjjh                       8/8     Running   0          96s
ovnkube-node-tdtb7                       8/8     Running   0          84s

# Una vez creado estos contenedores, empezaremos a ver "Ready" el cluster pasados 30 minutos

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE     VERSION
master1.ilba.cat   Ready    control-plane,master   3m20s   v1.34.4
master2.ilba.cat   Ready    control-plane,master   3m20s   v1.34.4
master3.ilba.cat   Ready    control-plane,master   3m2s    v1.34.4

# Seguimos esperando hasta que el siguiente comando esté todo en "True" (unas 3h)

[root@bastion ~]# oc get co | grep -E "NAME|etcd|kube-apiserver|kube-controller|kube-scheduler|machine-config|network|dns"
NAME                                       VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
dns                                        4.21.0-okd-scos.9   True        False         False      31m
etcd                                       4.21.0-okd-scos.9   True        False         False      23m
kube-apiserver                             4.21.0-okd-scos.9   True        False         False      19m
kube-controller-manager                    4.21.0-okd-scos.9   True        False         False      20m
kube-scheduler                             4.21.0-okd-scos.9   True        False         False      23m
machine-config                             4.21.0-okd-scos.9   True        False         False      31m
network                                    4.21.0-okd-scos.9   True        False         False      34m

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                         AGE   VERSION
master1.ilba.cat   Ready    control-plane,master,worker   24m   v1.34.4
master2.ilba.cat   Ready    control-plane,master,worker   24m   v1.34.4
master3.ilba.cat   Ready    control-plane,master,worker   23m   v1.34.4

[root@bastion ~]# openshift-install wait-for bootstrap-complete --dir=/root/cluster-okd/ --log-level=info
INFO Waiting up to 20m0s (until 11:47AM CEST) for the Kubernetes API at https://api.okd.ilba.cat:6443...
INFO API v1.28.2-3598+6e2789bbd58938-dirty up
INFO Waiting up to 1h0m0s (until 12:27PM CEST) for bootstrapping to complete...
INFO It is now safe to remove the bootstrap resources
INFO Time elapsed: 0s

# Paramos el bootstrap y añadimos los workers

[root@bastion ~]# ssh core@bootstrap
[core@bootstrap ~]$ sudo poweroff

sudo coreos-installer install /dev/sda \
  --ignition-url=http://10.26.0.5:8080/worker.ign \
  --insecure-ignition

sudo reboot

[root@bastion ~]# ssh core@worker1
core@worker1:~$ journalctl -u rpm-ostreed -f      <- Aquí es donde venmos que se va descargando las cosas

# Una vez acabado rebotará los workers

[root@bastion ~]# export KUBECONFIG=/root/cluster-okd/auth/kubeconfig
[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# oc get nodes
NAME               STATUS     ROLES                         AGE   VERSION
master1.ilba.cat   Ready      control-plane,master,worker   38m   v1.34.4
master2.ilba.cat   Ready      control-plane,master,worker   38m   v1.34.4
master3.ilba.cat   Ready      control-plane,master,worker   38m   v1.34.4
worker1.ilba.cat   NotReady   worker                        14s   v1.34.4
worker2.ilba.cat   NotReady   worker                        8s    v1.34.4

[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                         AGE    VERSION
master1.ilba.cat   Ready    control-plane,master,worker   40m    v1.34.4
master2.ilba.cat   Ready    control-plane,master,worker   40m    v1.34.4
master3.ilba.cat   Ready    control-plane,master,worker   40m    v1.34.4
worker1.ilba.cat   Ready    worker                        114s   v1.34.4
worker2.ilba.cat   Ready    worker                        111s   v1.34.4

[root@bastion ~]# oc patch scheduler cluster --type='json' -p='[{"op": "replace", "path": "/spec/mastersSchedulable", "value": false}]'

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   66m   v1.34.4
master2.ilba.cat   Ready    control-plane,master   66m   v1.34.4
master3.ilba.cat   Ready    control-plane,master   65m   v1.34.4
worker1.ilba.cat   Ready    worker                 27m   v1.34.4
worker2.ilba.cat   Ready    worker                 27m   v1.34.4


██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝  
╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗
 ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝


¡¡¡¡¡¡¡ Actualización de versión mayor !!!!!!!

# En una instalación UPI (manual), los objetos Machine dinámicos fallan porque no hay un proveedor Cloud aprovisionándolos de forma automática. 
# Al reducir el MachineSet a 0 y borrar las máquinas fallidas huérfanas, le has indicado a la API que no espere nodos dinámicos, desbloqueando los operadores y dejando el clúster completamente limpio y saludable.

[root@bastion ~]# oc get co | grep -v "True.*False.*False"
NAME                                       VERSION                          AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
cluster-autoscaler                                                          True        False         True       8d      machine-api not ready
machine-api                                                                 False       True          True       8d      Operator is initializing

[root@bastion ~]# oc get clusterversion
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version             False       True          8d      Unable to apply 4.15.0-0.okd-2024-03-10-010116: the cluster operator machine-api is not available

[root@bastion ~]# oc get machines -n openshift-machine-api
NAME                       PHASE    TYPE   REGION   ZONE   AGE
okd-wkh52-master-0         Failed                          8d
okd-wkh52-master-1         Failed                          8d
okd-wkh52-master-2         Failed                          8d
okd-wkh52-worker-0-fslth   Failed                          8d
okd-wkh52-worker-0-nddbb   Failed                          8d

[root@bastion ~]# oc get machinesets -n openshift-machine-api
NAME                 DESIRED   CURRENT   READY   AVAILABLE   AGE
okd-wkh52-worker-0   2         2                             8d

[root@bastion ~]# oc scale machineset okd-wkh52-worker-0 -n openshift-machine-api --replicas=0
[root@bastion ~]# oc delete machines --all -n openshift-machine-api
[root@bastion ~]# oc rollout restart deployment/machine-api-operator -n openshift-machine-api

------------------------------------------------------------------------------------------------------------------------------------------------------------------

[root@bastion ~]# oc get clusterversion
NAME      VERSION                          AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.15.0-0.okd-2024-03-10-010116   True        False         3m18s   Cluster version is 4.15.0-0.okd-2024-03-10-010116

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE     VERSION
master1.ilba.cat   Ready    control-plane,master   8d      v1.28.7+6e2789b
master2.ilba.cat   Ready    control-plane,master   8d      v1.28.7+6e2789b
master3.ilba.cat   Ready    control-plane,master   8d      v1.28.7+6e2789b
worker1.ilba.cat   Ready    worker                 7d22h   v1.28.7+6e2789b
worker2.ilba.cat   Ready    worker                 7d22h   v1.28.7+6e2789b

NO HA FUNCIONADO 

[root@bastion ~]# oc get clusteroperators
# Todos los operadores deben estar en AVAILABLE = True, PROGRESSING = False y DEGRADED = False



██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗  ██████╗██╗ ██████╗ ███╗   ██╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██╔══██╗██╔════╝██║██╔═══██╗████╗  ██║
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ███████║██║     ██║██║   ██║██╔██╗ ██║
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██╔══██║██║     ██║██║   ██║██║╚██╗██║
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗██║  ██║╚██████╗██║╚██████╔╝██║ ╚████║
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝

Como sería un a instalación via IPI (Installer-Provisioned Infrastructure).
Todo se resume a un install-config.yaml enriquecido:

apiVersion: v1
baseDomain: ilba.cat
metadata:
  name: okd
platform:
  vsphere:
    vCenter: vcenter.ilba.cat
    username: administrator@vsphere.local
    password: "TuPasswordSecret0"
    datacenter: Datacenter-Principal
    defaultDatastore: vsanDatastore
    cluster: Cluster-vSphere
    network: VM Network
    apiVIPs:
      - 10.26.0.5     # IP flotante para la API (no necesitas HAProxy)
    ingressVIPs:
      - 10.26.0.6     # IP flotante para Ingress/Router
pullSecret: '{"auths": ...}'
sshKey: 'ssh-rsa AAAAB3NzaC1yc2E...'
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
  platform:
    vsphere:
      cpus: 4
      coresPerSocket: 2
      memoryMB: 16384
      osDisk:
        diskSizeGB: 120
compute:
  - hyperthreading: Enabled
    name: worker
    replicas: 2
    platform:
      vsphere:
        cpus: 4
        coresPerSocket: 2
        memoryMB: 16384
        osDisk:
          diskSizeGB: 120

openshift-install create cluster --dir=cluster-okd --log-level=info




------------------------------------------------------------------------------------------------------------------------------------------------------------------

 ██████╗ ██╗   ██╗██╗
██╔════╝ ██║   ██║██║
██║  ███╗██║   ██║██║
██║   ██║██║   ██║██║
╚██████╔╝╚██████╔╝██║
 ╚═════╝  ╚═════╝ ╚═╝


[root@bastion ~]# cat /root/cluster-okd/auth/kubeadmin-password
9P9gF-768cI-EL5nd-wNKPb

[root@bastion ~]# oc get route console -n openshift-console
NAME      HOST/PORT                                     PATH   SERVICES   PORT    TERMINATION          WILDCARD
console   console-openshift-console.apps.okd.ilba.cat          console    https   reencrypt/Redirect   None

[root@bastion ~]# oc get pods -n openshift-ingress
NAME                              READY   STATUS    RESTARTS   AGE
router-default-66b49cc574-vssd6   1/1     Running   0          22h
router-default-77f49fdb85-psm45   1/1     Running   0          17h

[root@bastion ~]# oc get pods -n openshift-console
NAME                         READY   STATUS    RESTARTS        AGE
console-6b7885f757-rw9xz     1/1     Running   6 (3m39s ago)   6m54s
console-6b7885f757-xxk9m     1/1     Running   5 (5m11s ago)   6m54s
downloads-6d5dc6fc54-xscpr   1/1     Running   1               21h
downloads-6d5dc6fc54-z744q   1/1     Running   1               21h

[root@bastion ~]# oc get pods -n openshift-authentication
NAME                              READY   STATUS    RESTARTS   AGE
oauth-openshift-6b8d9fd9b-qgqrf   1/1     Running   0          3m18s
oauth-openshift-6b8d9fd9b-th652   1/1     Running   0          2m48s
oauth-openshift-6b8d9fd9b-zckw8   1/1     Running   0          2m18s

[root@bastion ~]# oc get pods -n openshift-authentication-operator
NAME                                       READY   STATUS    RESTARTS   AGE
authentication-operator-766d9779d4-dcttf   1/1     Running   0          17m

[root@bastion ~]# oc get co authentication
NAME             VERSION                          AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
authentication   4.15.0-0.okd-2024-03-10-010116   True        False         False      22s

# si falla algo:

[root@bastion ~]# oc delete pods --all -n openshift-authentication
[root@bastion ~]# oc delete pod -n openshift-authentication-operator --all

[root@bastion ~]# oc delete pods -n openshift-authentication --grace-period=0 --force
[root@bastion ~]# oc delete pods -n openshift-authentication-operator --grace-period=0 --force


------------------------------------------------------------------------------------------------------------------------------------------------------------------

# En la consola se ve: "Operators: 1 degraded"
# Ver columna DEGRADED

[root@bastion ~]# oc get co
NAME                                       VERSION                          AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
...
cluster-autoscaler                                                          True        False         True       46h     machine-api not ready
...

[root@bastion ~]# oc get co cluster-autoscaler machine-api
NAME                 VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
cluster-autoscaler             True        False         True       47h     machine-api not ready
machine-api                    False       True          True       46h     Operator is initializing

[root@bastion ~]# oc rollout restart deployment/machine-api-operator -n openshift-machine-api
[root@bastion ~]# oc rollout restart deployment/cluster-autoscaler-operator -n openshift-machine-api

[root@bastion ~]# oc get machines -n openshift-machine-api
NAME                       PHASE    TYPE   REGION   ZONE   AGE
okd-wkh52-master-0         Failed                          2d
okd-wkh52-master-1         Failed                          2d
okd-wkh52-master-2         Failed                          2d
okd-wkh52-worker-0-fslth   Failed                          43h
okd-wkh52-worker-0-nddbb   Failed                          43h

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   47h   v1.28.7+6e2789b
master2.ilba.cat   Ready    control-plane,master   47h   v1.28.7+6e2789b
master3.ilba.cat   Ready    control-plane,master   47h   v1.28.7+6e2789b
worker1.ilba.cat   Ready    worker                 42h   v1.28.7+6e2789b
worker2.ilba.cat   Ready    worker                 42h   v1.28.7+6e2789b


------------------------------------------------------------------------------------------------------------------------------------------------------------------

███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗ 
████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝ 
██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ ██║██╔██╗ ██║██║  ███╗
██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗ ██║██║╚██╗██║██║   ██║
██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝
╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

# Problemnas de networking

[root@bastion ~]# oc get pods -n openshift-multus -o wide
[root@bastion ~]# oc get pods -n openshift-ovn-kubernetes -o wide

[root@bastion ~]# oc rollout restart daemonset/ovnkube-node -n openshift-ovn-kubernetes
[root@bastion ~]# oc rollout restart daemonset/multus -n openshift-multus

[root@bastion ~]# oc get pods -n openshift-ingress

# OVN-Kubernetes, NetworkPolicies

[root@bastion ~]# oc new-project ns-frontend
[root@bastion ~]# oc new-project ns-backend

[root@bastion ~]# oc run server-pod --image=nginx --port=80 -n ns-backend
[root@bastion ~]# oc run client-pod --image=busybox -n ns-frontend -- sleep 3600

[root@bastion ~]# oc get pods -n ns-backend
NAME         READY   STATUS    RESTARTS   AGE
server-pod   1/1     Running   0          45s

[root@bastion ~]# oc get pods -n ns-frontend
NAME         READY   STATUS    RESTARTS   AGE
client-pod   1/1     Running   0          26s

[root@bastion ~]# SERVER_IP=$(oc get pod server-pod -n ns-backend -o jsonpath='{.status.podIP}')
[root@bastion ~]# oc exec -it client-pod -n ns-frontend -- wget -qO- --timeout=3 http://$SERVER_IP    <-- OK


cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-with-logging
  namespace: ns-backend
  annotations:
    k8s.ovn.org/acl-logging: |
      {
        "deny": "alert"
      }
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF


[root@bastion ~]# oc exec -it client-pod -n ns-frontend -- wget -qO- --timeout=3 http://$SERVER_IP    <-- TimeOut

[root@bastion ~]# oc adm node-logs $(oc get pod server-pod -n ns-backend -o jsonpath='{.spec.nodeName}') | grep -i "deny"
Aug 01 05:48:00.183928 worker2.ilba.cat kubenswrapper[2827]: E0801 05:48:00.183740    2827 kuberuntime_manager.go:1261] container &Container{Name:kube-state-metrics,Image:quay.io/openshift/okd-content@sha256:4266214a339b2724dd7652fec2192ef7f24a3fec02403c423e6e597bf3a895a3,Command:[],Args:[--host=127.0.0.1 --port=8081 --telemetry-host=127.0.0.1 --telemetry-port=8082 --metric-denylist=
Aug 01 05:48:00.183928 worker2.ilba.cat kubenswrapper[2827]:  --metric-labels-allowlist=pods=[*],nodes=[*],namespaces=[*],persistentvolumes=[*],persistentvolumeclaims=[*],poddisruptionbudgets=[*]

------------------------------------------------------------------------------------------------------------------------------------------------------------------


 ██████╗ ██╗   ██╗ ██████╗ ████████╗ █████╗ ███████╗
██╔═══██╗██║   ██║██╔═══██╗╚══██╔══╝██╔══██╗██╔════╝
██║   ██║██║   ██║██║   ██║   ██║   ███████║███████╗
██║▄▄ ██║██║   ██║██║   ██║   ██║   ██╔══██║╚════██║
╚██████╔╝╚██████╔╝╚██████╔╝   ██║   ██║  ██║███████║
 ╚══▀▀═╝  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚══════╝


[root@bastion ~]# oc new-project sin-quotas

[root@bastion ~]# oc get quota -n sin-quotas
No resources found in sin-quotas namespace

[root@bastion ~]# oc get resourcequotas -n sin-quotas
No resources found in sin-quotas namespace.

[root@bastion ~]# oc adm create-bootstrap-project-template -o yaml > project-template.yaml

[root@bastion ~]# vim project-template.yaml
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: default-quota
    namespace: ${PROJECT_NAME}
  spec:
    hard:
      requests.cpu: "2"
      requests.memory: 4Gi
      limits.cpu: "4"
      limits.memory: 8Gi
      pods: "10"
      services: "5"
      persistentvolumeclaims: "5"

[root@bastion ~]# oc create -f project-template.yaml -n openshift-config

oc patch project.config.openshift.io/cluster --type=merge -p '
spec:
  projectRequestTemplate:
    name: project-request
'

[root@bastion ~]# oc get template -n openshift-config
NAME              DESCRIPTION   PARAMETERS    OBJECTS
project-request                 5 (5 blank)   3

# Creandolo por consola

Cuando un administrador de clúster crea un namespace directamente con oc new-project o oc create ns, el API Server se salta intencionadamente la plantilla personalizada (projectRequestTemplate) y crea un namespace "limpio".
Por eso no podemos usar el comando: "oc new-project con-quotas"

[root@bastion ~]# oc new-project con-quotas

[root@bastion ~]# oc get resourcequotas -n con-quotas
No resources found in con-quotas namespace.

[root@bastion ~]# oc get quotas -n con-quotas
error: the server doesn't have a resource type "quotas"

# Creandolo por la GUI

[root@bastion ~]# oc get resourcequotas -n con-quotas-from-gui
NAME            AGE   REQUEST                                                                                             LIMIT
default-quota   15s   persistentvolumeclaims: 0/5, pods: 0/10, requests.cpu: 0/2, requests.memory: 0/4Gi, services: 0/5   limits.cpu: 0/4, limits.memory: 0/8Gi

# Desde consola

cat <<EOF | oc create -f -
apiVersion: project.openshift.io/v1
kind: ProjectRequest
metadata:
  name: con-quotas-v2
EOF

[root@bastion ~]# oc get resourcequotas -n con-quotas-v2
NAME            AGE   REQUEST                                                                                             LIMIT
default-quota   10s   persistentvolumeclaims: 0/5, pods: 0/10, requests.cpu: 0/2, requests.memory: 0/4Gi, services: 0/5   limits.cpu: 0/4, limits.memory: 0/8Gi




------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Punteros en nuestro fichero de hosts:

172.26.0.12	console-openshift-console.apps.okd.ilba.cat
172.26.0.12	oauth-openshift.apps.okd.ilba.cat

# Hacer un NAT y acceder

URL:          https://console-openshift-console.apps.okd.ilba.cat/
Usuario:      kubeadmin
Contraseña:   9P9gF-768cI-EL5nd-wNKPb

# Carga de un cluster vacio

[root@bastion ~]# kubectl top nodes
NAME               CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master1.ilba.cat   771m         22%    4406Mi          29%
master2.ilba.cat   728m         20%    5372Mi          36%
master3.ilba.cat   657m         18%    4046Mi          27%
worker1.ilba.cat   283m         8%     3425Mi          23%
worker2.ilba.cat   327m         9%     3588Mi          24%

------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Revisión del control plane

[root@bastion ~]# oc get pods -n openshift-kube-apiserver -o wide
[root@bastion ~]# oc get pods -n openshift-kube-scheduler -o wide
[root@bastion ~]# oc get co kube-apiserver kube-scheduler

------------------------------------------------------------------------------------------------------------------------------------------------------------------

██╗   ██╗███████╗██████╗ ██╗  ██╗███████╗██████╗ ███████╗     ██████╗███████╗██╗
██║   ██║██╔════╝██╔══██╗██║  ██║██╔════╝██╔══██╗██╔════╝    ██╔════╝██╔════╝██║
██║   ██║███████╗██████╔╝███████║█████╗  ██████╔╝█████╗      ██║     ███████╗██║
╚██╗ ██╔╝╚════██║██╔═══╝ ██╔══██║██╔══╝  ██╔══██╗██╔══╝      ██║     ╚════██║██║
 ╚████╔╝ ███████║██║     ██║  ██║███████╗██║  ██║███████╗    ╚██████╗███████║██║
  ╚═══╝  ╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝     ╚═════╝╚══════╝╚═╝


Para que el driver CSI de vSphere funcione, las Máquinas Virtuales de los nodos (Control Plane y Workers) deben tener habilitada la propiedad disk.EnableUUID. 
Sin esto, Linux no expone los UUIDs /dev/disk/by-id/ que necesita Kubernetes para identificar el volumen.

Como solucionarlo:
  Apaga los equipos
  En vCenter, haz clic derecho sobre la VM del Worker -> Edit Settings
  Ve a VM Options -> Advanced -> Configuration Parameters -> Edit Configuration.
  Revisa si existe la clave disk.EnableUUID:
    Si no existe, añádela con el valor TRUE.
    Si está en FALSE, cámbiala a TRUE.
  Enciende la VM de nuevo.


[root@bastion ~]# oc get clusteroperator storage
NAME      VERSION                          AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
storage   4.15.0-0.okd-2024-03-10-010116   True        False         False      177m

[root@bastion ~]# oc get sc
NAME                 PROVISIONER              RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
thin-csi (default)   csi.vsphere.vmware.com   Delete          WaitForFirstConsumer   true                   26h

[root@bastion ~]# oc new-project test-storage \
--display-name="Proyecto prueba almacenamiento" \
--description="Este proyecto es para pruebas almacenamiento."


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

------------------------------------------------------------------------------------------------------------------------------------------------------------------

██╗  ██╗██╗   ██╗██████╗ ███████╗███████╗██████╗  █████╗ ██████╗ ██╗   ██╗    ██╗   ██╗███████╗     ██████╗ ██╗  ██╗██████╗ 
██║ ██╔╝██║   ██║██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝    ██║   ██║██╔════╝    ██╔═══██╗██║ ██╔╝██╔══██╗
█████╔╝ ██║   ██║██████╔╝█████╗  ███████╗██████╔╝███████║██████╔╝ ╚████╔╝     ██║   ██║███████╗    ██║   ██║█████╔╝ ██║  ██║
██╔═██╗ ██║   ██║██╔══██╗██╔══╝  ╚════██║██╔═══╝ ██╔══██║██╔══██╗  ╚██╔╝      ╚██╗ ██╔╝╚════██║    ██║   ██║██╔═██╗ ██║  ██║
██║  ██╗╚██████╔╝██████╔╝███████╗███████║██║     ██║  ██║██║  ██║   ██║        ╚████╔╝ ███████║    ╚██████╔╝██║  ██╗██████╔╝
╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝         ╚═══╝  ╚══════╝     ╚═════╝ ╚═╝  ╚═╝╚═════╝ 


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

[root@bastion ~]# oc get nodes
NAME               STATUS                     ROLES                  AGE   VERSION
master1.ilba.cat   Ready                      control-plane,master   28h   v1.28.7+6e2789b
master2.ilba.cat   Ready                      control-plane,master   28h   v1.28.7+6e2789b
master3.ilba.cat   Ready,SchedulingDisabled   control-plane,master   28h   v1.28.7+6e2789b
worker1.ilba.cat   Ready                      worker                 23h   v1.28.7+6e2789b
worker2.ilba.cat   Ready,SchedulingDisabled   worker                 23h   v1.28.7+6e2789b

[root@bastion ~]# oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-f394f6962b5c73d456b82f7f879702c4   False     True       False      3              0                   0                     0                      28h
worker   rendered-worker-3c14a25be6380feebd1c35292aeeb2b1   False     True       False      2              0                   0                     0                      28h

# Security Context Constraints (SCC)

OKD prohíbe que un pod corra como root y le asigna un UID aleatorio dentro de un rango específico del namespace.

[root@bastion ~]# oc adm policy add-scc-to-user anyuid -z default -n test-hello-world
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:anyuid added: "default"

[root@bastion ~]# oc rollout restart deployment -n test-hello-world

OKD viene con un conjunto de SCCs predefinidas con distintos niveles de restricción:
* restricted-v2 (default) -> No permite ejecutar como root, asigna UIDs aleatorios en un rango alto asignado al namespace y prohíbe anotaciones inseguras (seccomp).
* anyuid -> Permite que los contenedores se ejecuten con cualquier UID definido en la imagen (por ejemplo, UID 1000 o root), pero mantiene restricciones sobre el host.
* privileged -> Otorga acceso total. El contenedor puede ejecutar como root, acceder a dispositivos del host, ignorar comprobaciones de seccomp y aplicar cualquier configuración de red o volumen.

------------------------------------------------------------------------------------------------------------------------------------------------------------------


 █████╗ ██████╗  ██████╗  ██████╗  ██████╗██████╗ 
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝██╔══██╗
███████║██████╔╝██║  ███╗██║   ██║██║     ██║  ██║
██╔══██║██╔══██╗██║   ██║██║   ██║██║     ██║  ██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝╚██████╗██████╔╝
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝  ╚═════╝╚═════╝ 


Instalación desde la Consola Web (UI):
* Ve a la consola web de OKD con tu usuario administrador.
* En el menú lateral, ve a Operators -> OperatorHub.
* Busca Red Hat OpenShift GitOps (o GitOps / ArgoCD).
* Haz clic en Install manteniendo las opciones por defecto (se instalará en el namespace openshift-gitops-operator).


[root@bastion ~]# oc get csv -n openshift-operators
NAME                      DISPLAY   VERSION   REPLACES                  PHASE
argocd-operator.v0.18.0   Argo CD   0.18.0    argocd-operator.v0.17.0   Succeeded

[root@bastion ~]# oc get pods -n openshift-operators | grep argocd
argocd-operator-controller-manager-7ccfd6bdd9-t98qz   1/1     Running   0          2m14s


cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: argocd-cluster
  namespace: openshift-operators
spec:
  server:
    insecure: true
    route:
      enabled: true
EOF


[root@bastion ~]# oc get argocd -n openshift-operators
NAME             AGE
argocd-cluster   2s

[root@bastion ~]# oc create route edge argocd-cluster-server --service=argocd-cluster-server --port=8080 -n openshift-operators

[root@bastion ~]# oc get route argocd-cluster-server -n openshift-operators
NAME                    HOST/PORT                                                     PATH   SERVICES                PORT   TERMINATION   WILDCARD
argocd-cluster-server   argocd-cluster-server-openshift-operators.apps.okd.ilba.cat          argocd-cluster-server   8080   edge          None

[root@bastion ~]# oc get secret argocd-cluster-cluster -n openshift-operators -o jsonpath="{.data.admin\.password}" | base64 -d; echo
pfLj90E6IbOPgNFrz1cTGSWuaXKewlH5

Problemas con ArgoCD: oc logs deployment/argocd-operator-controller-manager -n openshift-operators --tail=30

------------------------------------------------------------------------------------------------------------------------------------------------------------------

 ██████╗ ██████╗ ███████╗ █████╗ ███████╗    ██████╗  █████╗ ███╗   ██╗██████╗  ██████╗ ███╗   ███╗
██╔════╝██╔═══██╗██╔════╝██╔══██╗██╔════╝    ██╔══██╗██╔══██╗████╗  ██║██╔══██╗██╔═══██╗████╗ ████║
██║     ██║   ██║███████╗███████║███████╗    ██████╔╝███████║██╔██╗ ██║██║  ██║██║   ██║██╔████╔██║
██║     ██║   ██║╚════██║██╔══██║╚════██║    ██╔══██╗██╔══██║██║╚██╗██║██║  ██║██║   ██║██║╚██╔╝██║
╚██████╗╚██████╔╝███████║██║  ██║███████║    ██║  ██║██║  ██║██║ ╚████║██████╔╝╚██████╔╝██║ ╚═╝ ██║
 ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝





















[root@bastion ~]# sshpass -p 'C@dinor1988' ssh root@172.26.0.6 -C poweroff

echo "y" | sshpass -p 'sorisat' ssh admin@172.26.0.8 "/system shutdown"