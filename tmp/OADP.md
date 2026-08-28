OADP (OpenShift API for Data Protection) es el operador oficial recomendado para realizar copias de seguridad y restauraciones en OKD (y en Red Hat OpenShift).

# Almacenamiento MinIO

```
[root@bastion ~]# vim manifest/01-minio-namespace-pvc.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: minio-dev
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: minio-dev
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi

[root@bastion ~]# vim manifest/02-minio-deployment.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-creds
  namespace: minio-dev
type: Opaque
stringData:
  rootUser: "minioadmin"
  rootPassword: "minioadminpassword123" # Usa una contraseña segura
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-creds
              key: rootUser
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-creds
              key: rootPassword
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: minio-pvc

[root@bastion ~]# vim manifest/03-minio-services-routes.yaml
apiVersion: v1
kind: Service
metadata:
  name: minio-service
  namespace: minio-dev
spec:
  ports:
  - port: 9000
    targetPort: 9000
    name: api
  - port: 9001
    targetPort: 9001
    name: console
  selector:
    app: minio
---
# Ruta para acceder a la Consola Web de MinIO
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  namespace: minio-dev
spec:
  to:
    kind: Service
    name: minio-service
  port:
    targetPort: console
  tls:
    termination: edge
---
# Ruta para el Endpoint S3 (API) de MinIO
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-api
  namespace: minio-dev
spec:
  to:
    kind: Service
    name: minio-service
  port:
    targetPort: api
  tls:
    termination: edge

[root@bastion ~]# oc apply -f manifest/01-minio-namespace-pvc.yaml
[root@bastion ~]# oc apply -f manifest/02-minio-deployment.yaml
[root@bastion ~]# oc apply -f manifest/03-minio-services-routes.yaml
```

```
curl -L https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

[root@bastion ~]# chmod +x $HOME/minio-binaries/mc
[root@bastion ~]# export PATH=$PATH:$HOME/minio-binaries

[root@bastion ~]# MINIO_API_URL=$(oc get route minio-api -n minio-dev -o jsonpath='{.spec.host}')
[root@bastion ~]# echo "La URL de la API es: https://$MINIO_API_URL"
La URL de la API es: https://minio-api-minio-dev.apps.okd.ilba.cat

[root@bastion ~]# $HOME/minio-binaries/mc alias set okd-minio https://$MINIO_API_URL minioadmin minioadminpassword123 --insecure
[root@bastion ~]# $HOME/minio-binaries/mc mb okd-minio/oadp-backups --insecure

[root@bastion ~]# $HOME/minio-binaries/mc ls okd-minio --insecure
[2026-08-28 09:47:30 CEST]     0B oadp-backups/
```

# Velero setup

```
[root@bastion ~]# oc create ns openshift-adp

cat <<EOF > credentials-velero
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=minioadminpassword123
EOF

oc create secret generic cloud-credentials \
  --namespace=openshift-adp \
  --from-file=cloud=credentials-velero

[root@bastion ~]# kubectl get packagemanifest  | grep oadp
oadp-operator                               Community Operators   3d19h

[root@bastion ~]# kubectl -n olm get packagemanifest oadp-operator -o jsonpath='{.status.channels[*].name}' && echo
beta stable
```

```
[root@bastion ~]# vim manifest/01-oadp-subscription.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-adp-operatorgroup
  namespace: openshift-adp
spec:
  targetNamespaces:
  - openshift-adp
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: oadp-operator
  namespace: openshift-adp
spec:
  channel: stable
  name: oadp-operator
  source: community-operators
  sourceNamespace: openshift-marketplace

[root@bastion ~]# oc apply -f manifest/01-oadp-subscription.yaml

[root@bastion ~]# oc get pods -n openshift-adp
NAME                                                READY   STATUS    RESTARTS   AGE
openshift-adp-controller-manager-5f67cd48fc-22s6b   1/1     Running   0          24s
```

```
[root@bastion ~]# vim manifest/02-oadp-dpa.yaml
apiVersion: oadp.openshift.io/v1alpha1
kind: DataProtectionApplication
metadata:
  name: oadp-minio-dpa
  namespace: openshift-adp
spec:
  configuration:
    velero:
      defaultPlugins:
        - aws
        - openshift
    nodeAgent:
      enable: true
      uploaderType: kopia
  backupLocations:
    - velero:
        provider: aws
        default: true
        objectStorage:
          bucket: oadp-backups
          prefix: velero
        config:
          profile: "default"
          region: us-east-1
          s3Url: https://minio-api-minio-dev.apps.okd.ilba.cat
          s3ForcePathStyle: "true"
          insecureSkipTLSVerify: "true"
        credential:
          name: cloud-credentials
          key: cloud

[root@bastion ~]# oc apply -f manifest/02-oadp-dpa.yaml

[root@bastion ~]# oc get backupstoragelocation -n openshift-adp
NAME               PHASE       LAST VALIDATED   AGE   DEFAULT
oadp-minio-dpa-1   Available   10s              12m   true
```

# Velero testing

```
cat <<EOF | oc apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: poc-test-backup
  namespace: openshift-adp
spec:
  includedNamespaces:
  - minio-dev
  storageLocation: oadp-minio-dpa-1
EOF


[root@bastion ~]# oc get backup poc-test-backup -n openshift-adp -o jsonpath='{.status.phase}' && echo
Failed
```

```
$HOME/minio-binaries/mc ls okd-minio/oadp-backups/velero/backups/ --insecure
$HOME/minio-binaries/mc ls okd-minio/oadp-backups/velero/backups/poc-test-backup/ --insecure
```