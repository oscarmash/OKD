Por defecto, OpenShift incluye el operador node-tuning (tuned), que optimiza perfiles de kernel sin necesidad de reiniciar nodos.

En VMs sobre ESXi/vSphere, el planificador de I/O del kernel de Linux debe delegar el balanceo al hipervisor usando none (o mq-deadline) para evitar doble encolamiento y latencias en etcd y bases de datos:

# tuned-disk-and-network.yaml
apiVersion: tuned.openshift.io/v1
kind: Tuned
metadata:
  name: lab-performance-tuning
  namespace: openshift-cluster-node-tuning-operator
spec:
  profile:
    - name: lab-worker-profile
      data: |
        [main]
        summary=Optimizacion de disco e IP forwarding para workers
        include=openshift-node
        
        [disk]
        # Aplica 'none' a discos virtuales SCSI/SATA en VMware
        devices=sd*
        elevator=none
        
        [sysctl]
        # Evita que el kernel congele procesos por sincronización masiva de dirty memory
        vm.dirty_ratio = 10
        vm.dirty_background_ratio = 5
        # Eleva el límite de conexiones concurrentes en ingress/proxies
        net.core.somaxconn = 8192
        net.ipv4.tcp_max_syn_backlog = 8192
        # Máximo de descriptores de archivos para pods de alta concurrencia
        fs.file-max = 2097152
  recommend:
    - profile: lab-worker-profile
      priority: 20
      match:
        - label: node-role.kubernetes.io/worker
        - label: node-role.kubernetes.io/infra

No requiere reinicio de las máquinas. tuned detecta el recurso y aplica los parámetros del kernel dinámicamente en caliente.