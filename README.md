# Bootstrap Instructions

## Linux Setup

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply atty303
```

## Windows Setup Guide

### Prerequisites
- Windows 11 24H2 or later
- PowerShell 5.1 or later

### Installation Steps

1. Allow create symbolic link:
   - Press `Windows + R`
   - Run `gpedit.mac`
   - Navigate to `Computer Configuration\Windows Settings\Security Settings\Local Policies\User Rights Assignment`
   - Edit `Create symbolic links`
   - Add your account
   - Logout or Reboot

2. Open Windows Terminal:
    - Press `Windows + X`
    - Select "Windows Terminal (Administrator)"

3. Install and configure chezmoi:
   ```powershell
   New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled" -Value 3 -PropertyType DWORD -Force
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b ~/.local/bin -- init --apply atty303"
   ```

4. Configure Atuin shell history:
   ```bash
   atuin login -u atty303
   atuin sync
   ```

## Out-of-scope of chezmoi

- 1Password
   - Configure manually
- Zen
   - Sync with Mozilla Account
- ATOK

### Notes
- Ensure all commands are executed in order
- Administrative privileges may be required
- Wait for each command to complete before proceeding to the next

## Memo

- [Windows Sandbox](https://learn.microsoft.com/ja-jp/windows/security/application-security/application-isolation/windows-sandbox/) for testing bootstrap
- [winget configure](https://learn.microsoft.com/ja-jp/windows/package-manager/winget/configure) for ensure configuration
- https://github.com/ChrisTitusTech/winutil

## chezmoi templates cheatsheet

https://www.chezmoi.io/reference/templates/

- Trimming: `"{{23 -}} < {{- 45}}"` -> `23<45`
- Conditionals: `{{if pipeline}} T1 {{end}}`, `{{if pipeline}} T1 {{else}} T0 {{end}}`, `{{if pipeline}} T1 {{else if pipeline}} T0 {{end}}`
- Iteration: `{{range pipeline}} {{.}} {{end}}`, `{{range pipeline}} T1 {{else}} T0 {{end}}`
- `{{with pipeline}} T1 {{end}}`: `if (pipeline) { . = pipeline; T1 }`
- Functions:
   - https://pkg.go.dev/text/template
   - https://masterminds.github.io/sprig/
