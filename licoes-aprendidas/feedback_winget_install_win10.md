---
name: feedback-winget-install-win10
description: Como instalar winget manualmente em Windows 10 quando não vem por padrão — qual versão escolher e como tratar dependências
metadata: 
  type: feedback
---

Para instalar o winget em Windows 10 sem usar a Microsoft Store, use a release estável **v1.12.470** (ou outra da série 1.12), não as v1.28+. Baixe dois arquivos do GitHub `microsoft/winget-cli`:

1. `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle` (~206 MB)
2. `DesktopAppInstaller_Dependencies.zip` (~93 MB) — extraia e use os `.appx` da subpasta `x64` (ou `arm64`/`x86` conforme a CPU)

Instale tudo numa só chamada:
```powershell
Add-AppxPackage -Path .\winget.msixbundle -DependencyPath @(
  ".\x64\Microsoft.VCLibs.140.00_*_x64.appx",
  ".\x64\Microsoft.VCLibs.140.00.UWPDesktop_*_x64.appx",
  ".\x64\Microsoft.WindowsAppRuntime.1.8_*_x64.appx"
)
```

**Why:** Em maio de 2026 tentei a v1.28.240 (latest stable) numa máquina Win10 22H2 Home limpa e falhou com `HRESULT 0x80073CF3` reclamando de `Microsoft.WindowsAppRuntime.1.8` ausente. A v1.12.470 também depende disso, mas traz o runtime no zip de dependências oficial — a v1.28 não traz e exige instalar o WinAppSDK separadamente. Win10 não pré-instala o WindowsAppRuntime; só Win11 recente.

**How to apply:** Use ao montar uma máquina Windows 10 do zero. Em Win11 ou Win10 que já tenha o App Installer da Microsoft Store atualizado, prefira atualizar via Store e pule este fluxo manual. Antes de baixar, faça `Get-AppxPackage Microsoft.DesktopAppInstaller` — se já existir e versão >= 1.x, o winget provavelmente já está disponível, só não está no PATH (ver [feedback-path-recompose](feedback_path_recompose.md)).
