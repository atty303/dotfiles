# Bootstrap Instructions

## Windows Setup Guide

### Prerequisites
- Windows 10 or later
- PowerShell 5.1 or later
- Internet connection

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
    - Select "Windows Terminal"

3. Install and configure chezmoi:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b ~/.local/bin -- init --apply atty303"
   ```

4. Configure Atuin shell history:
   ```bash
   atuin login -u atty303
   atuin sync
   ```

### Notes
- Ensure all commands are executed in order
- Administrative privileges may be required
- Wait for each command to complete before proceeding to the next

# Memo

- [Windows Sandbox](https://learn.microsoft.com/ja-jp/windows/security/application-security/application-isolation/windows-sandbox/) for testing bootstrap
- [winget configure](https://learn.microsoft.com/ja-jp/windows/package-manager/winget/configure) for ensure configuration
- https://github.com/ChrisTitusTech/winutil
