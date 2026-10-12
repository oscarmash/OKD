Detalle completo de un usuario:

```
[root@bastion ~]# oc get users
NAME          UID                                    FULL NAME   IDENTITIES
nuria.ilari   8ca3a2c0-9407-42c9-8c58-4fc874da4c81               htpasswd_provider:nuria.ilari
oscar.mas     b721381f-154e-4657-8aa6-15a2cb40cfb6               htpasswd_provider:oscar.mas
```

Para consultar con qué proveedor (IDP, como HTPasswd, LDAP, etc.) se vincula cada usuario:

```
[root@bastion ~]# oc get identity
NAME                            IDP NAME            IDP USER NAME   USER NAME     USER UID
htpasswd_provider:nuria.ilari   htpasswd_provider   nuria.ilari     nuria.ilari   8ca3a2c0-9407-42c9-8c58-4fc874da4c81
htpasswd_provider:oscar.mas     htpasswd_provider   oscar.mas       oscar.mas     b721381f-154e-4657-8aa6-15a2cb40cfb6
```

Saber el rol de un usuario en concreto en un Namspace:

```
[root@bastion ~]# oc get rolebindings -n test-project-nuria -o wide | grep nuria.ilari
admin                   ClusterRole/admin                  2d    nuria.ilari
```