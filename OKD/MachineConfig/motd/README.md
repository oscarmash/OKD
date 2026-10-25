# MachineConfig con "motd"

Cambiaremos el motd de los equipos, para ver como funciona el MachineConfig

```
[root@bastion ~]# ssh core@master1
CentOS Stream CoreOS 10.0.20260806-0
  Part of OpenShift 4.22, RHCOS is a Kubernetes-native operating system
  managed by the Machine Config Operator (`clusteroperator/machine-config`).

WARNING: Direct SSH access to machines is not recommended; instead,
make configuration changes via `machineconfig` objects:
  https://docs.openshift.com/container-platform/4.22/architecture/architecture-rhcos.html

---
Last login: Sun Oct 25 11:58:58 2026 from 10.26.0.5
```

```
[root@bastion ~]# echo -n "=== Nodo gestionado por Machine Config Operator ===" | base64
PT09IE5vZG8gZ2VzdGlvbmFkbyBwb3IgTWFjaGluZSBDb25maWcgT3BlcmF0b3IgPT09

[root@bastion ~]# vim infra/manifest/50-worker-motd.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 50-master-motd
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - path: /etc/motd
        mode: 420
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,PT09IE5vZG8gZ2VzdGlvbmFkbyBwb3IgTWFjaGluZSBDb25maWcgT3BlcmF0b3IgPT09
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 50-worker-motd
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - path: /etc/motd
        mode: 420
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,PT09IE5vZG8gZ2VzdGlvbmFkbyBwb3IgTWFjaGluZSBDb25maWcgT3BlcmF0b3IgPT09

[root@bastion ~]# oc apply -f infra/manifest/50-worker-motd.yaml
```

```
[root@bastion ~]# oc get MachineConfig
NAME                                               GENERATEDBYCONTROLLER                      IGNITIONVERSION   AGE
...
50-master-motd                                                                                3.2.0             3m20s
50-worker-motd                                                                                3.2.0             3m20s
...
```

```
[root@bastion ~]# oc get nodes
NAME               STATUS                     ROLES                  AGE   VERSION
master1.ilba.cat   Ready                      control-plane,master   39h   v1.35.5
master2.ilba.cat   Ready,SchedulingDisabled   control-plane,master   40h   v1.35.5
master3.ilba.cat   Ready                      control-plane,master   39h   v1.35.5
worker1.ilba.cat   Ready,SchedulingDisabled   infra                  2d    v1.35.5
worker2.ilba.cat   Ready                      infra                  2d    v1.35.5
worker3.ilba.cat   Ready,SchedulingDisabled   worker                 2d    v1.35.5
worker4.ilba.cat   Ready                      worker                 2d    v1.35.5
```

¿Por qué aparece SchedulingDisabled?: Cuando el MCO detecta una actualización en un MachineConfigPool (como cuando aplicas tu YAML), no modifica las máquinas en caliente ni a lo loco para no tirar las aplicaciones. Sigue un procedimiento de mantenimiento seguro llamado Drain & Reboot

```
[root@bastion ~]# ssh core@worker1
=== Nodo gestionado por Machine Config Operator ===
Last login: Fri Aug 28 08:23:17 2026 from 10.26.0.5
```