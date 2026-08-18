Asignamos una etiqueta a los nodos workers para indicarle a OVN-Kubernetes en cuáles de ellos se puede alojar la IP de salida:

```
[root@bastion ~]# oc label node worker1.ilba.cat k8s.ovn.org/egress-assignable=""
[root@bastion ~]# oc label node worker2.ilba.cat k8s.ovn.org/egress-assignable=""
```

Creamos un namespace de prueba (test-egress) y asignamos una etiqueta al namespace (que luego usará la EgressIP para hacer match):

```
[root@bastion ~]# oc new-project test-egress
[root@bastion ~]# oc label namespace test-egress environment=test
[root@bastion ~]# oc get ns test-egress --show-labels
```

Desplegamos un pod dentro de este namespace:

```
[root@bastion ~]# oc run egress-client --image=busybox -n test-egress -- sleep 3600
```

```
[root@bastion ~]# vim manifest/egress-ip.yaml
apiVersion: k8s.ovn.org/v1
kind: EgressIP
metadata:
  name: egress-test-ip
spec:
  egressIPs:
    - 10.26.0.250
  namespaceSelector:
    matchLabels:
      environment: test
```

```
[root@bastion ~]# oc apply -f manifest/egress-ip.yaml

[root@bastion ~]# oc get egressip
NAME             EGRESSIPS     ASSIGNED NODE      ASSIGNED EGRESSIPS
egress-test-ip   10.26.0.250   worker1.ilba.cat   10.26.0.250
```

```
[root@bastion ~]# oc exec -it egress-client -n test-egress -- wget -qO- http://10.26.0.5:8080
[root@bastion ~]# tail -f /var/log/httpd/access_log
10.26.0.250 - - [18/Aug/2026:13:28:08 +0200] "GET / HTTP/1.1" 403 5760 "-" "Wget"
```
