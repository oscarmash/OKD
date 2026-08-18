# Observabilidad

## Métricas (uso de recursos)

En OKD, la pila de observabilidad ya viene instalada por defecto en los namespaces:
* openshift-monitoring
* openshift-user-workload-monitoring

Los dashboards que nos deja el sistema de KPS, estarian en:
Menú lateral $\rightarrow$ Observability / Observabilidad $\rightarrow$ Dashboards
(trae preconfigurados exactamente los mismos dashboards esenciales que vienen en KPS)

## Registros o logs (historial de eventos)

En OKD se usa Cluster Logging (utiliza Loki, mediante el Loki Operator)

## Trazas (seguimiento de peticiones)

xx