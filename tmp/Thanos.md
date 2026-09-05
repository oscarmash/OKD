En una instalación limpia de OKD/OpenShift: por defecto NO hay Downsampling activo.

Como saber la retención de promtheus:

```
[root@bastion ~]# oc get statefulset prometheus-k8s -n openshift-monitoring -o jsonpath='{.spec.template.spec.containers[?(@.name=="prometheus")].args}' | tr ',' '\n' | grep 'storage.tsdb.retention.time'
"--storage.tsdb.retention.time=15d"
```