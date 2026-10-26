#!/usr/bin/env bash
# Prints the current 6-digit TOTP code (the same one Google Authenticator shows).
# Works on Linux and macOS.
#
# Usage:
#   totp       print the code
#   totp -c    print the code and copy it to the clipboard
#
# Requirements:
#   oathtool  (Ubuntu/Debian: sudo apt install oathtool | macOS: brew install oath-toolkit)
#   Only for -c on Linux: wl-clipboard (Wayland) or xclip (X11)
#   Only for -c on macOS: nothing (pbcopy is built in)

# The base32 secret key is read from this file
SECRET_FILE="${TOTP_SECRET_FILE:-$HOME/.totp_secret}"

COPY=0
case "${1:-}" in
  -c) COPY=1 ;;
  "") ;;
  *)
    echo "Usage: $(basename "$0") [-c]" >&2
    exit 1
    ;;
esac

if ! command -v oathtool >/dev/null 2>&1; then
  echo "Error: oathtool is not installed." >&2
  exit 1
fi

if [ ! -r "$SECRET_FILE" ]; then
  echo "Error: cannot read $SECRET_FILE" >&2
  exit 1
fi

# Warn if the file is accessible to other users
PERMS=$(stat -c '%a' "$SECRET_FILE" 2>/dev/null || stat -f '%Lp' "$SECRET_FILE")
if [ "$PERMS" != "600" ] && [ "$PERMS" != "400" ]; then
  echo "Warning: $SECRET_FILE has permissions $PERMS; run: chmod 600 $SECRET_FILE" >&2
fi

# Strip any whitespace or newlines from the key
SECRET=$(tr -d '[:space:]' < "$SECRET_FILE")

CODE=$(oathtool --totp -b "$SECRET") || exit 1
REMAINING=$((30 - $(date +%s) % 30))

echo "$CODE  (valid for ${REMAINING}s more)"

if [ "$COPY" -eq 1 ]; then
  # Pick the clipboard tool: macOS, then Wayland, then X11
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$CODE" | pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$CODE" | wl-copy
  elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
    printf '%s' "$CODE" | xclip -selection clipboard
  else
    echo "Could not copy: install wl-clipboard (Wayland) or xclip (X11)." >&2
    exit 1
  fi
  echo "Copied to clipboard."
fi
