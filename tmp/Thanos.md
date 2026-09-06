# Introducción y arquitectura de Thanos en OKD

En una instalación limpia de OKD/OpenShift: por defecto NO hay Downsampling activo.
Antes he empezar hemos de tener un almacenamiento S3 y haber validado el acceso

Red Hat/OKD optó por no integrar el Compactor en el operador de monitorización para evitar riesgos de corrupción en el almacenamiento de objetos si varios procesos intentaran compactar el mismo bucket a la vez (debe ser estrictamente un singleton). OKD asume que la compactación y retención en S3 la gestionas externamente.

La interfaz gráfica (Thanos - Bucket / Blocks) no forma parte de la consola de OKD ni del operador; es una herramienta auxiliar (thanos tools bucket web) que lee directamente el bucket S3.

| Componente de Thanos | ¿Viene instalado en OKD? | ¿Para qué sirve? |
| :--- | :---: | :--- |
| **Thanos Sidecar** | **Sí** | Lee los datos de Prometheus y sube los bloques TSDB a MinIO. |
| **Thanos Querier** | **Sí** | Consulta métricas unificadas y las muestra en la consola web de OKD. |
| **Thanos Ruler** | **Sí** | Evalúa alertas y reglas de grabación de cargas de usuario. |
| **Thanos Compactor** | **NO** | **Aplica el Downsampling (5m / 1h)** y borra datos antiguos del bucket según tus retenciones. |
| **Thanos Bucket Web** | **NO** | **Es la interfaz web** para ver los bloques ULID y su estado. |

# Comprobación de la Retención Actual de Prometheus

Como saber la retención de prometheus:

```
[root@bastion ~]# oc get statefulset prometheus-k8s -n openshift-monitoring -o jsonpath='{.spec.template.spec.containers[?(@.name=="prometheus")].args}' | tr ',' '\n' | grep 'storage.tsdb.retention.time'
"--storage.tsdb.retention.time=15d"
```

# Configuración del Almacenamiento de Objetos

Le indicamos las credenciales para que Thanos Sidecar pueda subir los bloques a MinIO

```
[root@bastion ~]# vim manifest/thanos-objectstorage.yaml
apiVersion: v1
kind: Secret
metadata:
  name: thanos-objectstorage
  namespace: openshift-monitoring
type: Opaque
stringData:
  thanos.yaml: |
    type: s3
    config:
      bucket: thanos
      endpoint: minio-loki.ilba-minio.svc.cluster.local:9000
      insecure: true
      access_key: "lokiaccesskey"
      secret_key: "lokisecretpassword"
      http_config:
        insecure_skip_verify: true

[root@bastion ~]# oc apply -f manifest/thanos-objectstorage.yaml
```

# Ajuste de Retención y Persistencia del Clúster

Configura el operador de monitorización para habilitar las métricas de cargas de trabajo de usuario, asignar almacenamiento persistente a Prometheus y reducir su retención local en disco a 24 horas.

```
[root@bastion ~]# vim manifest/cluster-monitoring-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    prometheusK8s:
      retention: 24h
      volumeClaimTemplate:
        spec:
          storageClassName: thin-csi
          resources:
            requests:
              storage: 20Gi
      remoteWrite:
        - url: "http://thanos-receive.openshift-monitoring.svc:19291/api/v1/receive"

[root@bastion ~]# oc apply -f manifest/cluster-monitoring-config.yaml
```

# Configuración de Thanos para Métricas de Usuario (User Workload)

```
[root@bastion ~]# vim manifest/openshift-user-workload-monitoring.yaml
apiVersion: v1
kind: Secret
metadata:
  name: thanos-objectstorage
  namespace: openshift-user-workload-monitoring
type: Opaque
stringData:
  thanos.yaml: |
    type: s3
    config:
      bucket: thanos
      endpoint: minio-loki.ilba-minio.svc.cluster.local:9000
      insecure: true
      access_key: "lokiaccesskey"
      secret_key: "lokisecretpassword"
      http_config:
        insecure_skip_verify: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheus:
      retention: 24h
      volumeClaimTemplate:
        spec:
          storageClassName: thin-csi
          resources:
            requests:
              storage: 15Gi
    thanosRuler:
      retention: 24h

[root@bastion ~]# oc apply -f manifest/openshift-user-workload-monitoring.yaml
```

# Despliegue de Thanos Compactor

Despliega el pod singleton de compactación encargado de aplicar los periodos de retención por resolución (6d raw, 17d 5m, 90d 1h), realizar el downsampling matemático y limpiar los bloques eliminados en MinIO.

```
[root@bastion ~]# vim manifest/thanos-compactor.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: thanos-compactor-pvc
  namespace: openshift-monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: thin-csi
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: thanos-compactor
  namespace: openshift-monitoring
  labels:
    app.kubernetes.io/name: thanos-compactor
spec:
  replicas: 1
  serviceName: thanos-compactor
  selector:
    matchLabels:
      app.kubernetes.io/name: thanos-compactor
  template:
    metadata:
      labels:
        app.kubernetes.io/name: thanos-compactor
    spec:
      containers:
      - name: compactor
        image: quay.io/thanos/thanos:v0.37.2
        args:
        - compact
        - --data-dir=/data
        - --objstore.config-file=/etc/thanos/thanos.yaml
        - --retention.resolution-raw=6d
        - --retention.resolution-5m=17d
        - --retention.resolution-1h=90d
        - --delete-delay=1h
        - --compact.concurrency=1
        - --wait
        ports:
        - name: http
          containerPort: 10902
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /etc/thanos
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: thanos-compactor-pvc
      - name: config
        secret:
          secretName: thanos-objectstorage

[root@bastion ~]# oc apply -f manifest/thanos-compactor.yaml
```

# Despliegue de Thanos Bucket Web y exposición de Ruta

Levanta el servidor web que inspecciona el bucket S3 y crea una Route de OKD para publicar la interfaz gráfica bajo el FQDN [https://bucketinfo.172.26.0.12.nip.io/](https://bucketinfo.172.26.0.12.nip.io/blocks)

```
[root@bastion ~]# vim manifest/thanos-bucket-web.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thanos-bucket-web
  namespace: openshift-monitoring
  labels:
    app.kubernetes.io/name: thanos-bucket-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: thanos-bucket-web
  template:
    metadata:
      labels:
        app.kubernetes.io/name: thanos-bucket-web
    spec:
      containers:
      - name: bucket-web
        image: quay.io/thanos/thanos:v0.37.2
        args:
        - tools
        - bucket
        - web
        - --objstore.config-file=/etc/thanos/thanos.yaml
        - --http-address=0.0.0.0:10902
        - --refresh=2m
        ports:
        - name: http
          containerPort: 10902
        volumeMounts:
        - name: config
          mountPath: /etc/thanos
      volumes:
      - name: config
        secret:
          secretName: thanos-objectstorage
---
apiVersion: v1
kind: Service
metadata:
  name: thanos-bucket-web
  namespace: openshift-monitoring
  labels:
    app.kubernetes.io/name: thanos-bucket-web
spec:
  ports:
  - name: http
    port: 10902
    targetPort: 10902
  selector:
    app.kubernetes.io/name: thanos-bucket-web
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: thanos-bucket-web
  namespace: openshift-monitoring
spec:
  host: bucketinfo.172.26.0.12.nip.io
  to:
    kind: Service
    name: thanos-bucket-web
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect

[root@bastion ~]# oc apply -f manifest/thanos-bucket-web.yaml
```

# Despliegue de Thanos Receiver

```
[root@bastion ~]# vim manifest/thanos-receiver.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: thanos-receive-data-pvc
  namespace: openshift-monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: thin-csi
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: thanos-receive
  namespace: openshift-monitoring
  labels:
    app.kubernetes.io/name: thanos-receive
spec:
  replicas: 1
  serviceName: thanos-receive
  selector:
    matchLabels:
      app.kubernetes.io/name: thanos-receive
  template:
    metadata:
      labels:
        app.kubernetes.io/name: thanos-receive
    spec:
      containers:
      - name: thanos-receive
        image: quay.io/thanos/thanos:v0.37.2
        args:
        - receive
        - --tsdb.path=/var/thanos/receive
        - --objstore.config-file=/etc/thanos/thanos.yaml
        - --grpc-address=0.0.0.0:10901
        - --http-address=0.0.0.0:10902
        - --remote-write.address=0.0.0.0:19291
        - --label=receive_replica="thanos-receive-0"
        - --tsdb.retention=24h
        ports:
        - name: grpc
          containerPort: 10901
        - name: http
          containerPort: 10902
        - name: remote-write
          containerPort: 19291
        volumeMounts:
        - name: data
          mountPath: /var/thanos/receive
        - name: config
          mountPath: /etc/thanos
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: thanos-receive-data-pvc
      - name: config
        secret:
          secretName: thanos-objectstorage
---
apiVersion: v1
kind: Service
metadata:
  name: thanos-receive
  namespace: openshift-monitoring
  labels:
    app.kubernetes.io/name: thanos-receive
spec:
  ports:
  - name: grpc
    port: 10901
    targetPort: 10901
  - name: http
    port: 10902
    targetPort: 10902
  - name: remote-write
    port: 19291
    targetPort: 19291
  selector:
    app.kubernetes.io/name: thanos-receive

[root@bastion ~]# oc apply -f manifest/thanos-receiver.yaml

[root@bastion ~]# oc logs -n openshift-monitoring statefulset/thanos-receive -c thanos-receive --tail=30
```

# Verificación del estado y Logs

```
[root@bastion ~]# oc get pods -n openshift-monitoring -l 'app.kubernetes.io/name in (thanos-compactor, thanos-bucket-web)'
NAME                                 READY   STATUS    RESTARTS   AGE
thanos-bucket-web-7b767b676c-xvrdc   1/1     Running   0          17s
thanos-compactor-0                   1/1     Running   0          72s
```

```
[root@bastion ~]# oc logs -n openshift-monitoring statefulset/thanos-compactor -c compactor --tail=30
...
ts=2026-09-05T11:28:45.29052904Z caller=retention.go:32 level=info msg="start optional retention"
ts=2026-09-05T11:28:45.29054356Z caller=retention.go:47 level=info msg="optional retention apply done"
ts=2026-09-05T11:28:45.292708276Z caller=fetcher.go:627 level=info component=block.BaseFetcher msg="successfully synchronized block metadata" duration=2.101225ms duration_ms=2 cached=0 returned=0 partial=0
ts=2026-09-05T11:28:45.292742351Z caller=clean.go:34 level=info msg="started cleaning of aborted partial uploads"
ts=2026-09-05T11:28:45.292754377Z caller=clean.go:61 level=info msg="cleaning of aborted partial uploads done"
ts=2026-09-05T11:28:45.292764474Z caller=blocks_cleaner.go:44 level=info msg="started cleaning of blocks marked for deletion"
ts=2026-09-05T11:28:45.292774046Z caller=blocks_cleaner.go:58 level=info msg="cleaning of blocks marked for deletion done"
ts=2026-09-05T11:29:45.30226098Z caller=fetcher.go:627 level=info component=block.BaseFetcher msg="successfully synchronized block metadata" duration=16.646473ms duration_ms=16 cached=0 returned=0 partial=0
```

> Hay que esperar 2h :arrow_down:

La interfaz cargará vacía inicialmente o con el bucket en estado sincronizado; en cuanto se cumpla la ventana de 2 horas y Prometheus suba el primer bloque TSDB, la web empezará a dibujar las barras y los bloques ULID automáticamente tal como en tu captura.

Enlace de acceso a la consola: [https://bucketinfo.172.26.0.12.nip.io/blocks](https://bucketinfo.172.26.0.12.nip.io/blocks)


