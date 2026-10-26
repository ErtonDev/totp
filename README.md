# totp

Obtén tu código de 6 dígitos de Google Authenticator desde la terminal, sin mirar el móvil.

Contiene dos scripts:

- `totp.sh`: genera el código TOTP actual con `oathtool` y, opcionalmente, lo copia al portapapeles (`-c`). Es el mismo script para Linux y macOS.
- `decode_migration.py`: extrae la clave secreta en base32 a partir del enlace `otpauth-migration://` que se obtiene al exportar cuentas desde Google Authenticator.

> **Aviso de seguridad.** Guardar el segundo factor en el mismo ordenador donde inicias sesión reduce la protección que ofrece el 2FA, porque ya no depende de un dispositivo aparte. Hazlo solo si entiendes y aceptas ese riesgo. Quien tenga tu clave secreta puede generar tus códigos.

## Requisitos

El código es el mismo en ambos sistemas; solo cambia cómo se instalan las herramientas.

| Herramienta | Para qué | Ubuntu / Debian | macOS (Homebrew) |
|---|---|---|---|
| `oathtool` | Generar el código | `sudo apt install oathtool` | `brew install oath-toolkit` |
| `zbarimg` | Leer el QR de una imagen | `sudo apt install zbar-tools` | `brew install zbar` |
| Python 3 | Decodificar el enlace | Ya viene instalado | `brew install python` (o las herramientas de línea de comandos de Xcode) |
| Portapapeles (solo para `totp -c`) | Copiar el código | Ver abajo | Nada: `pbcopy` ya viene incluido |

### Portapapeles en Linux

Para `totp -c` necesitas una herramienta que dependa de tu sesión gráfica. Comprueba cuál usas:

```
echo $XDG_SESSION_TYPE
```

- Si dice `wayland` (lo habitual en Ubuntu 22.04 y posteriores): `sudo apt install wl-clipboard`
- Si dice `x11`: `sudo apt install xclip`

Si no estás seguro, instala las dos; el script elige la correcta. Sin sesión gráfica (por ejemplo, por SSH) no hay portapapeles al que copiar.

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

5. **Limpia los rastros**: borra la captura y el enlace, y quita la línea del historial del shell. El enlace contiene los secretos de *todas* las cuentas exportadas.
   - **bash** (Ubuntu): `history | tail`, luego `history -d NÚMERO` y `history -w`.
   - **zsh** (macOS): `history -d` no funciona igual; edita `~/.zsh_history`, borra la línea del enlace y cierra la terminal sin ejecutar más comandos.

## 2. Guardar la clave en un fichero

Sin que quede en el historial ni en pantalla. La sintaxis de `read` cambia según el shell (macOS usa zsh por defecto):

**bash (Ubuntu):**

```
umask 077
read -rs -p "Clave: " S && printf '%s\n' "$S" > ~/.totp_secret; unset S; echo
```

**zsh (macOS):**

```
umask 077
read -rs "S?Clave: " && printf '%s\n' "$S" > ~/.totp_secret; unset S; echo
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

### Copiar el código al portapapeles

```
./totp.sh -c
```

Muestra el código y además lo copia (consulta los requisitos de portapapeles más arriba). Ten en cuenta que el código se queda en el portapapeles hasta que copies otra cosa, y algunos gestores de portapapeles guardan historial.

### Ejecutarlo desde cualquier carpeta

```
mkdir -p ~/bin && cp totp.sh ~/bin/totp
```

Si `~/bin` no está en tu `PATH`, añade esta línea a `~/.bashrc` (Ubuntu) o a `~/.zshrc` (macOS):

```
export PATH="$HOME/bin:$PATH"
```

y vuelve a abrir la terminal. Después basta con escribir `totp` (o `totp -c`).

En Ubuntu, `~/bin` solo se añade al `PATH` automáticamente si la carpeta ya existía al iniciar sesión, así que si la acabas de crear, cierra sesión y vuelve a entrar.

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
- Con `-c`, copia el código usando `pbcopy` (macOS), `wl-copy` (Wayland) o `xclip` (X11), según lo que encuentre.

## Licencia

Uso libre. Si añades una licencia al repositorio, indícala aquí.
