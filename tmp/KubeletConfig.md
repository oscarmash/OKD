OpenShift gestiona los parámetros del agente kubelet de bajo nivel mediante el Machine Config Operator (MCO):

* autoSizingReserved: true: En lugar de calcular a mano cuánta memoria y CPU reservar para el sistema operativo (systemReserved), el kubelet calcula de forma dinámica y automática el margen reservado según el hardware físico de la máquina. Esto evita que los contenedores colapsen procesos vitales del host como systemd, crio, NetworkManager o el propio kubelet.
* evictionSoft y evictionSoftGracePeriod: Umbrales de aviso. Si la RAM libre cae por debajo de 500Mi o el disco baja del 10% durante 1m30s, el kubelet comienza a expulsar pods de forma ordenada y limpia.
* evictionHard: Umbral crítico estricto. Si la memoria baja de 200Mi o el disco de imágenes cae del 10%, el nodo desaloja pods de inmediato sin periodo de gracia para salvar al kernel de un bloqueo por OOM (Out Of Memory).
* imageGCHighThresholdPercent: 80 / LowThresholdPercent: 75: Recolector de basura (Garbage Collection). Cuando el disco asignado a imágenes (imagefs) supera el 80% de ocupación, elimina automáticamente capas e imágenes huérfanas en desuso hasta reducir el volumen por debajo del 75%.
* imageMinimumGCAge: 10m: Protege las imágenes descargadas recientemente para que no se purguen si llevan menos de 10 minutos en el nodo.

Estas características, no se aplican al Control Plane ya que forzar límites en nodos de control puede provocar que el OOM-Killer mate procesos esenciales como etcd o kube-apiserver.


# infra-kubeletconfig.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: infra-kubeletconfig
spec:
  machineConfigPoolSelector:
    matchLabels:
      pools.operator.machineconfiguration.openshift.io/infra: ''
  kubeletConfig:
    autoSizingReserved: true
    evictionSoft:
      memory.available: "500Mi"
      nodefs.available: "10%"
      nodefs.inodesFree: "5%"
      imagefs.available: "15%"
      imagefs.inodesFree: "10%"
    evictionSoftGracePeriod:
      memory.available: "1m30s"
      nodefs.available: "1m30s"
      nodefs.inodesFree: "1m30s"
      imagefs.available: "1m30s"
      imagefs.inodesFree: "1m30s"
    evictionHard:
      memory.available: "200Mi"
      nodefs.available: "5%"
      nodefs.inodesFree: "4%"
      imagefs.available: "10%"
      imagefs.inodesFree: "5%"
    evictionPressureTransitionPeriod: 0s
    imageMinimumGCAge: 10m
    imageGCHighThresholdPercent: 80
    imageGCLowThresholdPercent: 75


# worker-kubeletconfig.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: KubeletConfig
metadata:
  name: worker-kubeletconfig
spec:
  machineConfigPoolSelector:
    matchLabels:
      # Selector corregido hacia el pool worker
      pools.operator.machineconfiguration.openshift.io/worker: ''
  kubeletConfig:
    autoSizingReserved: true
    evictionSoft:
      memory.available: "500Mi"
      nodefs.available: "10%"
      nodefs.inodesFree: "5%"
      imagefs.available: "15%"
      imagefs.inodesFree: "10%"
    evictionSoftGracePeriod:
      memory.available: "1m30s"
      nodefs.available: "1m30s"
      nodefs.inodesFree: "1m30s"
      imagefs.available: "1m30s"
      imagefs.inodesFree: "1m30s"
    evictionHard:
      memory.available: "200Mi"
      nodefs.available: "5%"
      nodefs.inodesFree: "4%"
      imagefs.available: "10%"
      imagefs.inodesFree: "5%"
    evictionPressureTransitionPeriod: 0s
    imageMinimumGCAge: 10m
    imageGCHighThresholdPercent: 80
    imageGCLowThresholdPercent: 75

oc get mcp infra worker
oc apply -f infra-kubeletconfig.yaml

oc get mcp worker
oc apply -f worker-kubeletconfig.yaml

Validación:

oc debug node/worker3.ilba.cat -- chroot /host cat /etc/kubernetes/kubelet.conf | grep -E 'imageGCHighThresholdPercent|evictionHard'