# Bootstrap Instructions

## Windows Setup Guide

### Prerequisites
- Windows 10 or later
- PowerShell 5.1 or later
- Internet connection

### Installation Steps

1. Open Windows Terminal:
    - Press `Windows + X`
    - Select "Windows Terminal"

2. Install and configure chezmoi:
   ```powershell
   iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b ~/.local/bin -- init --apply atty303"
   ```

3. Configure Atuin shell history:
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

## ToDo
- [ ] Configure AHK