# MachineConfig con "chrony"

En RHCOS / CentOS Stream CoreOS, chrony ya viene instalado de fábrica y se ejecuta como servicio del sistema (chronyd.service).
No es necesario instalar ningún paquete RPM, únicamente configurar el archivo /etc/chrony.conf y reiniciar el servicio.

```
cat << 'EOF' > /tmp/chrony.conf
server hora.roa.es iburst
server minuto.roa.es iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
```

```
[root@bastion ~]# base64 -w0 /tmp/chrony.conf
c2VydmVyIGhvcmEucm9hLmVzIGlidXJzdApzZXJ2ZXIgbWludXRvLnJvYS5lcyBpYnVyc3QKZHJpZnRmaWxlIC92YXIvbGliL2Nocm9ueS9kcmlmdAptYWtlc3RlcCAxLjAgMwpydGNzeW5jCmxvZ2RpciAvdmFyL2xvZy9jaHJvbnkK
```

```
[root@bastion ~]# vim infra/manifest/51-chrony.yaml
kind: MachineConfig
metadata:
  name: 51-master-chrony
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - path: /etc/chrony.conf
        mode: 420 # 0644
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,c2VydmVyIGhvcmEucm9hLmVzIGlidXJzdApzZXJ2ZXIgbWludXRvLnJvYS5lcyBpYnVyc3QKZHJpZnRmaWxlIC92YXIvbGliL2Nocm9ueS9kcmlmdAptYWtlc3RlcCAxLjAgMwpydGNzeW5jCmxvZ2RpciAvdmFyL2xvZy9jaHJvbnkK
    systemd:
      units:
      - name: chronyd.service
        enabled: true
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 51-worker-chrony
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - path: /etc/chrony.conf
        mode: 420 # 0644
        overwrite: true
        contents:
          source: data:text/plain;charset=utf-8;base64,c2VydmVyIGhvcmEucm9hLmVzIGlidXJzdApzZXJ2ZXIgbWludXRvLnJvYS5lcyBpYnVyc3QKZHJpZnRmaWxlIC92YXIvbGliL2Nocm9ueS9kcmlmdAptYWtlc3RlcCAxLjAgMwpydGNzeW5jCmxvZ2RpciAvdmFyL2xvZy9jaHJvbnkK
    systemd:
      units:
      - name: chronyd.service
        enabled: true

[root@bastion ~]# oc apply -f  infra/manifest/51-chrony.yaml
```

```
[root@bastion ~]# oc get MachineConfig
NAME                                               GENERATEDBYCONTROLLER                      IGNITIONVERSION   AGE
...
51-master-chrony                                                                              3.2.0             13s
51-worker-chrony                                                                              3.2.0             13s
...
```

Verificación:

```
for node in master1 master2 master3 worker1 worker2 worker3 worker4; do
  echo "==================== $node.ilba.cat ===================="
  ssh -o StrictHostKeyChecking=no core@$node "grep -E '^server ' /etc/chrony.conf && chronyc sources"
done
```