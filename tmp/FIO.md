El File Integrity Operator (FIO) en OpenShift y Kubernetes es un operador enfocado en la seguridad y el cumplimiento normativo (compliance), diseñado para monitorizar continuamente la integridad de los archivos del sistema operativo base (RHCOS/FCOS/SCOS) en los nodos del clúster.

Su funcionalidad es:
* Detección de intrusiones y malware: Identifica si atacantes, procesos no autorizados o binarios maliciosos han modificado archivos críticos del sistema.
* Cumplimiento normativo (Compliance): Satisface requerimientos estrictos de normativas y estándares de seguridad de nuestar empresa
* Control de desviaciones no autorizadas (drift): Advierte si un administrador o proceso externo modificó manualmente configuraciones en los nodos eludiendo el Machine Config Operator (MCO)

la recomendación estándar del File Integrity Operator es crear un recurso FileIntegrity por cada rol o MachineConfigPool (MCP).

apiVersion: fileintegrity.openshift.io/v1alpha1
kind: FileIntegrity
metadata:
  name: control-plane-file-integrity
  namespace: openshift-file-integrity
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  config:
    gracePeriod: 30
    maxBackups: 5
---
apiVersion: fileintegrity.openshift.io/v1alpha1
kind: FileIntegrity
metadata:
  name: infra-file-integrity
  namespace: openshift-file-integrity
spec:
  nodeSelector:
    node-role.kubernetes.io/infra: ""
  tolerations:
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"
  config:
    gracePeriod: 30
    maxBackups: 5
---
apiVersion: fileintegrity.openshift.io/v1alpha1
kind: FileIntegrity
metadata:
  name: worker-file-integrity
  namespace: openshift-file-integrity
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  config:
    gracePeriod: 30
    maxBackups: 5

oc get fileintegritynodestatuses -n openshift-file-integrity
oc get configmaps -n openshift-file-integrity -l file-integrity.openshift.io/node=worker1.ilba.cat


Esto es para que cuando actualize no hayan problemas

oc annotate fileintegrity/worker-file-integrity file-integrity.openshift.io/re-init=