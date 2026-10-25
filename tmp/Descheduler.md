Kube Descheduler Operator es una de las piezas más importantes para mantener la salud operativa de un clúster a medio y largo plazo. A diferencia de lo que muchos piensan, Kubernetes no es capaz por sí solo de redistribuir la carga una vez que los pods ya están en marcha. De hecho: el schedule por defecto de Kubernetes (kube-scheduler) nunca moverá un pod aunque el nodo esté al 99% de CPU y el de al lado vacío.


Perfiles del Descheduler:
* TopologyAndDuplicates: Si un Deployment tiene 3 réplicas y 2 cayeron por azar o reinicio en el mismo worker, desaloja las réplicas repetidas para forzar a que cada una esté en un worker diferente.
* SoftTopologyAndDuplicates: Aplica el criterio anterior pero siendo permisivo con reglas de afinidad blanda (preferredDuringScheduling).
* LowNodeUtilization: Compara el porcentaje de requests de CPU, memoria y número de pods entre nodos. Si un nodo supera el umbral alto y otro está por debajo del umbral bajo, expulsa pods del nodo saturado para que migren al infrautilizado.
* AffinityAndTaints: Desaloja pods que estén violando reglas de afinidad de nodos o taints que se hayan añadido después de que el pod ya estuviese corriendo.

Mode: determina si el descheduler tiene permisos para expulsar pods o únicamente auditar:
* Predictive (Valor por defecto): modo simulación (dry-run). Evalúa las condiciones, calcula qué pods violan los perfiles y genera eventos y trazas de log, pero no desaloja nada.
* Automatic: para expulsar pods que incumplan las reglas, forzando a que el ReplicaSet los recree en otro worker.

deschedulingIntervalSeconds: intervalo de tiempo en segundos entre cada ronda de análisis y rebalanceo del clúster.
* Valor por defecto: 3600 (1 hora)
* Tipo: Entero positivo (integer)
* No se aconseja fijar valores inferiores a 120 segundos para dar tiempo a que los pods expulsados arranquen y alcancen estado Ready antes de la siguiente evaluación.

profileCustomizations
* devLowNodeUtilizationThresholds: Controla los porcentajes de saturación e infrautilización para la estrategia
  * Low: Umbral bajo = 10% / Umbral alto = 30% (muy agresivo)
  * Medium (por defecto en el operador si se habilita): Umbral bajo = 20% / Umbral alto = 50%
  * High: Umbral bajo = 40% / Umbral alto = 70%. (más conservador)
* namespaces: permite aislar namespaces para que el Descheduler no toque sus cargas.

evictionLimits: evita tormentas de desalojos si se añade un nodo nuevo o se drena uno grande
* node: máximo número de pods a desalojar simultáneamente por nodo
* total: máximo número total de desalojos en todo el clúster por ciclo

# descheduler.yaml
apiVersion: operator.openshift.io/v1
kind: KubeDescheduler
metadata:
  name: cluster
  namespace: openshift-kube-descheduler-operator
spec:
  deschedulingIntervalSeconds: 1800 # 30 minutos
  logLevel: Normal
  operatorLogLevel: Normal
  profiles:
    - TopologyAndDuplicates
    - SoftTopologyAndDuplicates
    - LowNodeUtilization
    - AffinityAndTaints
  profileCustomizations:
    devLowNodeUtilizationThresholds: "Medium"
    namespaces:
        excluded:
        - mi-base-de-datos-critica
        - kafka-cluster
  mode: Automatic
  evictionLimits:
    node: 2
    total: 5

El Descheduler no debe activarse _a ciegas_ sin revisar estos aspectos:

* Definir bien requests y limits: La estrategia LowNodeUtilization evalúa la ocupación del nodo basándose en las peticiones (requests) garantizadas de CPU y memoria, no solo en el consumo puntual instantáneo. Si tus pods no tienen requests configurados, el descheduler no sabrá con precisión qué nodo está realmente comprometido.
* Uso de PodDisruptionBudgets (PDB): El Descheduler respeta de forma estricta los PDBs. Si una aplicación tiene minAvailable: 1 sobre 2 réplicas, solo desalojará una réplica a la vez. Si una aplicación crítica tiene 1 sola réplica sin PDB, el descheduler podría tirarla
* Pods que NUNCA toca por seguridad:
  * Pods críticos del sistema (clase system-node-critical o system-cluster-critical).
  * Pods gestionados por un DaemonSet (ya que deben correr obligatoriamente en cada nodo).
  * Pods con volúmenes locales huérfanos que perderían datos de forma irreversible.
  * Pods que no pertenezcan a un controlador (pods standalone que no se recrearían).