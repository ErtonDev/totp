# totp

Get your 6-digit Google Authenticator code from the terminal, without looking at your phone.

It contains two scripts:

- `totp.sh`: prints the current TOTP code using `oathtool` and, optionally, copies it to the clipboard (`-c`). It is the same script for Linux and macOS.
- `decode_migration.py`: extracts the base32 secret key from the `otpauth-migration://` link you get when exporting accounts from Google Authenticator.

> **Security warning.** Keeping your second factor on the same computer you log in from weakens the protection 2FA gives you, because it no longer depends on a separate device. Only do this if you understand and accept that risk. Anyone with your secret key can generate your codes.

## Requirements

The code is the same on both systems; only the way you install the tools changes.

| Tool | Purpose | Ubuntu / Debian | macOS (Homebrew) |
|---|---|---|---|
| `oathtool` | Generate the code | `sudo apt install oathtool` | `brew install oath-toolkit` |
| `zbarimg` | Read the QR code from an image | `sudo apt install zbar-tools` | `brew install zbar` |
| Python 3 | Decode the link | Already installed | `brew install python` (or the Xcode command line tools) |
| Clipboard (only for `totp -c`) | Copy the code | See below | Nothing: `pbcopy` is built in |

### Clipboard on Linux

`totp -c` needs a tool that depends on your graphical session. Check which one you use:

```
echo $XDG_SESSION_TYPE
```

- If it says `wayland` (the default on recent Ubuntu): `sudo apt install wl-clipboard`
- If it says `x11`: `sudo apt install xclip`

If you are not sure, install both; the script picks the right one. Without a graphical session (for example over SSH) there is no clipboard to copy to.

## 1. Get the secret key

1. In Google Authenticator, use **Transfer accounts → Export accounts** and generate the QR code.
2. Take a screenshot and move it to your computer.
3. Extract the link from the QR code:
   ```
   zbarimg screenshot.png
   ```
   You will see something like `QR-Code:otpauth-migration://offline?data=...`.
4. Decode it (with the link in single quotes):
   ```
   python3 decode_migration.py 'otpauth-migration://offline?data=...'
   ```
   For each exported account it prints the issuer, the name and the base32 key.

5. **Clean up the traces**: delete the screenshot and the link, and remove the line from your shell history. The link contains the secrets of *all* the exported accounts.
   - **bash** (Ubuntu): `history | tail`, then `history -d NUMBER` and `history -w`.
   - **zsh** (macOS): `history -d` does not work the same way; edit `~/.zsh_history`, delete the line with the link and close the terminal without running more commands.

## 2. Store the key in a file

Without leaving it in your history or on screen. The `read` syntax depends on the shell (macOS uses zsh by default):

**bash (Ubuntu):**

```
umask 077
read -rs -p "Key: " S && printf '%s\n' "$S" > ~/.totp_secret; unset S; echo
```

**zsh (macOS):**

```
umask 077
read -rs "S?Key: " && printf '%s\n' "$S" > ~/.totp_secret; unset S; echo
```

The file must have `600` permissions (`ls -l ~/.totp_secret`).

## 3. Use the script

```
chmod +x totp.sh
./totp.sh
```

Example output:

```
123456  (valid for 17s more)
```

Check that it matches the code on your phone.

### Copy the code to the clipboard

```
./totp.sh -c
```

It prints the code and also copies it (see the clipboard requirements above). Note that the code stays in the clipboard until you copy something else, and some clipboard managers keep a history.

### Run it from any folder

```
mkdir -p ~/bin && cp totp.sh ~/bin/totp
```

If `~/bin` is not in your `PATH`, add this line to `~/.bashrc` (Ubuntu) or `~/.zshrc` (macOS):

```
export PATH="$HOME/bin:$PATH"
```

and open a new terminal. After that, just type `totp` (or `totp -c`).

On Ubuntu, `~/bin` is only added to the `PATH` automatically if the folder already existed when you logged in, so if you have just created it, log out and log back in.

To check that it is installed correctly:

```
which totp
```

It should print the path `~/bin/totp` (for example, `/home/your_user/bin/totp`). If it prints nothing, `~/bin` is not in the `PATH`.

#### Common problems

- **`totp: command not found`**: `~/bin` is not in the `PATH`. Add the `export PATH=...` line above to your `~/.bashrc` or `~/.zshrc`, then run `source ~/.bashrc` (or `source ~/.zshrc`), or open a new terminal.
- **`Permission denied`**: the script is missing the execute permission. Run `chmod +x ~/bin/totp`.

#### Updating the script

If you already had it installed and you download a newer version from the repository, copy it over the old one (from the repository folder) and check the permission:

```
cp totp.sh ~/bin/totp && chmod +x ~/bin/totp
```

The key in `~/.totp_secret` is not touched, so you do not need to store it again.

### Another location for the key

By default `~/.totp_secret` is read. You can change it with the `TOTP_SECRET_FILE` variable:

```
TOTP_SECRET_FILE=/another/path totp
```

## What `totp.sh` does

- Checks that `oathtool` is installed and that the key file can be read.
- Warns if the file does not have `600` or `400` permissions.
- Ignores whitespace and newlines in the key.
- Prints the code and the seconds it has left.
- With `-c`, copies the code using `pbcopy` (macOS), `wl-copy` (Wayland) or `xclip` (X11), whichever it finds.

## License

Free to use.
