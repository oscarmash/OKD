
██╗██████╗ ██╗    ██╗   ██╗███████╗       ██╗   ██╗██████╗ ██╗
██║██╔══██╗██║    ██║   ██║██╔════╝       ██║   ██║██╔══██╗██║
██║██████╔╝██║    ██║   ██║███████╗       ██║   ██║██████╔╝██║
██║██╔═══╝ ██║    ╚██╗ ██╔╝╚════██║       ██║   ██║██╔═══╝ ██║
██║██║     ██║     ╚████╔╝ ███████║██╗    ╚██████╔╝██║     ██║
╚═╝╚═╝     ╚═╝      ╚═══╝  ╚══════╝╚═╝     ╚═════╝ ╚═╝     ╚═╝


IPI (Installer-Provisioned Infrastructure) -> El instalador de OKD se conecta a la API de vCenter, crea la red, descarga/clona la plantilla de CoreO), crea la VM Bootstrap, crea los 3 Masters y los Workers.
UPI (User-Provisioned Infrastructure) -> El administrador (tú) crea y gestiona manualmente toda la infraestructura (redes, balanceador de carga como HAProxy, registros DNS en Bind/Unbound, almacenamiento y las propias máquinas virtuales en vCenter o servidores físicos


██╗███╗   ██╗███████╗████████╗ █████╗ ██╗      █████╗  ██████╗██╗ ██████╗ ███╗   ██╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██╔══██╗██╔════╝██║██╔═══██╗████╗  ██║
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ███████║██║     ██║██║   ██║██╔██╗ ██║
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██╔══██║██║     ██║██║   ██║██║╚██╗██║
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗██║  ██║╚██████╗██║╚██████╔╝██║ ╚████║
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝


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

wget https://github.com/okd-project/okd/releases/download/4.15.0-0.okd-2024-03-10-010116/openshift-client-linux-4.15.0-0.okd-2024-03-10-010116.tar.gz
wget https://github.com/okd-project/okd/releases/download/4.15.0-0.okd-2024-03-10-010116/openshift-install-linux-4.15.0-0.okd-2024-03-10-010116.tar.gz

tar -xvf openshift-client-linux-*.tar.gz
tar -xvf openshift-install-linux-*.tar.gz

mv oc kubectl openshift-install /usr/local/bin/

ssh-keygen -t rsa -b 4096 -C "root@bastion.ilba.cat"

mkdir ~/cluster-okd
cd ~/cluster-okd

vi install-config.yaml

cp install-config.yaml install-config.yaml.bak

# Ens la mayoría de instalaciones estándar no se ejecuta el comando de manifests. Por tanto, el primer comando no se lanza

openshift-install create manifests --dir=.              <- NO SE LANZA
openshift-install create ignition-configs --dir=.       <- SI SE LANZA

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

Reinstalamos los nodos: bootstrap, masters, workers (vamos todo)

Error de certificados:

core@bootstrap:~$ sudo journalctl -b -u bootkube.service -f
Jul 26 07:19:43 bootstrap.ilba.cat cluster-bootstrap[6112]: [#823] failed to fetch discovery: Get "https://localhost:6443/api?timeout=32s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-07-26T07:19:43Z is after 2026-07-22T14:31:06Z
Jul 26 07:19:43 bootstrap.ilba.cat bootkube.sh[5978]: [#823] failed to fetch discovery: Get "https://localhost:6443/api?timeout=32s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-07-26T07:19:43Z is after 2026-07-22T14:31:06Z

[root@bastion ~]# cp cluster-okd/install-config.yaml.bak .

[root@bastion ~]# rm /root/.ssh/known_hosts
[root@bastion ~]# rm -rf cluster-okd/
[root@bastion ~]# mkdir cluster-okd
[root@bastion ~]# cp install-config.yaml.bak cluster-okd/install-config.yaml
[root@bastion ~]# openshift-install create ignition-configs --dir=cluster-okd/
[root@bastion ~]# rm /var/www/html/*.ign
[root@bastion ~]# cp cluster-okd/*.ign /var/www/html/
[root@bastion ~]# chmod 644 /var/www/html/*.ign


------------------------------------------------------------------------------------------------------------------------------------------------------------------


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

[root@bastion ~]# curl -k https://10.26.0.10:22623/config/master

# Arrancamos los 3 servidores de master y lanzamos el siguiente comando en cada uno:

sudo coreos-installer install /dev/sda \
  --ignition-url=http://10.26.0.5:8080/master.ign \
  --insecure-ignition

sudo reboot

# Una vez arrancados los equipos, empezaran a aparecer (ha tardado unos 30 minutos)

[root@bastion ~]# export KUBECONFIG=/root/cluster-okd/auth/kubeconfig

[root@bastion ~]# oc get nodes
NAME               STATUS     ROLES                  AGE   VERSION
master1.ilba.cat   NotReady   control-plane,master   37s   v1.28.7+6e2789b
master2.ilba.cat   NotReady   control-plane,master   39s   v1.28.7+6e2789b
master3.ilba.cat   NotReady   control-plane,master   40s   v1.28.7+6e2789b


[root@bastion ~]# export KUBECONFIG=/root/cluster-okd/auth/kubeconfig
[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

# Quitamos la marca de "uninitialized" de los masters para que pueda desplegar los pods de sistema (red, DNS, etc...)

[root@bastion ~]# oc adm taint nodes master1.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-
[root@bastion ~]# oc adm taint nodes master2.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-
[root@bastion ~]# oc adm taint nodes master3.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-

# El siguiente contenedor tarda unos 5m desde aprovar los certificados en aparecer

[root@bastion ~]# oc get pods -n openshift-network-operator
NAME                                READY   STATUS    RESTARTS   AGE
network-operator-656d4d696f-rhwcp   1/1     Running   0          53m

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
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   37m   v1.28.7+6e2789b
master2.ilba.cat   Ready    control-plane,master   37m   v1.28.7+6e2789b
master3.ilba.cat   Ready    control-plane,master   37m   v1.28.7+6e2789b

# Seguimos esperando hasta que el siguiente comando esté todo en "True" (unas 3h)

[root@bastion ~]# export KUBECONFIG=/root/cluster-okd/auth/kubeconfig
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE     VERSION
master1.ilba.cat   Ready    control-plane,master   3h23m   v1.28.7+6e2789b
master2.ilba.cat   Ready    control-plane,master   3h23m   v1.28.7+6e2789b
master3.ilba.cat   Ready    control-plane,master   3h23m   v1.28.7+6e2789b

[root@bastion ~]# oc get co | grep -E "NAME|etcd|kube-apiserver|kube-controller|kube-scheduler|machine-config|network|dns"
NAME                                       VERSION                          AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
dns                                        4.15.0-0.okd-2024-03-10-010116   True        False         False      151m
etcd                                       4.15.0-0.okd-2024-03-10-010116   True        True          True       151m    xxx...
kube-apiserver                             4.15.0-0.okd-2024-03-10-010116   True        True          True       89m     xxx...
kube-controller-manager                    4.15.0-0.okd-2024-03-10-010116   True        True          True       83m     xxx...
kube-scheduler                             4.15.0-0.okd-2024-03-10-010116   True        True          True       143m    xxx...
machine-config                             4.15.0-0.okd-2024-03-10-010116   True        False         False      158m
network                                    4.15.0-0.okd-2024-03-10-010116   True        True          False      166m    xxx...

[root@bastion ~]# openshift-install wait-for bootstrap-complete --dir=/root/cluster-okd/ --log-level=info
INFO Waiting up to 20m0s (until 11:47AM CEST) for the Kubernetes API at https://api.okd.ilba.cat:6443...
INFO API v1.28.2-3598+6e2789bbd58938-dirty up
INFO Waiting up to 1h0m0s (until 12:27PM CEST) for bootstrapping to complete...
INFO It is now safe to remove the bootstrap resources
INFO Time elapsed: 0s

# Paramos el bootstrap y añadimos los workers

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
NAME               STATUS     ROLES                  AGE     VERSION
master1.ilba.cat   Ready      control-plane,master   5h57m   v1.28.7+6e2789b
master2.ilba.cat   Ready      control-plane,master   5h57m   v1.28.7+6e2789b
master3.ilba.cat   Ready      control-plane,master   5h57m   v1.28.7+6e2789b
worker1.ilba.cat   NotReady   worker                 6m1s    v1.28.7+6e2789b
worker2.ilba.cat   NotReady   worker                 6m2s    v1.28.7+6e2789b

[root@bastion ~]# oc get csr
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve

[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE     VERSION
master1.ilba.cat   Ready    control-plane,master   6h      v1.28.7+6e2789b
master2.ilba.cat   Ready    control-plane,master   6h      v1.28.7+6e2789b
master3.ilba.cat   Ready    control-plane,master   6h      v1.28.7+6e2789b
worker1.ilba.cat   Ready    worker                 8m59s   v1.28.7+6e2789b
worker2.ilba.cat   Ready    worker                 9m      v1.28.7+6e2789b

[root@bastion ~]# oc adm taint nodes worker1.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-
[root@bastion ~]# oc adm taint nodes worker2.ilba.cat node.cloudprovider.kubernetes.io/uninitialized-

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




[root@bastion ~]# sshpass -p 'C@dinor1988' ssh root@172.26.0.6 -C poweroff