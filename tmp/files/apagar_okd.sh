#!/bin/bash
set -e

clear

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m'

PROXMOX_HOST="172.26.0.75"

MASTERS=(
        "master01.ilba.cat"
        "master02.ilba.cat"
        "master03.ilba.cat"
        )

WORKERS=(
        "worker01.ilba.cat"
        "worker02.ilba.cat"
        "worker03.ilba.cat"
        "worker04.ilba.cat"
        )

STORAGE=(
        "storage01.ilba.cat"
        "storage02.ilba.cat"
        "storage03.ilba.cat"
        )

INFRA=(
        "infra01.ilba.cat"
        "infra02.ilba.cat"
        )

ALL_NODES=("${MASTERS[@]}" "${WORKERS[@]}" "${STORAGE[@]}" "${INFRA[@]}")

shutdown_group() {
    local group_name=$1
    shift
    local nodes=("$@")

    echo -e "${CYAN}${BOLD}=== Apagando grupo: ${group_name} ===${NC}"
    for node in "${nodes[@]}"; do
        echo -e "${CYAN}[INFO]${NC} Apagando el nodo ${RED}${node}${NC} vía SSH..."
        ssh -o StrictHostKeyChecking=no core@"$node" "sudo shutdown -h now" || echo -e "${YELLOW}[AVISO]${NC} No se pudo apagar ${node} por SSH, hazlo desde el hipervisor."
        #ssh -o StrictHostKeyChecking=no core@"$node" "hostname -f" || true
    done
    echo
}

shutdown_group "MASTERS" "${MASTERS[@]}"
shutdown_group "WORKERS" "${WORKERS[@]}"
shutdown_group "STORAGE" "${STORAGE[@]}"
shutdown_group "INFRA" "${INFRA[@]}"

echo -e "\n${CYAN}${BOLD}=== Esperando a que se apaguen los equipos ===${NC}"

start_time=$(date +%s)

while true; do
    still_alive=0
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    # Formatear el tiempo transcurrido en minutos y segundos (MM:SS)
    mins=$((elapsed / 60))
    secs=$((elapsed % 60))
    time_formatted=$(printf "%02d:%02d" $mins $secs)

    # Imprimir el contador en la misma línea dinámicamente
    echo -ne "${YELLOW}[CRONÓMETRO]${NC} Tiempo transcurrido: ${BOLD}${time_formatted}${NC} \r"

    for node in "${ALL_NODES[@]}"; do
        # Comprobar si responde al ping (timeout de 1 segundo)
        if ping -c 1 -W 1 "$node" &>/dev/null; then
            still_alive=$((still_alive + 1))
        fi
    done

    # Si ningún nodo responde al ping, salimos del bucle
    if [ $still_alive -eq 0 ]; then
        echo -e "\n\n${CYAN}${BOLD}=== ¡Todos los equipos se han apagado correctamente! ===${NC}"
        echo -e "${CYAN}[INFO]${NC} Tiempo total de apagado: ${BOLD}${time_formatted}${NC}"
        break
    fi

    sleep 1
done

echo -e "\n${CYAN}${BOLD}=== Verificando estado real de las VMs en Proxmox (${PROXMOX_HOST}) ===${NC}"
sleep 10

QM_LIST=$(ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "qm list")

for node in "${ALL_NODES[@]}"; do
    vm_info=$(echo "$QM_LIST" | awk -v name="$node" '$2 == name {print $1, $3}')

    if [ -n "$vm_info" ]; then
        vmid=$(echo "$vm_info" | awk '{print $1}')
        status=$(echo "$vm_info" | awk '{print $2}')

        if [ "$status" == "running" ]; then
            echo -e "${YELLOW}[AVISO]${NC} La VM ${RED}${node}${NC} (VMID: ${BOLD}${vmid}${NC}) sigue en estado '${status}'. Forzando parada (qm stop)..."
            ssh -o StrictHostKeyChecking=no "$PROXMOX_HOST" "qm stop ${vmid}"
            echo -e "${CYAN}[OK]${NC} VMID ${vmid} (${node}) detenida correctamente."
        else
            echo -e "${CYAN}[OK]${NC} La VM ${node} (VMID: ${vmid}) ya está apagada (${status})."
        fi
    else
        echo -e "${YELLOW}[AVISO]${NC} No se encontró ninguna VM llamada ${node} en ${PROXMOX_HOST}."
    fi
done

echo -e "\n${CYAN}${BOLD}=== Apagado de nodos OKD completado ===${NC}"

echo -e "\n${CYAN}${BOLD}=== Ejecutar pasos finales de apagado de infraestructura ===${NC}"

echo -e "${CYAN}[INFO]${NC} Apagar Proxmox: ${YELLOW}ssh host5 -C "shutdown -h now"${NC}"
echo -e "${CYAN}[INFO]${NC} Apagar MikroTik: ${YELLOW}echo "y" | sshpass -p 'C@dinor1988' ssh admin@172.26.0.8 "/system shutdown"${NC}"

echo -e "\n${CYAN}${BOLD}=== Secuencia de apagado total completada ===${NC}"
