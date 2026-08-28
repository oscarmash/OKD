# Configuración de nodos mediante MachineConfig (MCO)


Tener en cuenta que el sistema operativo es un sistema de archivos de solo lectura (/usr está montado como read-only):
* Red Hat Enterprise Linux CoreOS (RHCOS)
* CentOS Stream CoreOS (SCOS)

A diferencia de una distribución tradicional como RHEL, CentOS o Ubuntu, RHCOS/SCOS no está pensado para ser gestionado de forma individual por un administrador de sistemas mediante SSH, sino para ser un componente más controlado automáticamente por OpenShift/OKD

* /usr en solo lectura (read-only): Todos los binarios, librerías y componentes del sistema operativo residen en /usr.
* Inspirado en Git (rpm-ostree): RHCOS/SCOS utiliza una tecnología llamada ostree (a menudo descrita como "Git para el sistema operativo"). Las actualizaciones del SO no se realizan actualizando paquetes individualmente (dnf update), sino descargando una nueva imagen completa de sistema operativo (un "commit" de la imagen) y conmutando hacia ella mediante un reinicio del nodo.
* El arranque y la instalación lo lleva un componente llamado: ignition
* No hay dnf ni yum habilitados por defecto (no puedes hacer un "dnf install nginx")
* No hay servicios locales extra: No debes habilitar servicios nativos (como Apache, MySQL, etc.) directamente en el SO. Todo lo que ejecutes debe ir dentro de Pod/Contenedores gestionados por Kubernetes/OKD

# Ejemplo de MachineConfig con "motd"

Cambiaremos el motd de los equipos, para ver como funciona el MachineConfig

```
[root@bastion ~]# ssh core@worker1
```

```
[root@bastion ~]# echo -n "=== Nodo gestionado por Machine Config Operator ===" | base64
PT09IE5vZG8gZ2VzdGlvbmFkbyBwb3IgTWFjaGluZSBDb25maWcgT3BlcmF0b3IgPT09

[root@bastion ~]# vim manifest/50-worker-motd.yaml
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
        mode: 420 # Octal 0644
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,PT09IE5vZG8gZ2VzdGlvbmFkbyBwb3IgTWFjaGluZSBDb25maWcgT3BlcmF0b3IgPT09

[root@bastion ~]# oc apply -f manifest/50-worker-motd.yaml
```

```
[root@bastion ~]# oc get nodes
NAME               STATUS                     ROLES                  AGE   VERSION
master1.ilba.cat   Ready                      control-plane,master   11d   v1.34.4
master2.ilba.cat   Ready                      control-plane,master   11d   v1.34.4
master3.ilba.cat   Ready                      control-plane,master   11d   v1.34.4
worker1.ilba.cat   Ready,SchedulingDisabled   worker                 10d   v1.34.4
worker2.ilba.cat   Ready                      worker                 10d   v1.34.4
worker3.ilba.cat   Ready                      worker                 8d    v1.34.4
worker4.ilba.cat   Ready                      worker                 8d    v1.34.4
```

¿Por qué aparece SchedulingDisabled?: Cuando el MCO detecta una actualización en un MachineConfigPool (como cuando aplicas tu YAML), no modifica las máquinas en caliente ni a lo loco para no tirar las aplicaciones. Sigue un procedimiento de mantenimiento seguro llamado Drain & Reboot

```
[root@bastion ~]# ssh core@worker1
=== Nodo gestionado por Machine Config Operator ===
Last login: Fri Aug 28 08:23:17 2026 from 10.26.0.5
```