[root@bastion ~]# vim ~/.bashrc
__oc_ps1() {
  local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
  [ -f "$kubeconfig" ] || return

  local current_context
  current_context=$(grep -m1 '^current-context:' "$kubeconfig" | awk '{print $2}')
  [ -z "$current_context" ] && return

  local ns user
  ns=$(echo "$current_context" | awk -F'/' '{print $1}')
  user=$(echo "$current_context" | awk -F'/' '{print $3}')

  if [ -z "$ns" ] || [ -z "$user" ]; then
    user=$(oc config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null)
    ns=$(oc config view --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null)
  fi

  [ -z "$ns" ] && ns="default"

  # Paleta accesible de alto contraste:
  # - Delimitadores: gris claro (245)
  # - Usuario: rojo brillante / salmón claro (203)
  # - Namespace: azul cielo / cian eléctrico (75)
  local c_reset="\033[0m"
  local c_dim="\033[38;5;245m"
  local c_red="\033[38;5;203m"
  local c_blue="\033[38;5;75m"

  [ -n "$user" ] && echo -e " ${c_dim}(okd:${c_red}${user}${c_dim}|${c_blue}${ns}${c_dim})${c_reset}"
}

PS1='[\u@\h \W]$(__oc_ps1)\n$ '