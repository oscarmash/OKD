
El control-plane-machine-set es el operador de OpenShift encargado de gestionar el ciclo de vida, las actualizaciones y la alta disponibilidad de los nodos de control (los masters) y OKD oblidga a tener una relación entre los nodos masters y los nodos de VMWare, para tener la información de cada uno de ellos se usa el **control-plane-machine-set**

[root@bastion ~]# oc get clusteroperators
...
control-plane-machine-set                  4.21.0-okd-scos.9   False       False         True       45h     Missing 3 available replica(s)
...

[root@bastion ~]# oc describe clusteroperator control-plane-machine-set

[root@bastion ~]# oc get machines -n openshift-machine-api
No resources found in openshift-machine-api namespace.

Al no existis los objetos, vamos a generarlos a partir del propio ControlPlaneMachineSet.
