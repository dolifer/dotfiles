#!/bin/sh
# k8s context for starship prompt — reads ~/.config/starship-k8s.conf for color/alias mapping
ctx=$(kubectl config current-context 2>/dev/null) || exit 1
ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)

# Color lookup table
color_code() {
  case "$1" in
    red)     echo "31";;
    green)   echo "32";;
    yellow)  echo "33";;
    blue)    echo "34";;
    magenta) echo "35";;
    cyan)    echo "36";;
    white)   echo "37";;
    *)       echo "38;5;$1";;  # 256-color
  esac
}

# Default: blue, no alias
color="34"
label="$ctx"

# Read mapping file
conf="$HOME/.config/starship-k8s.conf"
if [ -f "$conf" ]; then
  while IFS='	' read -r pattern c alias; do
    case "$pattern" in \#*|"") continue;; esac
    if echo "$ctx" | grep -qE "$pattern"; then
      color=$(color_code "$c")
      if [ "$alias" != "-" ]; then label="$alias"; fi
      break
    fi
  done < "$conf"
fi

# Build output
out="\033[1;${color}m${label}\033[0m"
if [ -n "$ns" ] && [ "$ns" != "default" ] && [ "$ns" != "kube-system" ]; then
  out="${out} \033[${color}m(${ns})\033[0m"
fi

printf "☸ %b" "$out"
