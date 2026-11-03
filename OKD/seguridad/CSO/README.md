# Container Security Operator (CSO)

:warning: Una :shit: de producto :warning:

Para que el CSO genere los objetos ImageManifestVuln, la imagen en ejecución debe provenir de Quay.io. El CSO no analiza imágenes estáticamente ni contiene un motor local de CVEs: actúa únicamente consultando la API de seguridad del registro donde reside la image

Para que el operador genere un objeto ImageManifestVuln, se deben cumplir dos condiciones:
* El registro debe exponer endpoints compatibles con la API de vulnerabilidades de Quay/Clair.
* El repositorio o tag consultado en quay.io debe haber sido escaneado previamente por Clair y tener el reporte de indexación público disponible en la API de Quay

En pocas palabras que un contenedor de [hub.docker.com](https://hub.docker.com/), no funciona.