El catálogo actual (community-operators): Solo indexa los operadores de la comunidad. En ciertas versiones de OKD, la comunidad de Tekton no mantiene publicado un paquete OLM en community-operators. Vamos que que no existe ningún operador de Tekton dentro del catálogo community-operators de OKD :shit:

# Instalación de Tekton

```
[root@bastion ~]# oc get catalogsource -n openshift-marketplace
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     6d20h
```

Por tanto desplegaremos Tekton Operator upstream directamente.

[root@bastion ~]# oc apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml

[root@bastion ~]# oc get pods -n tekton-operator
NAME                                       READY   STATUS    RESTARTS   AGE
tekton-operator-5889466b74-m4dwt           2/2     Running   0          17s
tekton-operator-webhook-5f68fd688b-j7zg5   1/1     Running   0          17s

[root@bastion ~]# vim manifest/tekton_config.yaml
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  targetNamespace: openshift-pipelines
  pipeline:
    params: []
  result:
    disabled: true
  pruner:
    resources:
      - pipelinerun
      - taskrun
    keep: 3
    schedule: "0 8 * * *"

[root@bastion ~]# oc delete tektonconfig config
[root@bastion ~]# oc apply -f manifest/tekton_config.yaml

[root@bastion ~]# oc adm policy add-scc-to-user anyuid -z tekton-pipelines-controller -n openshift-pipelines
[root@bastion ~]# oc adm policy add-scc-to-user anyuid -z tekton-pipelines-webhook -n openshift-pipelines
[root@bastion ~]# oc adm policy add-scc-to-group anyuid system:serviceaccounts:openshift-pipelines
[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:openshift-pipelines
[root@bastion ~]# oc adm policy add-scc-to-group privileged system:serviceaccounts:tekton-operator

[root@bastion ~]# oc delete rs --all -n openshift-pipelines
[root@bastion ~]# oc rollout restart deployment/tekton-operator -n tekton-operator

[root@bastion ~]# oc get pods -n openshift-pipelines
NAME                                                READY   STATUS    RESTARTS   AGE
tekton-chains-controller-7fcf49767-8868h            1/1     Running   0          8s
tekton-events-controller-84ddbdc948-4n28v           1/1     Running   0          68s
tekton-operator-proxy-webhook-6c7dcbddf5-n7r2k      1/1     Running   0          68s
tekton-pipelines-controller-7b85df8565-gqlpg        1/1     Running   0          68s
tekton-pipelines-remote-resolvers-db6db9996-dxv5l   1/1     Running   0          68s
tekton-pipelines-webhook-7d48c76b87-lk2h4           1/1     Running   0          68s
tekton-triggers-controller-5b8b78d66-7nk82          1/1     Running   0          29s
tekton-triggers-core-interceptors-767bfd459-8s467   1/1     Running   0          29s
tekton-triggers-webhook-8579b6f968-kb5pv            1/1     Running   0          29s


[root@bastion ~]# oc get tektonpipeline
NAME       VERSION   READY   REASON
pipeline   v1.3.1    True

[root@bastion ~]# oc get tektontrigger
NAME      VERSION   READY   REASON
trigger   v0.33.0   True

[root@bastion ~]# oc get tektonchain
NAME    VERSION   READY   REASON
chain   v0.25.1   True

[root@bastion ~]# oc get tektonresult
NAME     VERSION   READY   REASON
result   v0.16.0   True

# Verificación de Tekton









































# Flujo de CI/CD en OKD: GitHub + Tekton + Registro Interno + Argo CD

```text
┌─────────────────────────┐
│ GitHub: Repo A (Código) │ ── Push de cambios en el Dockerfile/phpIPAM
└────────────┬────────────┘
             │ (Webhook)
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Tekton (Integración Continua)                      │
│  1. Clona el repositorio A desde GitHub                                 │
│  2. Construye la imagen con Buildah directamente en el clúster          │
│  3. Sube la imagen al registro interno de OKD                           │
│  4. OKD actualiza automáticamente el ImageStream correspondiente        │
│  5. Clona Repo B y actualiza la referencia de versión/tag en el YAML    │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ (Git Commit & Push)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   GitHub: Repo B (Manifiestos GitOps)                   │
│                   (Deployment.yaml con nueva imagen/tag)                │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ (Detecta el commit)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Argo CD (Despliegue Continuo)                    │
│  1. Lee el Repo B y detecta desincronización (OutOfSync)                │
│  2. Aplica los cambios de forma declarativa en el namespace phpipam     │
│  3. Descarga las capas localmente desde el registro interno de OKD      │
│  4. Recrea los pods de phpIPAM con la nueva versión en ejecución        │
└─────────────────────────────────────────────────────────────────────────┘
```