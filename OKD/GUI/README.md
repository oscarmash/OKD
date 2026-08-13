# Verificación y Resolución de Problemas de la Consola Web (OKD)

## Credenciales y Acceso a la GUI

### Obtener contraseña del usuario "kubeadmin"

```
[root@bastion ~]# cat /root/cluster-okd/auth/kubeadmin-password
i62yI-b8w8b-toW6G-uNPKk
```

### Obtener la URL de la Consola Web

```
[root@bastion ~]# oc get route console -n openshift-console
NAME      HOST/PORT                                     PATH   SERVICES   PORT    TERMINATION          WILDCARD
console   console-openshift-console.apps.okd.ilba.cat          console    https   reencrypt/Redirect   None
```

## Verificación de Componentes de Interfaz y Autenticación

Si la interfaz no carga o se queda en pantalla negra, comprueba que los pods del Ingress, Consola y OAuth estén en estado Running:

```
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
NAME             VERSION             AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
authentication   4.21.0-okd-scos.9   True        False         False      3d21h
```

## Procedimientos de Troubleshooting

### La Consola o el OAuth se quedan bloqueados

```
[root@bastion ~]# oc rollout restart deployment/oauth-openshift -n openshift-authentication
[root@bastion ~]# oc rollout restart deployment/console -n openshift-console

[root@bastion ~]# oc delete pods --all -n openshift-authentication --grace-period=0 --force
[root@bastion ~]# oc delete pod -n openshift-authentication-operator --all --grace-period=0 --force
```

### Error the server doesn't have a resource type "route"

```
[root@bastion ~]# oc get route console -n openshift-console
error: the server doesn't have a resource type "route"

[root@bastion ~]# oc get apiservice v1.route.openshift.io
NAME                    SERVICE                   AVAILABLE                      AGE
v1.route.openshift.io   openshift-apiserver/api   False (FailedDiscoveryCheck)   3d23h
```

```
[root@bastion ~]# oc get csr | grep -i pending
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve
[root@bastion ~]# oc get csr -o name | xargs oc adm certificate approve
```