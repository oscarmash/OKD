# Envoy (Proxy Inverso)

Envoy = rendimiento extremo + control quirúrgico

No se le puede llamr Gateway API Gateway porque no es un programa ni un proxy: es una especificación / conjunto de interfaces (CRDs) de Kubernetes (como Gateway, HTTPRoute, etc.).

Que puede hacr envoy:
* Enrutamiento L7 y gestión de tráfico avanzada:
  * Traffic Splitting / Canaries
  * Enrutamiento por contenido -> Desvío de tráfico según cabeceras HTTP, métodos, rutas de URL (path/regex), cookies o query parameters
  * Traffic Shadowing / Mirroring -> Duplica el tráfico de producción hacia un backend de pruebas de forma asíncrona sin afectar al usuario.
  * Manipulación de cabeceras -> Inserción, borrado y transformación de cabeceras de petición y respuesta al vuelo.<>
* Seguridad y Control de Acceso
  * Autorización Externa (ext_authz)
  * TLS/mTLS
* Resiliencia y Protección de Backends
  * Rate Limiting -> Control de concurrencia tanto local (en el propio nodo) como global distribuido (utilizando servicios Redis externos de cuotas).
  * Circuit Breaking -> Límite estricto de conexiones simultáneas, peticiones pendientes y reintentos para evitar caídas en cascada.
  * Outlier Detection -> Expulsa temporalmente del balanceo a un pod o servidor si empieza a devolver errores 5xx consecutivos.
* Soporte multiprotocolo:
  * HTTP/1.1, HTTP/2 y HTTP/3 -> Traducción transparente bidireccional entre versiones de HTTP
  * gRPC
  * Capas L4 y protocolos de datos: Proxy TCP/UDP crudo con decodificadores específicos para MongoDB, Postgres o Redis
* Observabilidad de primer nivel:
  * Distributed Tracing -> Genera e inyecta identificadores de traza compatibles con Jaeger, Zipkin y OpenTelemetry.
  * Métricas exhaustivas

## Prerequisitos

Comprobamos si los CRDs de Gateway API ya existen

```
[root@bastion ~]# oc get crd | grep -iE "gateway.networking.k8s.io"
backendtlspolicies.gateway.networking.k8s.io                               2026-09-25T11:00:38Z
gatewayclasses.gateway.networking.k8s.io                                   2026-09-03T12:16:39Z
gateways.gateway.networking.k8s.io                                         2026-09-03T12:16:39Z
grpcroutes.gateway.networking.k8s.io                                       2026-09-03T12:16:39Z
httproutes.gateway.networking.k8s.io                                       2026-09-03T12:16:39Z
referencegrants.gateway.networking.k8s.io                                  2026-09-03T12:16:40Z
```

Saber la versión que tenemos instalada:

```
[root@bastion ~]# oc get crd gateways.gateway.networking.k8s.io -o yaml | grep bundle-version
    gateway.networking.k8s.io/bundle-version: v1.4.1
```

## Instalación

No existe el paquete OLM, así que lo instalaremos via Helm:

```
[root@bastion ~]# oc get packagemanifest -n openshift-marketplace | grep -iE "envoy|gateway"
ack-apigateway-controller                   Community Operators   23d
ack-apigatewayv2-controller                 Community Operators   23d
```

### Instalación via Helm de Envoy

```
[root@bastion ~]# oc create namespace envoy-gateway-system

[root@bastion ~]# oc adm policy add-scc-to-group anyuid system:serviceaccounts:envoy-gateway-system
[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:envoy-gateway-system
```

```
helm install eg oci://docker.io/envoyproxy/gateway-helm \
--version v1.9.1 \
-n envoy-gateway-system \
--create-namespace \
--skip-crds
```

```
[root@bastion ~]# helm -n envoy-gateway-system ls
NAME    NAMESPACE               REVISION        UPDATED                                         STATUS          CHART                   APP VERSION
eg      envoy-gateway-system    1               2026-09-27 10:15:01.919587424 +0200 CEST        deployed        gateway-helm-v1.9.1     v1.9.1
```

El siguiewnte pod (envoy-gateway), su único trabajo es vigilar la API de Kubernetes (escuchar Gateway, HTTPRoute, etc.) y traducir esa configuración en órdenes gRPC para los proxies. Es correcto que sólo haya 1 pod.

¿Dónde están los proxies Envoy? -> En cuanto se cree un recurso Gateway, Envoy Gateway creará automáticamente un Deployment nuevo de proxies Envoy.

```
[root@bastion ~]# oc get pods -n envoy-gateway-system
NAME                            READY   STATUS    RESTARTS   AGE
envoy-gateway-54b57d4f5-k5kw5   1/1     Running   0          70s
```

### Instalación de CRD's de Envoy

#### Via Helm (FAILED)

No podemos instalarlo via Helm, porque hay objetos que supera 1MB y la API de Kubernetes lo rechaza, el problema es que los CRDs de Envoy Gateway son gigantescos porque definen esquemas de validación OpenAPI v3 extremadamente detallados.

```
[root@bastion ~]# helm install eg-crds oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.9.1 \
  --set gatewayAPI.install=false
Pulled: docker.io/envoyproxy/gateway-crds-helm:v1.9.1
Digest: sha256:45693764cab8aae661bc32f0f706f5c8e5aaa9a151b6d03fb0a468cc535a155c
Error: INSTALLATION FAILED: create: failed to create: Secret "sh.helm.release.v1.eg-crds.v1" is invalid: data: Too long: may not be more than 1048576 bytes
```

#### Via Helm Pull (OK)

Nos los hemos de descargar y aplicar:

```
[root@bastion tmp]# mkdir -p /tmp/eg-crds && cd /tmp/eg-crds
[root@bastion eg-crds]# helm pull oci://docker.io/envoyproxy/gateway-helm --version v1.9.1 --untar

[root@bastion eg-crds]# ls -la /tmp/eg-crds/gateway-helm/charts/crds/crds/generated/
total 2512
drwxr-xr-x. 2 root root    4096 Sep 27 11:23 .
drwxr-xr-x. 3 root root      51 Sep 27 11:23 ..
-rw-r--r--. 1 root root   29000 Sep 27 11:23 gateway.envoyproxy.io_backends.yaml
-rw-r--r--. 1 root root  223986 Sep 27 11:23 gateway.envoyproxy.io_backendtrafficpolicies.yaml
-rw-r--r--. 1 root root  123719 Sep 27 11:23 gateway.envoyproxy.io_clienttrafficpolicies.yaml
-rw-r--r--. 1 root root  168531 Sep 27 11:23 gateway.envoyproxy.io_envoyextensionpolicies.yaml
-rw-r--r--. 1 root root   28094 Sep 27 11:23 gateway.envoyproxy.io_envoypatchpolicies.yaml
-rw-r--r--. 1 root root 1412988 Sep 27 11:23 gateway.envoyproxy.io_envoyproxies.yaml
-rw-r--r--. 1 root root   28014 Sep 27 11:23 gateway.envoyproxy.io_httproutefilters.yaml
-rw-r--r--. 1 root root  538338 Sep 27 11:23 gateway.envoyproxy.io_securitypolicies.yaml

[root@bastion eg-crds]# oc apply --server-side -f /tmp/eg-crds/gateway-helm/charts/crds/crds/generated/

[root@bastion eg-crds]# oc get crd | grep -iE "gateway.envoyproxy.io"
backends.gateway.envoyproxy.io                                             2026-09-27T09:24:52Z
backendtrafficpolicies.gateway.envoyproxy.io                               2026-09-27T09:24:53Z
clienttrafficpolicies.gateway.envoyproxy.io                                2026-09-27T09:24:53Z
envoyextensionpolicies.gateway.envoyproxy.io                               2026-09-27T09:24:53Z
envoypatchpolicies.gateway.envoyproxy.io                                   2026-09-27T09:24:53Z
envoyproxies.gateway.envoyproxy.io                                         2026-09-27T09:24:54Z
httproutefilters.gateway.envoyproxy.io                                     2026-09-27T09:24:55Z
securitypolicies.gateway.envoyproxy.io                                     2026-09-27T09:24:55Z
```

## Envoy NodePort (30080)

```
[root@bastion ~]# vim manifest/00-envoy_EnvoyProxy.yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: eg-proxy-config
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 2
      envoyService:
        type: NodePort
        externalTrafficPolicy: Cluster
        ports:
          - name: http
            port: 8080
            targetPort: 8080
            nodePort: 30080
```

```
[root@bastion ~]# oc apply -f manifest/00-envoy_EnvoyProxy.yaml

[root@bastion ~]# oc -n envoy-gateway-system get pods
NAME                                                             READY   STATUS    RESTARTS   AGE
envoy-envoy-gateway-system-eg-gateway-b87277ac-b8758bf4d-7ghjk   2/2     Running   0          12s
envoy-envoy-gateway-system-eg-gateway-b87277ac-b8758bf4d-grlx7   2/2     Running   0          20m
envoy-gateway-54b57d4f5-k5kw5                                    1/1     Running   2          11h

[root@bastion ~]# oc get svc -A | grep -i envoy-gateway-system | grep NodePort | awk '{print $6}'
8080:30080/TCP
```


## Ejemplo de funcionamiento

```
[root@bastion ~]# oc new-project test-envoy
[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:test-envoy
```

### Deployment + Service

```
[root@bastion ~]# vim manifest/01-test-envoy_deploy-svc.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-app
  namespace: test-envoy
  labels:
    app: echo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: echo-app
  template:
    metadata:
      labels:
        app: echo-app
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:0.2.3
        args:
        - "-text=Hola desde el pod: $(HOSTNAME)\n"
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-svc
  namespace: test-envoy
  labels:
    app: echo-app
spec:
  ports:
  - name: http
    port: 80
    targetPort: 5678
  selector:
    app: echo-app
```

```
[root@bastion ~]# oc apply -f manifest/01-test-envoy_deploy-svc.yaml
```

```
[root@bastion ~]# oc -n test-envoy get svc
NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
echo-svc   ClusterIP   172.30.219.154   <none>        80/TCP    24s

[root@bastion ~]# ssh core@master1.ilba.cat

[core@master1 ~]$ curl 172.30.219.154
Hola desde el pod: echo-app-65bc5cd765-2dtts
```

### GatewayClass + Gateway

```
[root@bastion ~]# vim manifest/01-test-envoy_GatewayClass_Gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: eg-proxy-config
    namespace: envoy-gateway-system
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg-gateway
  namespace: envoy-gateway-system
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 8080
      allowedRoutes:
        namespaces:
          from: All
```

```
[root@bastion ~]# oc apply -f manifest/01-test-envoy_GatewayClass_Gateway.yaml
```

### HTTPRoute

```
[root@bastion ~]# vim manifest/01-test-envoy_HTTPRoute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo-route
  namespace: test-envoy
spec:
  parentRefs:
  - name: eg-gateway
    namespace: envoy-gateway-system
  hostnames:
  - "echo.172.26.0.12.nip.io"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: echo-svc
      port: 80
```

```
[root@bastion ~]# oc apply -f manifest/01-test-envoy_HTTPRoute.yaml
```

```
[root@bastion ~]# oc get HTTPRoute -A
NAMESPACE    NAME         HOSTNAMES                     AGE
test-envoy   echo-route   ["echo.172.26.0.12.nip.io"]   28s
```

### Test

```
[root@bastion ~]# curl -i -H "Host: echo.172.26.0.12.nip.io" http://10.26.0.24:30080/
HTTP/1.1 200 OK
x-app-name: http-echo
x-app-version: 0.2.3
date: Sun, 27 Sep 2026 19:50:27 GMT
content-length: 46
content-type: text/plain; charset=utf-8

Hola desde el pod: echo-app-65bc5cd765-z6gmp
```