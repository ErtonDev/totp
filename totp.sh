#!/usr/bin/env bash
# Muestra el código TOTP de 6 dígitos (el mismo que Google Authenticator).
# Funciona en Linux y macOS.
#
# Uso:
#   totp       muestra el código
#   totp -c    muestra el código y lo copia al portapapeles
#
# Requisitos:
#   oathtool  (Ubuntu/Debian: sudo apt install oathtool | macOS: brew install oath-toolkit)
#   Solo para -c en Linux: wl-clipboard (Wayland) o xclip (X11)
#   Solo para -c en macOS: nada (pbcopy viene incluido)

# La clave secreta (base32) se lee de este fichero
SECRET_FILE="${TOTP_SECRET_FILE:-$HOME/.totp_secret}"

COPY=0
case "${1:-}" in
  -c) COPY=1 ;;
  "") ;;
  *)
    echo "Uso: $(basename "$0") [-c]" >&2
    exit 1
    ;;
esac

if ! command -v oathtool >/dev/null 2>&1; then
  echo "Error: oathtool no está instalado." >&2
  exit 1
fi

if [ ! -r "$SECRET_FILE" ]; then
  echo "Error: no se puede leer $SECRET_FILE" >&2
  exit 1
fi

# Avisa si el fichero es accesible por otros usuarios
PERMS=$(stat -c '%a' "$SECRET_FILE" 2>/dev/null || stat -f '%Lp' "$SECRET_FILE")
if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
  echo "Aviso: $SECRET_FILE tiene permisos $PERMS; ejecuta: chmod 600 $SECRET_FILE" >&2
fi

SECRET=$(tr -d '[:space:]' < "$SECRET_FILE")

CODE=$(oathtool --totp -b "$SECRET") || exit 1
REMAINING=$((30 - $(date +%s) % 30))

echo "$CODE  (válido ${REMAINING}s más)"

if [ "$COPY" -eq 1 ]; then
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$CODE" | pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$CODE" | wl-copy
  elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
    printf '%s' "$CODE" | xclip -selection clipboard
  else
    echo "No se pudo copiar: instala wl-clipboard (Wayland) o xclip (X11)." >&2
    exit 1
  fi
  echo "Copiado al portapapeles."
fi
