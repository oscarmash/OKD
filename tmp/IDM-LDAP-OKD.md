# IdM (Identity Management)

Indice

xxxxx

# Estrategias de autenticación entre K8s y Red Hat IdM

Red Hat IdM es un servidor LDAP (389-ds) + Kerberos KDC, pero no incluye de fábrica un emisor OpenID Connect (OIDC / OAuth2), pero tenemos varias opciones para poderlo integrar con K8s:
* Kubernetes Webhook con guard o SSSD
* Autenticación por Kerberos / SPNEGO (emitir tickets Kerberos a cada WorkStation)
* Proxy de autenticación OIDC ultraligero (dex)


| Criterio | Kubernetes Webhook directo (LDAP / SSSD / Guard) | Autenticación Kerberos / SPNEGO | Conector OIDC ultraligero (Dex) |
| :--- | :--- | :--- | :--- |
| **Protocolo cliente $\leftrightarrow$ API** | Token HTTP / Webhook Token | Kerberos Ticket (SPNEGO via Webhook) | OpenID Connect (OIDC / JWT) |
| **Protocolo intermedio hacia IdM** | LDAP / LDAPS directo (puerto 389 / 636) | Kerberos KDC (puerto 88) | LDAP / LDAPS directo (puerto 389 / 636) |
| **Experiencia en CLI (`kubectl`)** | Directa por consola (usuario + password o token estático) | Nativa de SO (`kinit usuario` y `kubectl` valida directo) | Vía navegador o terminal interactiva (`kubelogin`) |
| **Soporte MFA / 2FA** | Limitado (solo si el servicio webhook o LDAP soporta OTP inline) | Complejo de implementar en CLI | Fácil (soporta flujos web delegados o TOTP en IdM) |
| **Compatibilidad con herramientas GUI (Lens, Dashboards)** | Alta (acepta tokens directos en cabeceras Bearer) | Muy baja (pocas GUIs soportan SPNEGO/Kerberos nativo) | Máxima (cualquier herramienta moderna soporta OIDC) |
| **Modificaciones en `kube-apiserver`** | `--authentication-token-webhook-config-file` | `--authentication-token-webhook-config-file` | Parámetros estándar OIDC (`--oidc-issuer-url`, `--oidc-client-id`, etc.) |
| **Complejidad de despliegue** | **Media:** Requiere compilar/desplegar un pod webhook TLS de confianza | **Alta:** Requiere keytabs, SPNs, sincronización horaria estricta y proxy SPNEGO | **Baja:** Un solo contenedor con un archivo `config.yaml` apuntando a `idm.ilba.cat` |
| **Madurez y soporte comunitario** | Proyectos dispersos (`appscode/guard`, scripts Go propios) | Nicho corporativo específico | **Estándar CNCF / Kubernetes de facto** para puentear LDAP a K8s |

> Descartamos la autenticación por _Kerberos / SPNEGO_, ya que requeriría unir al dominio (kerberizar) cada equipo cliente que necesite conectarse a la API de Kubernetes

La diferencia entre Webhook y DEX es:
* Webhook directo (LDAP / SSSD / Guard)
  * kubectl habla con la API de kubernetes y esta le pasa la authenticación al WebHook, y de aquí con el IdM
  * El protocilo de comunicación es HTTP y LDAP
* Conector OIDC ultraligero (Dex)
  * kubectl habla con Dex y de aquí con el iDM
  * El protocolo de comunicación es OIDC y LDAP
  * Es significativamente más seguro que un Webhook directo con LDAP


# Enlaces de interés

URLs de interes:
* Ver los [equipos registrados en RedHat](https://console.redhat.com/insights/inventory)
* Proyecto [DEX](https://www.cncf.io/projects/dex/): fue donado por RedHat a la CNCF

# Proxy de autenticación OIDC ultraligero (dex)

## Arquitectura

```
[ kubectl + kubelogin ] ──(1. Login OIDC)──> [ Dex (en Pod) ] ──(2. LDAP / LDAPS)──> [ Red Hat IdM ]
           │                                        │
           │                                (3. Emite ID Token JWT)
           ▼                                        ▼
    [ kube-apiserver ] <────────────────────────────┘
     (Valida JWT por OIDC y aplica RBAC al grupo k8s-admins)
```




frontend okd_https_ingress_frontend
    bind 10.26.0.5:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    # Desvío a IDM si el SNI coincide
    use_backend idm_backend if { req_ssl_sni -i idm.172.26.0.12.nip.io }
    use_backend idm_backend if { req_ssl_sni -i idm.ilba.cat }
    
    # Resto de tráfico hacia los workers de OpenShift
    default_backend okd_https_ingress_backend

backend idm_backend
    mode tcp
    server idm-rhel10 IP_DE_TU_VM_IDM:443 check



--------

Obtener la CA de Red Hat IdM

scp root@172.26.0.29:/etc/ipa/ca.crt ./idm-ca.crt
kubectl create namespace dex
kubectl create configmap idm-ca --from-file=ca.crt=./idm-ca.crt -n dex

Crear el certificado TLS para Dex. Podriamos usar la CA interna de Kubernetes, pero preferimos no mezclar conceptos

cd /tmp
openssl genrsa -out dex.key 2048
openssl req -new -key dex.key -out dex.csr -subj "/CN=dex.ilba.cat"

cat <<EOF > dex-ext.cnf
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dex.ilba.cat
DNS.2 = dex.dex.svc.cluster.local
IP.1 = 172.26.0.230
EOF

openssl x509 -req -in dex.csr \
  -CA /etc/kubernetes/ssl/ca.crt \
  -CAkey /etc/kubernetes/ssl/ca.key \
  -CAcreateserial -out dex.crt -days 365 -extfile dex-ext.cnf

kubectl create ns dex
kubectl create secret tls dex-tls --cert=dex.crt --key=dex.key -n dex

cat <<'EOF' > dex-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-config
  namespace: dex
data:
  config.yaml: |
    issuer: https://dex.ilba.cat:32000
    storage:
      type: memory
    web:
      https: 0.0.0.0:5556
      tlsCert: /etc/dex/tls/tls.crt
      tlsKey: /etc/dex/tls/tls.key

    connectors:
    - type: ldap
      id: ldap
      name: RedHat-IdM
      config:
        host: idm.ilba.cat:636
        rootCA: /etc/dex/ldap-ca/ca.crt
        insecureNoSSL: false
        insecureSkipVerify: false
        bindDN: uid=svc-dex,cn=users,cn=accounts,dc=ilba,dc=cat
        bindPW: C@dinor1988
        userSearch:
          baseDN: cn=users,cn=accounts,dc=ilba,dc=cat
          filter: "(objectClass=person)"
          username: uid
          idAttr: uid
          emailAttr: mail
          nameAttr: cn
        groupSearch:
          baseDN: cn=groups,cn=accounts,dc=ilba,dc=cat
          filter: "(objectClass=ipausergroup)"
          userMatchers:
          - userAttr: DN
            groupAttr: member
          nameAttr: cn

    staticClients:
    - id: kubernetes
      name: 'Kubernetes CLI'
      secret: z2H9kL0pQ4vR8tY1wX5bN7mJ3
      redirectURIs:
      - 'http://localhost:8000'
      - 'http://localhost:18000'
EOF
kubectl apply -f dex-configmap.yaml

Desplegar Dex

cat <<'EOF' > dex-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex
  namespace: dex
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dex
  template:
    metadata:
      labels:
        app: dex
    spec:
      hostAliases:
      - ip: "172.26.0.29"
        hostnames:
        - "idm.ilba.cat"
      containers:
      - name: dex
        image: ghcr.io/dexidp/dex:v2.41.1
        command: ["dex", "serve", "/etc/dex/cfg/config.yaml"]
        ports:
        - name: https
          containerPort: 5556
        volumeMounts:
        - name: config
          mountPath: /etc/dex/cfg
        - name: tls
          mountPath: /etc/dex/tls
        - name: ldap-ca
          mountPath: /etc/dex/ldap-ca
      volumes:
      - name: config
        configMap:
          name: dex-config
      - name: tls
        secret:
          secretName: dex-tls
      - name: ldap-ca
        configMap:
          name: idm-ca
---
apiVersion: v1
kind: Service
metadata:
  name: dex
  namespace: dex
spec:
  type: NodePort
  ports:
  - name: https
    port: 5556
    targetPort: 5556
    nodePort: 32000
  selector:
    app: dex
EOF
kubectl apply -f dex-deployment.yaml

Configurar el kube-apiserver

echo "172.26.0.230 dex.ilba.cat" >> /etc/hosts

cp /etc/kubernetes/ssl/ca.crt /etc/kubernetes/ssl/oidc/dex-ca.pem
chmod 644 /etc/kubernetes/ssl/oidc/dex-ca.pem

/etc/kubernetes/manifests/kube-apiserver.yaml:
- --oidc-issuer-url=https://dex.ilba.cat:32000
    - --oidc-client-id=kubernetes
    - --oidc-ca-file=/etc/kubernetes/ssl/oidc/dex-ca.pem
    - --oidc-username-claim=email
    - --oidc-groups-claim=groups

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: idm-cluster-admins
subjects:
- kind: Group
  name: "k8s-admins"               # Grupo creado en Red Hat IdM
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

kubectl apply -f idm-rbac.yaml

Probar desde el cliente:

/etc/hosts
172.26.0.230 dex.ilba.cat

kubectl oidc-login get-token \
  --oidc-issuer-url=https://dex.ilba.cat:32000 \
  --oidc-client-id=kubernetes \
  --oidc-client-secret=z2H9kL0pQ4vR8tY1wX5bN7mJ3 \
  --certificate-authority=/etc/kubernetes/ssl/oidc/dex-ca.pem \
  --oidc-extra-scope=groups \
  --oidc-extra-scope=email

