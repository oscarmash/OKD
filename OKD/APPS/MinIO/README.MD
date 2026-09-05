# Índice

* [Introducción](#introducción)
* [Despliegue de MinIO](#despliegue-de-minio)
* [Configuración del Cliente MinIO (mc) y Creación de Buckets](#configuración-del-cliente-minio-mc-y-creación-de-buckets)

# Introducción

OKD no proporciona de forma nativa un servicio de almacenamiento de objetos S3 "out of the box" como lo hace con el almacenamiento en bloque a través del driver CSI de VMware (csi.vsphere.vmware.com). El driver CSI de vSphere únicamente aprovisiona discos virtuales VMDK (bloques en modo ReadWriteOnce).

# Despliegue de MinIO

```
[root@bastion ~]# oc new-project ilba-minio --description="Servicio S3 para OKD / HomeLab" --display-name="MinIO Object Storage
```

```
[root@bastion ~]# vim manifest/minio-loki.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-loki-pvc
  namespace: ilba-minio
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
  namespace: ilba-minio
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
          value: "lokisecretpassword"
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
  namespace: ilba-minio
spec:
  ports:
  - port: 9000
    targetPort: 9000
  selector:
    app: minio-loki
```


```
[root@bastion ~]# oc apply -f manifest/minio-loki.yaml

[root@bastion ~]# oc -n ilba-minio get pods
NAME                          READY   STATUS    RESTARTS   AGE
minio-loki-6ccd6f9567-sbmxl   1/1     Running   0          14s

[root@bastion ~]# oc -n ilba-minio get pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
minio-loki-pvc   Bound    pvc-263c55f3-9dad-462c-bdb9-a29e6d6037e1   50Gi       RWO            thin-csi       <unset>                 22s
```

# Configuración del Cliente MinIO (mc) y Creación de Buckets

```
curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o /usr/local/bin/mc
```

```
[root@bastion ~]# chmod +x /usr/local/bin/mc
[root@bastion ~]# mc --version
```

```
[root@bastion ~]# oc port-forward svc/minio-loki 9000:9000 -n ilba-minio &
[root@bastion ~]# mc alias set myminio http://127.0.0.1:9000 lokiaccesskey lokisecretpassword
[root@bastion ~]# mc mb myminio/thanos --ignore-existing

[root@bastion ~]# mc ls myminio
Handling connection for 9000
[2026-09-05 12:14:21 CEST]     0B thanos/

[root@bastion ~]# pkill -f "oc port-forward svc/minio-loki"
```