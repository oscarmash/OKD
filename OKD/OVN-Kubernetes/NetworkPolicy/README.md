
# Validaciones

Verificamos que etot esté funcionando correctamente:

```
[root@bastion ~]# oc get nodes
NAME               STATUS   ROLES                  AGE   VERSION
master1.ilba.cat   Ready    control-plane,master   23h   v1.34.4
master2.ilba.cat   Ready    control-plane,master   23h   v1.34.4
master3.ilba.cat   Ready    control-plane,master   23h   v1.34.4
worker1.ilba.cat   Ready    worker                 23h   v1.34.4
worker2.ilba.cat   Ready    worker                 23h   v1.34.4
```

```
[root@bastion ~]# oc get pods -n openshift-multus -o wide
[root@bastion ~]# oc get pods -n openshift-ovn-kubernetes -o wide
```

# OVN-Kubernetes, NetworkPolicies

```
[root@bastion ~]# oc new-project ns-frontend
[root@bastion ~]# oc new-project ns-backend
```

```
[root@bastion ~]# oc run server-pod --image=nginx --port=80 -n ns-backend
[root@bastion ~]# oc run client-pod --image=busybox -n ns-frontend -- sleep 3600
```

```
[root@bastion ~]# oc get pods -n ns-backend
NAME         READY   STATUS    RESTARTS   AGE
server-pod   1/1     Running   0          45s

[root@bastion ~]# oc get pods -n ns-frontend
NAME         READY   STATUS    RESTARTS   AGE
client-pod   1/1     Running   0          26s
```

```
[root@bastion ~]# SERVER_IP=$(oc get pod server-pod -n ns-backend -o jsonpath='{.status.podIP}')
[root@bastion ~]# oc exec -it client-pod -n ns-frontend -- wget -qO- --timeout=3 http://$SERVER_IP    <-- OK
```

```
[root@bastion ~]# vim manifest/test-NetworkPolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-with-logging
  namespace: ns-backend
  annotations:
    k8s.ovn.org/acl-logging: |
      {
        "type": "alert",
        "deny": "alert"
      }
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```
[root@bastion ~]# oc apply -f manifest/test-NetworkPolicy.yaml
[root@bastion ~]# oc exec -it client-pod -n ns-frontend -- wget -qO- --timeout=3 http://$SERVER_IP    <-- TimeOut
```
