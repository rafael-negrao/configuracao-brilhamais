---
name: feedback-cpu-virt-hypervisor-mask
description: Win32_Processor.VirtualizationFirmwareEnabled e SLAT retornam False quando o hypervisor está ativo — não confie em valor False para concluir que a CPU não suporta virtualização
metadata: 
  type: feedback
---

No Windows, ao verificar suporte de CPU para virtualização (para WSL2, Docker Desktop, Hyper-V) via WMI/CIM:

```powershell
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpu.VirtualizationFirmwareEnabled              # pode mentir
$cpu.SecondLevelAddressTranslationExtensions    # pode mentir
```

**Quando o hypervisor (Hyper-V ou WSL2) já está ativo, esses campos retornam `False` mesmo a CPU tendo o recurso de fato.** O Windows esconde a propriedade real porque o hypervisor está consumindo-a, e `systeminfo` confirma com a mensagem "Hipervisor detectado. Recursos necessários para o Hyper-V não serão exibidos."

Solução: **detectar primeiro se o hypervisor já está rodando** e, se sim, inferir que a virtualização está habilitada (caso contrário ele não estaria rodando). Só caso o hypervisor esteja inativo é que faz sentido ler `VirtualizationFirmwareEnabled` da CPU:

```powershell
$hyperVisorActive = [bool](Get-CimInstance Win32_ComputerSystem).HypervisorPresent

if ($hyperVisorActive) {
    # virtualizacao OK (inferido) - hypervisor nao rodaria sem ela
} else {
    # so agora vale ler Win32_Processor.VirtualizationFirmwareEnabled e SLAT
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if (-not $cpu.VirtualizationFirmwareEnabled) {
        # avise para habilitar VT-x/AMD-V no BIOS/UEFI
    }
}
```

**Why:** Em 2026-05-16, ao escrever um script de preflight (`setup-brilhamais.ps1` Fase 0) para validar se uma máquina suporta WSL2/Docker, o script reportou "virtualização DESABILITADA" + "SLAT ausente" numa máquina onde ambos estavam habilitados — e onde, no início da sessão (antes de instalar WSL2), o mesmo comando retornava `True`. A causa: depois de instalar WSL2, o hypervisor passou a rodar; daí em diante `Win32_Processor` esconde a info da CPU. Isso quebraria a idempotência de qualquer script de provisionamento que re-checasse pré-requisitos.

**How to apply:** Sempre que um script for verificar suporte de virtualização em Windows, **primeiro** consultar `Win32_ComputerSystem.HypervisorPresent`. Se `True`, inferir OK. Se `False`, aí sim ler propriedades da CPU. Esta armadilha aparece em scripts de provisionamento (setup automatizado), troubleshooting de Docker/WSL e em CI que monta máquinas Windows. Relaciona com [project-aluno-setup](project_aluno_setup.md) — o caso concreto foi nesse script.
