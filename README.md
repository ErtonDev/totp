# totp

Get your 6-digit Google Authenticator code from the terminal, without looking at your phone.

It contains three scripts:

- `totp.sh`: prints the current TOTP code using `oathtool` and, optionally, copies it to the clipboard (`-c`). It is the same script for Linux and macOS.
- `totp.ps1`: the same for Windows, with the same options (`totp` and `totp -c`). It uses only what comes with PowerShell. See [Windows](#windows).
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
| `gpg` (only for an [encrypted key](#optional-encrypt-the-key-with-a-password)) | Decrypt the key | Already installed (`gnupg`) | `brew install gnupg` |

On Windows you need nothing for the code itself; see [Windows](#windows).

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

### Optional: encrypt the key with a password

With the plain file, anyone (or any program) that can read your home folder can read the key. You can store it encrypted with GnuPG instead, so a password is needed to use it. `totp` uses `~/.totp_secret.gpg` if it exists and falls back to `~/.totp_secret` otherwise.

Encrypt the key you already stored and check that it works:

```
gpg --symmetric --cipher-algo AES256 -o ~/.totp_secret.gpg ~/.totp_secret
./totp.sh
```

(or `totp`, if you already [installed it](#run-it-from-any-folder)). If the code is right, delete the plain file:

- **Ubuntu:** `shred -u ~/.totp_secret`
- **macOS:** `rm ~/.totp_secret`

`gpg` asks you to choose a password (it is not the one of your user account; choose one you will remember, because without it the key cannot be recovered and you would have to export it again from your phone). After that, `totp` asks for it when needed. The `gpg-agent` remembers it for a few minutes, so you do not have to type it every time.

While both files exist, `totp` uses the encrypted one and warns you that the plain one is still there.

To go back to the plain file, decrypt it:

```
umask 077
gpg --decrypt -o ~/.totp_secret ~/.totp_secret.gpg && rm ~/.totp_secret.gpg
```

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

If `/another/path.gpg` exists, that encrypted file is used instead.

## What `totp.sh` does

- Checks that `oathtool` is installed and that the key file can be read.
- If `~/.totp_secret.gpg` exists, decrypts it with `gpg` (asking for the password) instead of reading `~/.totp_secret`, and warns if the plain file is still there.
- Warns if the plain file does not have `600` or `400` permissions.
- Ignores whitespace and newlines in the key.
- Prints the code and the seconds it has left.
- With `-c`, copies the code using `pbcopy` (macOS), `wl-copy` (Wayland) or `xclip` (X11), whichever it finds.

## Windows

`totp.ps1` does the same as `totp.sh` with the PowerShell that comes with Windows: it calculates the code itself (HMAC-SHA1, as defined in RFC 6238) and copies it with `Set-Clipboard`. You do not need `oathtool`.

All the commands below are for PowerShell (not the old `cmd`).

### 1. Get the secret key

You need Python and a tool to read the QR code:

- **Python:** `winget install Python.Python.3.12`, or from [python.org](https://www.python.org/downloads/).
- **QR reader:** download ZBar for Windows from [zbar.sourceforge.net](https://zbar.sourceforge.net/) and install it. It includes `zbarimg.exe`.

Then follow the same steps as on Linux, from the repository folder:

```
zbarimg screenshot.png
python decode_migration.py 'otpauth-migration://offline?data=...'
```

If `zbarimg` is not found, use its full path, for example `& 'C:\Program Files (x86)\ZBar\bin\zbarimg.exe' screenshot.png`. If `python` is not found, try `py`.

**Clean up the traces**: delete the screenshot and remove the link from the PowerShell history. The history is a text file; open it with:

```
notepad (Get-PSReadLineOption).HistorySavePath
```

delete the line with the link, save, and close PowerShell.

### 2. Store the key in a file

```
$k = Read-Host 'Key' -AsSecureString
[Net.NetworkCredential]::new('', $k).Password | Set-Content -NoNewline "$HOME\.totp_secret"
Remove-Variable k
```

Your user folder is only readable by your account (and administrators) by default, so there is no permission check on Windows.

### 3. Allow PowerShell scripts

Windows blocks scripts by default. Allow local scripts for your user, and unblock this one because it was downloaded from the internet:

```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Unblock-File .\totp.ps1
```

### 4. Use the script

```
.\totp.ps1
.\totp.ps1 -c
```

The output is the same as on Linux and macOS: `123456  (valid for 17s more)`. With `-c` the code is also copied to the clipboard.

### Run it from any folder

Copy it to a `bin` folder in your user folder and add that folder to your `PATH`:

```
New-Item -ItemType Directory -Force "$HOME\bin"
Copy-Item .\totp.ps1 "$HOME\bin\totp.ps1"
Unblock-File "$HOME\bin\totp.ps1"
$p = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', "$p;$HOME\bin", 'User')
```

Open a new PowerShell window. After that, just type `totp` (or `totp -c`). To check that it is installed correctly, `Get-Command totp` should show the path `...\bin\totp.ps1`.

To update it, run the `Copy-Item` and `Unblock-File` lines again. The key in `.totp_secret` is not touched.

### Another location for the key

```
$env:TOTP_SECRET_FILE = 'D:\another\path'
totp
```

### Optional: encrypt the key

The encrypted key works on Windows too, with GnuPG for Windows (Gpg4win):

```
winget install GnuPG.Gpg4win
```

Open a new PowerShell window, then:

```
gpg --symmetric --cipher-algo AES256 -o "$HOME\.totp_secret.gpg" "$HOME\.totp_secret"
totp
Remove-Item "$HOME\.totp_secret"
```

As on Linux and macOS, `totp` uses `.totp_secret.gpg` if it exists and falls back to `.totp_secret` otherwise.

## License

This project is released under the [MIT License](LICENSE).
