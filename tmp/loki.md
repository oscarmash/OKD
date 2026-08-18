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

[root@bastion ~]# vim manifest/lokistack.yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki
  namespace: openshift-logging
spec:
  size: 1x.extra-small
  storage:
    schemas:
      - version: v13
        effectiveDate: "2026-01-01"
    secret:
      name: loki-s3-credentials
      type: s3
  storageClassName: thin-csi
  managementState: Managed

[root@bastion ~]# oc apply -f manifest/lokistack.yaml


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