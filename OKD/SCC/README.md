# SCC (Security Context Constraints)

Los SCC (Security Context Constraints) son el "cortafuegos" de permisos que decide qué puede hacer y qué no puede hacer un contenedor dentro del sistema operativo del nodo.

En un Kubernetes tradicional, por defecto un contenedor puede:
* Intentar ejecutarse como root
* Usar puertos privilegiados
* Acceder al hardware del host si el manifiesto lo pide.

En OpenShift y OKD esto está terminantemente prohibido por defecto, y los SCC son las directivas encargadas de imponer esas reglas.

La analogía fácil:
* El Pod / Contenedor es la persona que quiere entrar.
* La ServiceAccount (cuenta de servicio) es su tarjeta de identificación.
* El SCC es el nivel de autorización grabado en la tarjeta.

OKD viene con varios SCC predefinidos

| SCC | ¿Qué permite? | Caso típico |
| :--- | :--- | :--- |
| **`restricted-v2`** *(por defecto)* | Máxima seguridad. Prohíbe root, prohíbe UIDs fijos, exige perfiles seguros y retira casi todas las capacidades del kernel. | Aplicaciones estándar bien diseñadas para la nube. |
| **`anyuid`** | Permite que el contenedor se ejecute con cualquier UID de usuario que tenga su imagen (incluso root o UIDs fijos como 999), pero sin darle privilegios del host. | Bases de datos oficiales (MySQL, PostgreSQL, MariaDB, Redis) que exigen un usuario fijo del sistema. |
| **`privileged`** | Permiso total. Quita todas las restricciones de seguridad. Permite ser root, manipular el kernel, usar sockets crudos y saltarse validaciones. | Operadores del sistema, utilidades de red profunda (hacer ping), agentes de monitorización o almacenamiento. |

A los contenedores no se les asigna el SCC a mano; el SCC se asigna a la ServiceAccount (cuenta de servicio) que ejecuta esos contenedores.

# Ejemplos

> El flag -z es una abreviación de --serviceaccount

Dar permiso a un pod específico (su ServiceAccount):

```
oc adm policy add-scc-to-user anyuid -z default -n mi-namespace
```

Dar permiso a todas las ServiceAccounts del namespace de golpe

```
oc adm policy add-scc-to-group anyuid system:serviceaccounts:mi-namespace
```