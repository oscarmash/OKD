# Project vs NS

un Project es una capa de abstracción sobre un Namespace estándar de Kubernetes. Cada vez que se crea un Project, OpenShift crea y mapea por debajo un Namespace con el mismo nombre.

Crear directamente un Namespace: Es la práctica estándar para componentes de infraestructura, operadores y middleware del clúster
Crear un Project: Es el enfoque idóneo para aplicaciones de usuarios y desarrolladores

| Característica | **Namespace** (Kubernetes nativo) | **Project** (OpenShift / OKD) |
| :--- | :--- | :--- |
| **API / Origen** | Nativo de Kubernetes (`k8s.io` / `v1`) | Extensión de OpenShift (`project.openshift.io/v1`) |
| **Comando CLI** | `kubectl get namespaces` o `oc get ns` | `oc project` o `oc get projects` |
| **Autoaprovisionamiento y permisos** | Requiere permisos de administrador de clúster para crearse | Los usuarios no administradores pueden crearlo por autoservicio (`oc new-project`) mediante `ProjectRequest` |
| **RBAC automático** | No asigna roles por defecto al creador | Asigna automáticamente el rol de `admin` local al usuario creador |
| **Plantillas automáticas** | No dispara mecanismos de plantillas al crearse | Permite aplicar `ProjectRequestTemplate` que inyecta cuotas (`ResourceQuota`), límites (`LimitRanges`) o `NetworkPolicies` |
| **Metadatos adicionales** | Solo admite etiquetas y anotaciones genéricas | Incorpora campos específicos como `displayName` (nombre legible) y `description` para la consola web |

Los projects se pueden hacer de dos maneras:
* Via consola
* Via GUI

Projects starting with openshift- and kube- are default projects.
OpenShift Container Platform does not allow you to create projects starting with openshift- or kube- using the oc new-project command. Cluster administrators can create these projects using the oc adm new-project command.

## Creación de un proyecto

```
[root@bastion ~]# oc new-project openshift-ilba \
  --display-name="Project Ilba" \
  --description="Entorno de microservicios para Ilba"
Error from server (Forbidden): project.project.openshift.io "openshift-ilba" is forbidden: cannot request a project starting with "openshift-"
```

Existen unos Projectos los cuales tienen un RUN-LEVEL 0 o 1, los cuales tienen un orden superior en el momento de arranque del cluster, ya que son componentes críticos los cuales son los cimientos de Kubernetes.

```
[root@bastion ~]# oc get namespaces -L openshift.io/run-level
```

Cuando creamos un proyecto, se le asigna automáticamente el rol de `admin` local al usuario que ha creado el proyecto. Esto le da las siguientes ventajas al usuario que ha creado el NS:
* Puede crear, modificar y eliminar Deployments, Pods, Services, Routes, ConfigMaps, Secrets, etc...
* Puede crear Pipelines y CI/CD (Tekton)
* Puede revisar eventos, logs de contenedores y depurar errores de sus aplicaciones.

CAPTURA DE CREAR UN PROJECT DESDE LA GUI

```
[root@bastion ~]# oc get rolebinding admin -n test-project-nuria -o yaml
```

## Plantilla base

En OpenShift y OKD, el ProjectRequestTemplate es el mecanismo que permite definir una plantilla (Template) global con la configuración base que debe tener cualquier proyecto nuevo. Cada vez que un usuario crea un proyecto con **oc new-project** o mediante la consola web, el clúster inyecta automáticamente los objetos que tú hayas configurado, que pueden ser los siguientes:

* ResourceQuota
* LimitRange
* NetworkPolicies

## Ejemplo de plantilla base

En este ejemplo, añadiremos los objetos que deseemos, para que cuando se cree un proyecto, se cree con nuestras características personalizadas:

```
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: custom-project-template
  namespace: openshift-config
parameters:
- name: PROJECT_NAME
- name: PROJECT_DISPLAY_NAME
- name: PROJECT_DESCRIPTION
- name: PROJECT_ADMIN_USER
objects:
# 1. Objeto Project raíz (OpenShift genera el Namespace internamente a partir de este)
- apiVersion: project.openshift.io/v1
  kind: Project
  metadata:
    name: ${PROJECT_NAME}
    annotations:
      openshift.io/display-name: ${PROJECT_DISPLAY_NAME}
      openshift.io/description: ${PROJECT_DESCRIPTION}

# 2. RBAC: Rol de Admin para el creador
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: admin
    namespace: ${PROJECT_NAME}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: admin
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: ${PROJECT_ADMIN_USER}

# 3. ResourceQuota: Cuota agregada de CPU, RAM y Pods
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: default-quota
    namespace: ${PROJECT_NAME}
  spec:
    hard:
      requests.cpu: "2"
      requests.memory: 4Gi
      limits.cpu: "4"
      limits.memory: 8Gi
      pods: "10"

# 4. LimitRange: Valores por defecto y topes por contenedor
- apiVersion: v1
  kind: LimitRange
  metadata:
    name: default-limits
    namespace: ${PROJECT_NAME}
  spec:
    limits:
    - type: Container
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 256Mi
      max:
        cpu: "2"
        memory: 2Gi
      min:
        cpu: 50m
        memory: 64Mi

# 5. NetworkPolicy: Tráfico restringido al mismo namespace
- apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-same-namespace
    namespace: ${PROJECT_NAME}
  spec:
    podSelector: {}
    ingress:
    - from:
      - podSelector: {}
```

Registrar la plantilla y activarla globalmente

```
[root@bastion ~]# oc apply -n openshift-config -f manifest/custom-project-template.yaml
```

Configuraremos el recurso global de proyectos para usar la plantilla:

```
oc patch project.config.openshift.io/cluster --type=merge -p '{
  "spec": {
    "projectRequestTemplate": {
      "name": "custom-project-template"
    }
  }
}'
```

```
[root@bastion ~]# oc get template -n openshift-config
NAME                      DESCRIPTION   PARAMETERS    OBJECTS
custom-project-template                 4 (4 blank)   5
```

Cuando se crea un namespace directamente como root o cluster-admin usando comandos estándar como oc create ns test-gobernado, OpenShift/OKD no invoca el motor de ProjectRequestTemplate

Crearemos un nuevo proyecto y verificaremos que 

```
[root@bastion ~]# oc new-project test-gobernado --display-name="Test Gobernado" 
```

```
[root@bastion ~]# oc -n test-gobernado get resourcequota
NAME            REQUEST                                                 LIMIT                                   AGE
default-quota   pods: 0/10, requests.cpu: 0/2, requests.memory: 0/4Gi   limits.cpu: 0/4, limits.memory: 0/8Gi   88s

[root@bastion ~]# oc -n test-gobernado get limitrange
NAME             CREATED AT
default-limits   2026-10-10T15:51:51Z

[root@bastion ~]# oc -n test-gobernado get networkpolicy
NAME                   POD-SELECTOR   AGE
allow-same-namespace   <none>         94s
```

Hecemos limpieza

```
[root@bastion ~]# oc patch project.config.openshift.io/cluster --type=json -p '[{"op": "remove", "path": "/spec/projectRequestTemplate"}]'
[root@bastion ~]# oc patch project.config.openshift.io/cluster --type=merge -p '{"spec":{"projectRequestTemplate":{"name":""}}}'
[root@bastion ~]# oc patch project.config.openshift.io/cluster --type=merge -p '{"spec":{"projectRequestTemplate":null}}'
[root@bastion ~]# oc rollout restart deployment/apiserver -n openshift-apiserver
```