# Configuración de nodos mediante MachineConfig (MCO)

El Machine Config Operator no es un proceso único, sino una orquesta de controladores:
* MCO (Operador principal): Vigila los manifiestos MachineConfig que aplicas.
* Machine Config Controller (MCC): Toma todos los MachineConfig que coinciden con un rol (worker, master, infra) y los compila en un único fichero "monolítico" renderizado llamado rendered-worker-<hash>.
* Machine Config Daemon (MCD): Un DaemonSet que corre en cada nodo físico. El MCD vigila si su nodo tiene el último rendered asignado

Estos dos sistemas operativos fueron una fusión de CoreOS y Project Atomic de RedHat. De estos dos se decidió combinar lo mejor de ambos mundos: la filosofía de arranque y aprovisionamiento de Container Linux (Ignition) y el sistema de ficheros basado en commits de Red Hat (rpm-ostree). De esa unión nacieron:
* RHCOS (para OpenShift)
* FCOS (Fedora CoreOS)
* SCOS (CentOS Stream CoreOS PARA okd)

A diferencia de una distribución tradicional como RHEL, CentOS o Ubuntu, RHCOS/SCOS no está pensado para ser gestionado de forma individual por un administrador de sistemas mediante SSH, sino para ser un componente más controlado automáticamente por OpenShift/OKD

Tener en cuenta que el sistema operativo es un sistema de archivos de solo lectura (/usr está montado como read-only)

* /usr en solo lectura (read-only): Todos los binarios, librerías y componentes del sistema operativo residen en /usr.
* Inspirado en Git (rpm-ostree): RHCOS/SCOS utiliza una tecnología llamada ostree (a menudo descrita como "Git para el sistema operativo"). Las actualizaciones del SO no se realizan actualizando paquetes individualmente (dnf update), sino descargando una nueva imagen completa de sistema operativo (un "commit" de la imagen) y conmutando hacia ella mediante un reinicio del nodo.
* El arranque y la instalación lo lleva un componente llamado: ignition
* No hay dnf ni yum habilitados por defecto (no puedes hacer un "dnf install nginx")
* No hay servicios locales extra: No debes habilitar servicios nativos (como Apache, MySQL, etc.) directamente en el SO. Todo lo que ejecutes debe ir dentro de Pod/Contenedores gestionados por Kubernetes/OKD
