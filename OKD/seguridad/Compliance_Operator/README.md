# Compliance Operator

El Compliance Operator es un operador oficial de Red Hat OpenShift / OKD diseñado para: automatizar la evaluación, monitorización y remediación del cumplimiento normativo y de seguridad del clúster.

Vamos sería el típoco hardering que haríamos on un Kubernetes vanilla, pero en un clúster de Kubernetes vanilla (desplegado con kubeadm, KubeSpray o RKE), el hardening tradicional suele implicar:
* Ejecutar herramientas de auditoría externa como kube-bench contra el clúster.
* Leer el informe PDF o de terminal con los incumplimientos de la guía CIS Kubernetes Benchmark.
* Ir máquina por máquina por SSH o via Ansible, editando archivos de flags, cambiando permisos, ajustando parámetros del kernel, endureciendo políticas, etc...
* Cruzar los dedos para que nadie toque nada y repetir la auditoría periódicamente a mano.


# Instalación del operador vía OLM.

```
[root@bastion ~]# oc get packagemanifest -n openshift-marketplace | grep -i compliance
compliance-operator                              Red Hat Operators     7h29m
```

```
[root@bastion ~]# vim infra/manifest/install-compliance-operator.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-compliance
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: compliance-operatorgroup
  namespace: openshift-compliance
spec:
  targetNamespaces:
  - openshift-compliance
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: compliance-operator
  namespace: openshift-compliance
spec:
  channel: stable
  installPlanApproval: Automatic
  name: compliance-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

```
[root@bastion ~]# oc apply -f infra/manifest/install-compliance-operator.yaml

[root@bastion ~]# oc get csv -n openshift-compliance
NAME                          DISPLAY               VERSION   RELEASE   REPLACES                     PHASE
compliance-operator.v1.10.0   Compliance Operator   1.10.0              compliance-operator.v1.9.2   Succeeded

[root@bastion ~]# oc get pods -n openshift-compliance
NAME                                             READY   STATUS    RESTARTS      AGE
compliance-operator-85b66575f6-stxbx             1/1     Running   1 (75s ago)   86s
ocp4-openshift-compliance-pp-7d58496658-mz674    1/1     Running   0             70s
rhcos4-openshift-compliance-pp-fb497964b-72w6f   1/1     Running   0             70s
```

# Revisión del "Antes"

```
[root@bastion ~]# ssh core@worker4.ilba.cat
=== Nodo gestionado por Machine Config Operator ===
Last login: Sat Oct 31 11:42:15 2026 from 10.26.0.5

[core@worker4 ~]$ ls -la /etc/issue
-rw-r--r--. 1 root root 20 Oct 25 11:28 /etc/issue

[core@worker4 ~]$ sudo chmod 0666 /etc/issue

[core@worker4 ~]$ ls -la /etc/issue
-rw-rw-rw-. 1 root root 20 Oct 25 11:28 /etc/issue

[core@worker4 ~]$ exit
```

# Lanzamiento de un escaneo

Definiremos un ScanSetting que audite exclusivamente el rol worker, pero con autoApplyRemediations: false para poder auditar el hallazgo antes de que se corrija automáticamente.

Lanzaremos dos tipos de perfiles totalmente diferencidos para escanear nuestros equipos:
* ocp4-cis-nod: audita el motor de Kubernetes y del runtime de contenedores en el nodo
  * Kubelet
  * Archivos y permisos de red/CRI
  * Reglas iptables
  * etc...
* rhcos4-moderate: el sistema operativo host (RHCOS / SCOS) de forma integral, independientemente de que corra Kubernetes encima:
  * Kernel y módulos del Kernel
  * Parámetros Sysctl
  * etc..

```
[root@bastion ~]# vim infra/manifest/compliance-scan-workers.yaml
apiVersion: compliance.openshift.io/v1alpha1
kind: ScanSetting
metadata:
  name: manual-scansetting
  namespace: openshift-compliance
rawResultStorage:
  size: "1Gi"
  rotation: 3
roles:
  - worker
scanTolerations:
  - operator: Exists
autoApplyRemediations: false
---
apiVersion: compliance.openshift.io/v1alpha1
kind: ScanSettingBinding
metadata:
  name: cis-workers-binding
  namespace: openshift-compliance
profiles:
  - name: ocp4-cis-node
    kind: Profile
    apiGroup: compliance.openshift.io/v1alpha1
  - name: rhcos4-moderate
    kind: Profile
    apiGroup: compliance.openshift.io/v1alpha1
settingsRef:
  name: manual-scansetting
  kind: ScanSetting
  apiGroup: compliance.openshift.io/v1alpha1
```

```
[root@bastion ~]# oc apply -f infra/manifest/compliance-scan-workers.yaml
```

```
[root@bastion ~]# oc get pods -n openshift-compliance
NAME                                             READY   STATUS    RESTARTS      AGE
compliance-operator-85b66575f6-stxbx             1/1     Running   5 (22m ago)   16h
ocp4-openshift-compliance-pp-7d58496658-mz674    1/1     Running   1             16h
rhcos4-openshift-compliance-pp-fb497964b-72w6f   1/1     Running   1             16h
```

# Inspección del hallazgo (FAIL) y de la remediación sugerida (ComplianceRemediation)

El escaneo se ha completado con éxito (PHASE: DONE) en los workers y ha encontrado un incumplimiento respecto al benchmark CIS, el resultado global marca NON-COMPLIANT.

```
[root@bastion ~]# oc get compliancesuites,compliancescans -n openshift-compliance
NAME                                                          PHASE   RESULT
compliancesuite.compliance.openshift.io/cis-workers-binding   DONE    NON-COMPLIANT

NAME                                                            PHASE   RESULT
compliancescan.compliance.openshift.io/ocp4-cis-node-worker     DONE    NON-COMPLIANT
compliancescan.compliance.openshift.io/rhcos4-moderate-worker   DONE    NON-COMPLIANT
```

Al lanzar el siguiente comando, no nos asustemos de la cantidad de FAILs que hay. Hemos de pensar que estos S.O. por defecto son de propósito general. Se compilan y entregan con una configuración pensada para compatibilidad, facilidad de uso y rendimiento general, no con el nivel de restricción paranoico que exige una auditoría.


```
[root@bastion ~]# oc get compliancecheckresults -n openshift-compliance | grep -i "FAIL"
rhcos4-moderate-worker-audit-rules-dac-modification-chmod                                           FAIL     medium
rhcos4-moderate-worker-audit-rules-dac-modification-chown                                           FAIL     medium
rhcos4-moderate-worker-audit-rules-dac-modification-fchmod                                          FAIL     medium
rhcos4-moderate-worker-audit-rules-dac-modification-fchmodat                                        FAIL     medium
...
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-ra                                       FAIL     medium
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-redirects                                FAIL     medium
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-source-route                             FAIL     medium
rhcos4-moderate-worker-usbguard-allow-hid-and-hub                                                   FAIL     medium
```

Si queremos ver las remediaciones:

```
[root@bastion ~]# oc get complianceremediations -n openshift-compliance
NAME                                                                                                STATE
rhcos4-moderate-worker-audit-rules-dac-modification-chmod                                           NotApplied
rhcos4-moderate-worker-audit-rules-dac-modification-chown                                           NotApplied
rhcos4-moderate-worker-audit-rules-dac-modification-fchmod                                          NotApplied
rhcos4-moderate-worker-audit-rules-dac-modification-fchmodat                                        NotApplied
...
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-ra                                       NotApplied
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-redirects                                NotApplied
rhcos4-moderate-worker-sysctl-net-ipv6-conf-default-accept-source-route                             NotApplied
rhcos4-moderate-worker-usbguard-allow-hid-and-hub                                                   NotApplied
```

```
[root@bastion ~]# oc describe compliancecheckresult ocp4-cis-node-worker-file-permissions-cni-conf -n openshift-compliance
Name:         ocp4-cis-node-worker-file-permissions-cni-conf
Namespace:    openshift-compliance
Labels:       compliance.openshift.io/check-severity=medium
              compliance.openshift.io/check-status=FAIL
              compliance.openshift.io/profile-guid=fea955f1-9f13-56fd-aacf-868b95b7283f
              compliance.openshift.io/scan-name=ocp4-cis-node-worker
              compliance.openshift.io/suite=cis-workers-binding
Annotations:  compliance.openshift.io/last-scanned-timestamp: 2026-10-31T15:44:50Z
              compliance.openshift.io/rule: file-permissions-cni-conf
              control.compliance.openshift.io/CIS-OCP: 1.1.9;1.1;1
              control.compliance.openshift.io/NERC-CIP: CIP-003-8 R6;CIP-004-6 R3;CIP-007-3 R6.1
              control.compliance.openshift.io/NIST-800-53: CM-6;CM-6(1)
              control.compliance.openshift.io/PCI-DSS-4-0: 2.2.1;2.2
              control.compliance.openshift.io/SRG: SRG-APP-000516-CTR-001325
              policies.open-cluster-management.io/controls:
                CIP-003-8 R6,CIP-004-6 R3,CIP-007-3 R6.1,CM-6,CM-6(1),SRG-APP-000516-CTR-001325,1.1.9,1.1,1,2.2.1,2.2
              policies.open-cluster-management.io/standards: NERC-CIP,NIST-800-53,SRG,CIS-OCP,PCI-DSS-4-0
API Version:  compliance.openshift.io/v1alpha1
Description:  Verify Permissions on the OpenShift Container Network Interface Files
To properly set the permissions of /etc/cni/net.d/* , run the command:

$ sudo chmod 0600 /etc/cni/net.d/*

This also covers CNI configuration files under /etc/kubernetes/cni/net.d/ , which is the CRI-O network configuration directory ( network_dir ) used by OpenShift; on newer releases /etc/cni/net.d/ may be absent and the active configuration lives only under /etc/kubernetes/cni/net.d/.
Id:            xccdf_org.ssgproject.content_rule_file_permissions_cni_conf
Instructions:  To check the permissions of /etc/cni/net.d/*,
you'll need to log into a node in the cluster.
As a user with administrator privileges, log into a node in the relevant pool:

$ oc debug node/$NODE_NAME

At the sh-4.4# prompt, run:

# chroot /host


Then,run the command:
$ ls -l /etc/cni/net.d/*
If properly configured, the output should indicate the following permissions:
-rw-------
Is it the case that /etc/cni/net.d/* does not have unix mode -rw-------?
Kind:  ComplianceCheckResult
Metadata:
  Creation Timestamp:  2026-10-31T15:45:56Z
  Generation:          1
  Owner References:
    API Version:           compliance.openshift.io/v1alpha1
    Block Owner Deletion:  true
    Controller:            true
    Kind:                  ComplianceScan
    Name:                  ocp4-cis-node-worker
    UID:                   a5bdcc24-a3f1-4945-a663-e885db753dc0
  Resource Version:        475810
  UID:                     8e9a9faf-64f5-46eb-b836-d45b808f6599
Rationale:                 CNI (Container Network Interface) files consist of a specification and libraries for writing plugins to configure network interfaces in Linux containers, along with a number of supported plugins. Allowing writeable access to the files could allow an attacker to modify the networking configuration potentially adding a rogue network connection.
Severity:                  medium
Status:                    FAIL
Events:                    <none>
```

# Aplicación de la remediación y validación del "Después"

Forzamos el re-escaneo:

```
[root@bastion ~]# oc annotate compliancesuite cis-workers-binding compliance.openshift.io/rescan= -n openshift-compliance --overwrite
```

Podemos ver las "recetas" que se pueden aplicar en el cluster:

```
[root@bastion ~]# oc get complianceremediations -n openshift-compliance | wc -l
188
```

Pero hay más 193 reglas que requieren arreglarse:

```
[root@bastion ~]# oc get compliancecheckresults -n openshift-compliance | grep -i "FAIL" | wc -l
193
```

Aplicamos TODAS las remediaciones automáticas de golpe:

```
[root@bastion ~]# oc patch scansetting manual-scansetting -n openshift-compliance --type merge -p '{"autoApplyRemediations":true}'
```

Una vez lanzado el comando, empezará el Drain de los nodos secuencialmente, para aplicar las remediaciones:

```
[root@bastion ~]# oc get nodes
NAME               STATUS                     ROLES                  AGE     VERSION
master1.ilba.cat   Ready                      control-plane,master   8d      v1.35.5
master2.ilba.cat   Ready                      control-plane,master   8d      v1.35.5
master3.ilba.cat   Ready                      control-plane,master   8d      v1.35.5
worker1.ilba.cat   Ready,SchedulingDisabled   infra                  8d      v1.35.5
worker2.ilba.cat   Ready                      infra                  8d      v1.35.5
worker3.ilba.cat   Ready,SchedulingDisabled   worker                 8d      v1.35.5
worker4.ilba.cat   Ready                      worker                 8d      v1.35.5
worker5.ilba.cat   Ready                      worker                 3d13h   v1.35.5
worker6.ilba.cat   Ready                      worker                 3d13h   v1.35.5
```

Una vez acabado, lanzaremos el reescaneo, para no haver de esperar:

```
[root@bastion ~]# oc annotate compliancescan rhcos4-moderate-worker compliance.openshift.io/rescan=$(date +%s) -n openshift-compliance --overwrite
[root@bastion ~]# oc annotate compliancescan ocp4-cis-node-worker compliance.openshift.io/rescan=$(date +%s) -n openshift-compliance --overwrite

[root@bastion ~]# oc get pods -n openshift-compliance
NAME                                             READY   STATUS    RESTARTS      AGE
compliance-operator-85b66575f6-stxbx             1/1     Running   5 (78m ago)   17h
ocp4-cis-node-worker-rs-67b99dfcb6-rd4l4         1/1     Running   0             21s
ocp4-cis-node-worker-worker3.ilba.cat-pod        2/2     Running   0             20s
ocp4-cis-node-worker-worker4.ilba.cat-pod        2/2     Running   0             20s
ocp4-cis-node-worker-worker5.ilba.cat-pod        2/2     Running   0             20s
ocp4-cis-node-worker-worker6.ilba.cat-pod        2/2     Running   0             20s
ocp4-openshift-compliance-pp-7d58496658-mz674    1/1     Running   1             17h
rhcos4-moderate-worker-rs-667b5d6884-fx6zv       1/1     Running   0             25s
rhcos4-moderate-worker-worker3.ilba.cat-pod      2/2     Running   0             25s
rhcos4-moderate-worker-worker4.ilba.cat-pod      2/2     Running   0             25s
rhcos4-moderate-worker-worker5.ilba.cat-pod      2/2     Running   0             25s
rhcos4-moderate-worker-worker6.ilba.cat-pod      2/2     Running   0             25s
rhcos4-openshift-compliance-pp-fb497964b-72w6f   1/1     Running   1             17h
```

Pasado un rato veremos que el escaneo ha acabado y podremos ver que hemos pasado de 193 a 6. Las 6 que siguen en FAIL corresponden a reglas que requieren arquitectura física o cambios manuales que el operador no puede deducir (como esquemas de particionado en discos, configuraciones específicas de hardware o políticas organizativas)

```
[root@bastion ~]# oc get compliancecheckresults -n openshift-compliance | grep -w "FAIL" | wc -l
6

[root@bastion ~]# oc get compliancecheckresults -n openshift-compliance | grep -w "FAIL"
ocp4-cis-node-worker-file-permissions-cni-conf                                                      FAIL     medium
rhcos4-moderate-worker-enable-fips-mode                                                             FAIL     high
rhcos4-moderate-worker-package-usbguard-installed                                                   FAIL     medium
rhcos4-moderate-worker-service-usbguard-enabled                                                     FAIL     medium
rhcos4-moderate-worker-sshd-limit-user-access                                                       FAIL     unknown
rhcos4-moderate-worker-usbguard-allow-hid-and-hub                                                   FAIL     medium
```

Como podemos observar, tenemos la regla _ocp4-cis-node-worker-file-permissions-cni-conf_ que es la que hemos modificado los permisos del fichero: _/etc/issue_. El operador no la ha podido arreglar de forma automática porque no dispone de una receta (ComplianceRemediation) para ella. Así que se trendrá que arreglar a mano igual que las otras reglas.
