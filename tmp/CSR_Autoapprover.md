Cronjob “CSR Autoapprover”
•
Dado que en una instalación agnóstica no hay proceso de aprobación de CSR automático, se crea un cronjob que valida de forma periódica si hay CSR pendientes de aceptación y los aprueba automáticamente.
•
Creamos un CronJob "ocp4-auto-approve-csr" en el proyecto "openshift-cron-jobs" que cada 15 minutos revise si hay CSR pending y los apruebe.
[root@su1186 ~]# cd post-install/cronjob-csr-autoapprover/
[root@su1186 cronjob-csr-autoapprover]# ls -la
total 20
drwxr-xr-x 2 root root 162 Jun 16 10:26 .
drwxr-xr-x 24 root root 4096 Jun 16 10:26 ..
-rw-r--r-- 1 root root 242 Jun 16 10:26 clusterrolebinding-approver.yaml
-rw-r--r-- 1 root root 1165 Jun 16 10:26 cronjob-auto-approve-csr.yaml
-rw-r--r-- 1 root root 360 Jun 16 10:26 namespace-openshift-cron-jobs.yaml
-rw-r--r-- 1 root root 100 Jun 16 10:26 service-account-approver.yaml
[root@su1186 cronjob-csr-autoapprover]# cat namespace-openshift-cron-jobs.yaml
---
apiVersion: v1
kind: Namespace
metadata:
name: openshift-cron-jobs
annotations:
openshift.io/display-name: OpenShift System CronJobs
labels:
openshift.io/cluster-monitoring: "true"
pod-security.kubernetes.io/audit: privileged
pod-security.kubernetes.io/enforce: privileged
pod-security.kubernetes.io/warn: privileged
Informe Despliegue OCP 4.18 - pág. 64
Información Confidencial
[root@su1186 cronjob-csr-autoapprover]# oc create -f namespace-openshift-cron-jobs.yaml
namespace/openshift-cron-jobs created
[root@su1186 cronjob-csr-autoapprover]# cat service-account-approver.yaml
---
kind: ServiceAccount
apiVersion: v1
metadata:
name: approver
namespace: openshift-cron-jobs
[root@su1186 cronjob-csr-autoapprover]# oc create -f service-account-approver.yaml
serviceaccount/approver created
[root@su1186 cronjob-csr-autoapprover]# cat clusterrolebinding-approver.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
name: system:csr-approver
roleRef:
kind: ClusterRole
name: cluster-admin
subjects:
- kind: ServiceAccount
name: approver
namespace: openshift-cron-jobs
[root@su1186 cronjob-csr-autoapprover]# oc create -f clusterrolebinding-approver.yaml
clusterrolebinding.rbac.authorization.k8s.io/system:csr-approver created
[root@su1186 cronjob-csr-autoapprover]# cat cronjob-auto-approve-csr.yaml
kind: CronJob
apiVersion: batch/v1
metadata:
name: ocp4-auto-approve-csr
namespace: openshift-cron-jobs
spec:
schedule: '*/15 * * * *'
concurrencyPolicy: Forbid
successfulJobsHistoryLimit: 5
failedJobsHistoryLimit: 5
startingDeadlineSeconds: 60
suspend: false
jobTemplate:
spec:
template:
spec:
containers:
- name: cronjob-csr-approver
image: "registry.redhat.io/openshift4/ose-cli:latest"
command:
- "/bin/bash"
- "-c"
- oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve
resources: {}
terminationMessagePath: /dev/termination-log
terminationMessagePolicy: File
imagePullPolicy: IfNotPresent
restartPolicy: OnFailure
terminationGracePeriodSeconds: 30
Informe Despliegue OCP 4.18 - pág. 65
Información Confidencial
dnsPolicy: ClusterFirst
securityContext: {}
schedulerName: default-scheduler
serviceAccountName: "approver"
serviceAccount: "approver"
[root@su1186 cronjob-csr-autoapprover]# oc create -f cronjob-auto-approve-csr.yaml
cronjob.batch/ocp4-auto-approve-csr created
[root@su1186 cronjob-csr-autoapprover]# oc get cj -n openshift-cron-jobs
NAME SCHEDULE TIMEZONE SUSPEND ACTIVE LAST SCHEDULE AGE
ocp4-auto-approve-csr */15 * * * * <none> False 0 <none> 7s
•
Esperamos que se ejecute un job para validar que funciona:
[root@su1186 ~]# oc get jobs -n openshift-cron-jobs
NAME STATUS COMPLETIONS DURATION AGE
ocp4-auto-approve-csr-29167755 Complete 1/1 22s 14m
•
El pod del job se ejecuta sin problemas.
[root@su1186 ~]# oc get pods -n openshift-cron-jobs
NAME READY STATUS RESTARTS AGE
ocp4-auto-approve-csr-29167755-479hm 0/1 Completed 0 14m
[root@su1186 ~]# oc logs -n openshift-cron-jobs ocp4-auto-approve-csr-29167755-479hm
[root@su1186 ~]# oc get csr
NAME AGE SIGNERNAME REQUESTOR REQUESTEDDURATION CONDITION
csr-xpxk7 57m kubernetes.io/kube-apiserver-client system:ovn-node:infra3.ocp1.corpo.ad.diba.es 24h Approved,Issued