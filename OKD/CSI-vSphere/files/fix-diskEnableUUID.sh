#!/bin/bash

for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== Procesando $node ==="
    UUID=$(oc get node $node -o jsonpath='{.status.nodeInfo.systemUUID}')

    if [ -n "$UUID" ]; then
        oc patch node $node -p "{\"spec\":{\"providerID\":\"vsphere://${UUID}\"}}"
        echo "OK: providerID asignado a $node ($UUID)"
    else
        echo "ERROR: No se pudo obtener el systemUUID de $node"
    fi
done