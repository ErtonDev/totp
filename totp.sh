#!/usr/bin/env bash
# Muestra el código TOTP de 6 dígitos (el mismo que Google Authenticator)
# Requisito: oathtool (Debian/Ubuntu: sudo apt install oathtool | macOS: brew install oath-toolkit)

# La clave secreta (base32) se lee de este fichero
SECRET_FILE="${TOTP_SECRET_FILE:-$HOME/.totp_secret}"

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
