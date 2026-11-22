# Isntalación

```
oc new-project ilba-awx \
  --description="AWX is the upstream open-source automation platform for Ansible" \
  --display-name="Ansible AWX"
```

```
[root@bastion ~]# helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
[root@bastion ~]# helm repo update
```

No hace falta pasarle ningún archivo values.yaml, ya el chart awx-operator solo despliega el controlador/operador (el pod awx-operator-controller-manager) y sus CRDs.

```
[root@bastion ~]# helm search repo awx-operator/awx-operator
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
awx-operator/awx-operator       3.2.1           2.19.1          The community-supported AWX Operator Helm Chart
```

```
helm upgrade --install \
awx-operator awx-operator/awx-operator \
--namespace ilba-awx \
--version=3.2.1
```

```
[root@bastion ~]# oc get pods -n ilba-awx
NAME                                               READY   STATUS    RESTARTS   AGE
awx-operator-controller-manager-7d579bf564-rxwhh   2/2     Running   0          55s
```

```
oc create secret generic awx-admin-password \
  --from-literal=password='3OwthEpibAkAd' \
  -n ilba-awx
```

```
[root@bastion 53-ilba-awx]# vim awx-instance.yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: ilba-awx
spec:
  service_type: ClusterIP
  ingress_type: Route
  route_host: awx.172.26.0.12.nip.io
  route_tls_termination_mechanism: Edge
  admin_user: admin
  admin_password_secret: awx-admin-password
  postgres_storage_class: rook-ceph-block
  postgres_storage_requirements:
    requests:
      storage: 10Gi
```

```
[root@bastion 53-ilba-awx]# oc apply -f awx-instance.yaml
```

Pasado un rato:

```
[root@bastion 02-rook]# oc get pods -n ilba-awx
NAME                                               READY   STATUS      RESTARTS   AGE
awx-migration-24.6.1-jlt2f                         0/1     Completed   0          9m17s
awx-operator-controller-manager-7d579bf564-rxwhh   2/2     Running     0          27m
awx-postgres-15-0                                  1/1     Running     0          10m
awx-task-59d699b658-4n4cq                          4/4     Running     0          10m
awx-web-5974dcffcf-c24rj                           3/3     Running     0          10m

[root@bastion 02-rook]# oc -n ilba-awx get route
NAME   HOST/PORT                PATH   SERVICES      PORT   TERMINATION     WILDCARD
awx    awx.172.26.0.12.nip.io          awx-service   http   edge/Redirect   None

[root@bastion 02-rook]# oc -n ilba-awx get pvc
NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      VOLUMEATTRIBUTESCLASS   AGE
postgres-15-awx-postgres-15-0   Bound    pvc-cb0c1e63-0d86-4edf-80be-84a9b184d9f5   10Gi       RWO            rook-ceph-block   <unset>                 11m
```
