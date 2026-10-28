# Prints the current 6-digit TOTP code (the same one Google Authenticator shows).
# Works on Windows with the built-in PowerShell; nothing needs to be installed.
#
# Usage:
#   totp       print the code
#   totp -c    print the code and copy it to the clipboard
#
# Requirements:
#   Only for an encrypted key: gpg  (Gpg4win: winget install GnuPG.Gpg4win)

param(
    [switch]$c
)

$ErrorActionPreference = 'Stop'

# The base32 secret key is read from this file. If an encrypted copy
# with the same name plus ".gpg" exists, that one is used instead.
$SecretFile = if ($env:TOTP_SECRET_FILE) { $env:TOTP_SECRET_FILE } else { Join-Path $HOME '.totp_secret' }
$EncryptedFile = "$SecretFile.gpg"

if (Test-Path -LiteralPath $EncryptedFile) {
    # Encrypted key: gpg asks for the password (gpg-agent may remember it for a while)
    if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: $EncryptedFile exists but gpg is not installed.")
        exit 1
    }
    if (Test-Path -LiteralPath $SecretFile) {
        [Console]::Error.WriteLine("Warning: $SecretFile is still there unencrypted; delete it once the encrypted one works.")
    }
    $Text = (& gpg --quiet --decrypt $EncryptedFile) -join ''
    if ($LASTEXITCODE -ne 0 -or -not $Text) {
        [Console]::Error.WriteLine("Error: could not decrypt $EncryptedFile")
        exit 1
    }
} else {
    if (-not (Test-Path -LiteralPath $SecretFile)) {
        [Console]::Error.WriteLine("Error: cannot read $SecretFile")
        exit 1
    }
    $Text = Get-Content -LiteralPath $SecretFile -Raw
}

# Strip any whitespace, newlines and "=" padding from the key
$Secret = ($Text -replace '[\s=]', '').ToUpperInvariant()

# Decode base32 into raw key bytes
$Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
$Bytes = New-Object System.Collections.Generic.List[byte]
$Buffer = 0
$Bits = 0
foreach ($Char in $Secret.ToCharArray()) {
    $Value = $Alphabet.IndexOf($Char)
    if ($Value -lt 0) {
        [Console]::Error.WriteLine("Error: the key in $SecretFile is not valid base32.")
        exit 1
    }
    $Buffer = (($Buffer -shl 5) -bor $Value) -band 0xFFFF
    $Bits += 5
    if ($Bits -ge 8) {
        $Bits -= 8
        $Bytes.Add([byte](($Buffer -shr $Bits) -band 0xFF))
    }
}
if ($Bytes.Count -eq 0) {
    [Console]::Error.WriteLine("Error: $SecretFile is empty.")
    exit 1
}

# TOTP (RFC 6238): HMAC-SHA1 of the number of 30-second steps since 1970
$Now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$Counter = [BitConverter]::GetBytes([long][Math]::Floor($Now / 30))
if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($Counter) }

$Hmac = New-Object System.Security.Cryptography.HMACSHA1 -ArgumentList (, $Bytes.ToArray())
$Hash = $Hmac.ComputeHash($Counter)
$Hmac.Dispose()

# Dynamic truncation: take 4 bytes at the offset given by the last byte
$Offset = $Hash[19] -band 0x0F
$Number = (([int]($Hash[$Offset] -band 0x7F)) -shl 24) -bor
          (([int]$Hash[$Offset + 1]) -shl 16) -bor
          (([int]$Hash[$Offset + 2]) -shl 8) -bor
          ([int]$Hash[$Offset + 3])
$Code = ($Number % 1000000).ToString('D6')
$Remaining = 30 - ($Now % 30)

Write-Output "$Code  (valid for ${Remaining}s more)"

if ($c) {
    Set-Clipboard -Value $Code
    Write-Output 'Copied to clipboard.'
}
