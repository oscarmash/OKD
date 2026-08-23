```

[root@bastion ~]# oc create namespace openshift-logging

[root@bastion ~]# vim manifest/minio-loki.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-loki-pvc
  namespace: openshift-logging
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: thin-csi
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio-loki
  namespace: openshift-logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio-loki
  template:
    metadata:
      labels:
        app: minio-loki
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - /data
        env:
        - name: MINIO_ROOT_USER
          value: "lokiaccesskey"
        - name: MINIO_ROOT_PASSWORD
          value: "lokis secretpassword"
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: minio-loki-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio-loki
  namespace: openshift-logging
spec:
  ports:
  - port: 9000
    targetPort: 9000
  selector:
    app: minio-loki


[root@bastion ~]# oc apply -f manifest/minio-loki.yaml

[root@bastion ~]# oc -n openshift-logging get pods
NAME                          READY   STATUS    RESTARTS   AGE
minio-loki-7b7f5c5b78-wshsc   1/1     Running   0          36s

[root@bastion ~]# oc -n openshift-logging get pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
minio-loki-pvc   Bound    pvc-8444038d-8796-4a7a-ac59-15351af6b882   50Gi       RWO            thin-csi       <unset>                 47s

[root@bastion ~]# vim manifest/create-bucket-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: create-loki-bucket
  namespace: openshift-logging
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: mc
        image: quay.io/minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          mc alias set myminio http://minio-loki:9000 lokiaccesskey "lokis secretpassword"
          mc mb myminio/loki-data --ignore-existing


[root@bastion ~]# oc apply -f manifest/create-bucket-job.yaml

[root@bastion ~]# oc create secret generic loki-s3-credentials \
  -n openshift-logging \
  --from-literal=access_key_id="lokiaccesskey" \
  --from-literal=access_key_secret="lokis secretpassword" \
  --from-literal=bucketnames="loki-data" \
  --from-literal=endpoint="http://minio-loki.openshift-logging.svc:9000" \
  --from-literal=style="path"


---------------------------------------------------------------------------------------------------------------------------------------------------------------------

Operador de LokiStack

El API de Kubernetes no reconoce la definición del recurso LokiStack porque todavía no se ha instalado el Loki Operator en el clúster. Lo instalamos:

Pero antes hemos de ver que es lo que tenemos en el catálogo

[root@bastion ~]# oc get packagemanifests | grep -i loki
loki-helm-operator                          Community Operators   47h
loki-operator                               Community Operators   47h

[root@bastion ~]# oc get packagemanifest loki-operator -o jsonpath='{.status.channels[*].name}'
alpha

[root@bastion ~]# vim manifest/loki-operator-install.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: loki-operator
  namespace: openshift-operators
spec:
  channel: alpha
  name: loki-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic

[root@bastion ~]# oc apply -f manifest/loki-operator-install.yaml

[root@bastion ~]# oc get installplan -n openshift-operators
NAME            CSV                     APPROVAL    APPROVED
install-lqt7w   loki-operator.v0.10.2   Automatic   true

[root@bastion ~]# oc get csv -n openshift-operators
NAME                    DISPLAY                   VERSION   REPLACES                PHASE
loki-operator.v0.10.2   Community Loki Operator   0.10.2    loki-operator.v0.10.1   Succeeded

[root@bastion ~]# oc get crd lokistacks.loki.grafana.com
NAME                          CREATED AT
lokistacks.loki.grafana.com   2026-08-19T08:11:41Z

[root@bastion ~]# oc get lokistack logging-loki -n openshift-logging -o jsonpath='{.status.conditions}' | jq .

---------------------------------------------------------------------------------------------------------------------------------------------------------------------

[root@bastion ~]# vim manifest/lokistack.yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki
  namespace: openshift-logging
spec:
  size: 1x.extra-small
  replicationFactor: 1
  storage:
    schemas:
      - version: v13
        effectiveDate: "2026-01-01"
    secret:
      name: loki-s3-credentials
      type: s3
  storageClassName: thin-csi
  managementState: Managed
  tenants:
    mode: openshift-logging
  template:
    compactor:
      replicas: 1
    distributor:
      replicas: 1
    ingester:
      replicas: 1
    querier:
      replicas: 1
    queryFrontend:
      replicas: 1
    gateway:
      replicas: 1
    indexGateway:
      replicas: 1

[root@bastion ~]# oc apply -f manifest/lokistack.yaml

[root@bastion ~]# oc get pods -n openshift-logging
NAME                                           READY   STATUS    RESTARTS   AGE
logging-loki-compactor-0                       1/1     Running   0          47s
logging-loki-distributor-5d7cb955b7-bxzql      1/1     Running   0          47s
logging-loki-gateway-5974fd4877-sjh6h          2/2     Running   0          47s
logging-loki-index-gateway-0                   1/1     Running   0          47s
logging-loki-ingester-0                        1/1     Running   0          47s
logging-loki-querier-6fb4cd46b-dvbgx           1/1     Running   0          47s
logging-loki-query-frontend-65f6499f74-skg9p   1/1     Running   0          47s
minio-loki-7b7f5c5b78-wshsc                    1/1     Running   1          24h

---------------------------------------------------------------------------------------------------------------------------------------------------------------------

Instalación de Cluster Logging Operator (CLO)

[root@bastion ~]# oc get catalogsource -n openshift-marketplace
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     2d22h

[root@bastion ~]# oc get packagemanifests | grep -iE "logging|vector|fluent"
neuvector-community-operator                Community Operators   2d23h
ack-s3vectors-controller                    Community Operators   2d23h
logging-operator                            Community Operators   2d23h

[root@bastion ~]# oc get packagemanifest logging-operator -o jsonpath='{.status.channels[*].name}' && echo
beta

[root@bastion ~]# vim manifest/logging-operator-install.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: logging-operator
  namespace: openshift-operators
spec:
  channel: beta
  name: logging-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic

[root@bastion ~]# oc apply -f manifest/logging-operator-install.yaml
[root@bastion ~]# oc get csv -n openshift-operators
NAME                    DISPLAY                   VERSION   REPLACES                PHASE
loki-operator.v0.11.0   Community Loki Operator   0.11.0    loki-operator.v0.10.2   Succeeded




















[root@bastion ~]# vim manifest/cluster-log-forwarder.yaml













































---------------------------------------------------------------------------------------------------------------------------------------------------------------------

[root@bastion ~]# vim manifest/logforwarder.yaml
apiVersion: observability.openshift.io/v1
kind: ClusterLogForwarder
metadata:
  name: instance
  namespace: openshift-logging
spec:
  serviceAccount:
    name: cluster-logging-operator
  outputs:
    - name: default-loki
      type: lokiStack
      lokiStack:
        authentication:
          token:
            from: serviceAccount
        target:
          name: logging-loki
          namespace: openshift-logging
      tls:
        ca:
          key: service-ca.crt
          configMapName: openshift-service-ca.crt
  pipelines:
    - name: all-to-loki
      inputRefs:
        - application
        - infrastructure
        - audit
      outputRefs:
        - default-loki

[root@bastion ~]# oc apply -f manifest/logforwarder.yaml

Acceder a los logs en la Consola Web de OKD: ve a Observability $\rightarrow$ Logs

```