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
  namespace: ilba-minio
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

Operador de LokiStack (Loki Operator)

El API de Kubernetes no reconoce la definición del recurso LokiStack porque todavía no se ha instalado el Loki Operator en el clúster. Lo instalamos:
Gestiona el almacenamiento e indexación de logs.

Buscar el operador en los catálogos:

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

Para que en el menú lateral de la consola de OKD vas a Observe -> Logs, y tengas una GUI completa integrada con OKD, hemos de tener lo siguiente:

* Instalar el Cluster Logging Operator y el Loki Operator desde el OperatorHub de la consola de OKD.
* Crear un recurso LokiStack (que gestiona las instancias de Loki de forma nativa en OKD).
* Crear un recurso ClusterLogForwarder: Aquí es donde le dices a OKD que capture los logs de los pods (los de infrastructure y application) y los reenvíe al LokiStack.

Una vez que el ClusterLogForwarder empieza a inyectar logs en Loki, el plugin de la consola de OKD activa la pestaña Observe -> Logs.


# Cluster Logging Operator (que despliega el recolector Vector)

#### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 #### 1 ####

[root@bastion ~]# oc get catalogsources -n openshift-marketplace
NAME               DISPLAY             TYPE   PUBLISHER   AGE
redhat-operators   Red Hat Operators   grpc   Red Hat     26h

[root@bastion ~]# oc get operatorhub cluster -o yaml
...
  - disabled: true
    name: community-operators
    status: Success
  - disabled: true
    name: redhat-marketplace
    status: Success
  - disabled: false
    name: redhat-operators
    status: Success
  - disabled: true
    name: certified-operators
    status: Success
...

oc patch operatorhub cluster --type merge -p '{"spec": {"disableAllDefaultSources": false}}'


oc patch operatorhub cluster --type merge -p '{"spec": {"sources": [{"name": "community-operators", "disabled": false}, {"name": "redhat-operators", "disabled": true}, {"name": "certified-operators", "disabled": true}, {"name": "redhat-marketplace", "disabled": true}]}}'

[root@bastion ~]# oc get operatorhub cluster -o yaml
...
  - disabled: false
    name: community-operators
    status: Success
  - disabled: true
    name: redhat-marketplace
    status: Success
  - disabled: true
    name: redhat-operators
    status: Success
  - disabled: true
    name: certified-operators
    status: Success
...

[root@bastion ~]# oc get catalogsources -n openshift-marketplace
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     6m10s

[root@bastion ~]# oc get pods -n openshift-marketplace
NAME                                    READY   STATUS    RESTARTS   AGE
community-operators-lf4bn               1/1     Running   0          6m23s
marketplace-operator-75b8797c46-7qrm8   1/1     Running   8          6d5h

[root@bastion ~]# oc get packagemanifests -n openshift-marketplace | grep -i logging
logging-operator                            Community Operators   6m43s

[root@bastion ~]# kubectl -n olm get packagemanifest logging-operator -o jsonpath='{.status.channels[*].name}' && echo
beta

[root@bastion ~]# vim manifest/logging-operator-install.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-logging-operatorgroup
  namespace: openshift-logging
spec:
  targetNamespaces:
  - openshift-logging
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: logging-operator
  namespace: openshift-logging
spec:
  channel: "beta"
  name: logging-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Manual

[root@bastion ~]# oc apply -f manifest/logging-operator-install.yaml

[root@bastion ~]# oc get installplan -n openshift-logging
NAME            CSV                       APPROVAL   APPROVED
install-jbrnh   logging-operator.v0.4.0   Manual     false


oc patch installplan install-jbrnh \
  -n openshift-logging \
  --type merge \
  -p '{"spec": {"approved": true}}'


[root@bastion ~]# oc get installplan -n openshift-logging
NAME            CSV                       APPROVAL   APPROVED
install-jbrnh   logging-operator.v0.4.0   Manual     true

[root@bastion ~]# oc get csv -n openshift-logging
NAME                      DISPLAY                   VERSION   REPLACES                  PHASE
logging-operator.v0.4.0   Logging Operator          0.4.0     logging-operator.v0.3.0   Succeeded
loki-operator.v0.11.0     Community Loki Operator   0.11.0    loki-operator.v0.10.2     Succeeded

# Configuración de recolección hacia LokiStack

[root@bastion ~]# vim manifest/collection-LokiStack.yaml
apiVersion: logging.banzaicloud.io/v1beta1
kind: Logging
metadata:
  name: default-logging
  namespace: openshift-logging
spec:
  fluentbit: {}
  controlNamespace: openshift-logging
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterOutput
metadata:
  name: loki-output
  namespace: openshift-logging
spec:
  loki:
    url: "http://logging-loki-gateway.openshift-logging.svc:8080"
    configure_kubernetes_labels: true
---
apiVersion: logging.banzaicloud.io/v1beta1
kind: ClusterFlow
metadata:
  name: all-logs-flow
  namespace: openshift-logging
spec:
  globalOutputRefs:
    - loki-output

Has instalado el operador Logging Operator de Opstree Labs (logging.opstreelabs.in), que es un operador diseñado para desplegar la pila Elasticsearch/Fluentd/Kibana.





#### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 #### 2 ####

Operador nativo de Loki / Vector

[root@bastion ~]# oc patch console.operator.openshift.io cluster --type json -p '[{"op": "add", "path": "/spec/plugins/-", "value": "logging-view-plugin"}]'









Acceder a los logs en la Consola Web de OKD: ve a Observability $\rightarrow$ Logs

```