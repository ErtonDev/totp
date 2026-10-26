# totp

Obtén tu código de 6 dígitos de Google Authenticator desde la terminal, sin mirar el móvil.

Contiene dos scripts:

- `totp.sh`: genera el código TOTP actual con `oathtool`.
- `decode_migration.py`: extrae la clave secreta en base32 a partir del enlace `otpauth-migration://` que se obtiene al exportar cuentas desde Google Authenticator.

> **Aviso de seguridad.** Guardar el segundo factor en el mismo ordenador donde inicias sesión reduce la protección que ofrece el 2FA, porque ya no depende de un dispositivo aparte. Hazlo solo si entiendes y aceptas ese riesgo. Quien tenga tu clave secreta puede generar tus códigos.

## Requisitos

- `oathtool`
  - Debian/Ubuntu: `sudo apt install oathtool`
  - macOS: `brew install oath-toolkit`
- `zbarimg` (para leer el QR desde una imagen)
  - Debian/Ubuntu: `sudo apt install zbar-tools`
  - macOS: `brew install zbar`
- Python 3 (sin dependencias adicionales)

## 1. Obtener la clave secreta

1. En Google Authenticator, usa **Transferir cuentas → Exportar cuentas** y genera el QR.
2. Haz una captura de pantalla y pásala al ordenador.
3. Extrae el enlace del QR:
   ```
   zbarimg captura.png
   ```
   Verás algo como `QR-Code:otpauth-migration://offline?data=...`.
4. Decodifícalo (con el enlace entre comillas simples):
   ```
   python3 decode_migration.py 'otpauth-migration://offline?data=...'
   ```
   Se imprime, por cada cuenta exportada, el emisor, el nombre y la clave en base32.

5. **Limpia los rastros**: borra la captura y el enlace, y quita la línea del historial del shell (`history | tail`, `history -d NÚMERO`, `history -w`). El enlace contiene los secretos de *todas* las cuentas exportadas.

## 2. Guardar la clave en un fichero

Sin que quede en el historial ni en pantalla:

```
umask 077
read -rs -p "Clave: " S && printf '%s\n' "$S" > ~/.totp_secret; unset S; echo
```

El fichero debe tener permisos `600` (`ls -l ~/.totp_secret`).

## 3. Usar el script

```
chmod +x totp.sh
./totp.sh
```

Salida de ejemplo:

```
123456  (válido 17s más)
```

Comprueba que coincide con el código del móvil.

### Ejecutarlo desde cualquier carpeta

```
mkdir -p ~/bin && cp totp.sh ~/bin/totp
```

Si `~/bin` no está en tu `PATH`, añade a `~/.bashrc` (o `~/.zshrc`):

```
export PATH="$HOME/bin:$PATH"
```

y vuelve a abrir la terminal. Después basta con escribir `totp`.

### Otra ubicación para la clave

Por defecto se lee `~/.totp_secret`. Puedes cambiarlo con la variable `TOTP_SECRET_FILE`:

```
TOTP_SECRET_FILE=/ruta/otra totp
```

## Qué hace `totp.sh`

- Comprueba que `oathtool` está instalado y que el fichero de la clave se puede leer.
- Avisa si el fichero no tiene permisos `600` o `400`.
- Ignora espacios y saltos de línea en la clave.
- Muestra el código y los segundos que le quedan.

## Licencia

Uso libre. Si añades una licencia al repositorio, indícala aquí.
