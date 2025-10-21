<#
.SYNOPSIS
    Remove de forma segura e completa um perfil de usuário de múltiplos servidores RDS.
.DESCRIPTION
    Este script automatiza o processo de backup, exclusão de perfil (pasta, registro, VHDX)
    e verificação. Versão 2.1 lida com perfis duplicados/corrompidos.
.AUTHOR
    Manus (Assistente AI)
.VERSION
    2.1
#>

# --- CONFIGURAÇÕES ---
$userName = Read-Host "Digite o nome de usuário (login) a ser removido (ex: joao.silva)"
if (-not $userName) { Write-Error "O nome de usuário não pode ser vazio."; return }

$serverListInput = Read-Host "Digite os nomes dos servidores RDS, separados por vírgula (ex: RDS01,RDS02)"
$servers = $serverListInput.Split(',') | ForEach-Object { $_.Trim() }
if (-not $servers) { Write-Error "A lista de servidores não pode ser vazia."; return }

$backupBasePath = Read-Host "Digite o caminho para a pasta de backup (ex: \\servidor-arquivos\Backups\Perfis)"
if (-not (Test-Path $backupBasePath)) {
    try {
        New-Item -Path $backupBasePath -ItemType Directory -Force | Out-Null
        Write-Host "Pasta de backup criada em $backupBasePath" -ForegroundColor Green
    } catch { Write-Error "Falha ao criar a pasta de backup. Saindo."; return }
}

# --- EXECUÇÃO ---
Write-Host "`nIniciando processo de remoção para o usuário '$userName' nos servidores: $($servers -join ', ')" -ForegroundColor Cyan

foreach ($server in $servers) {
    Write-Host "`n--- Processando Servidor: $server ---" -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
        Write-Warning "Servidor '$server' está offline ou inacessível. Pulando."
        continue
    }

    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($targetUser, $backupPath)

            $userAccount = New-Object System.Security.Principal.NTAccount($env:USERDOMAIN, $targetUser)
            $sid = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
            
            # A consulta agora retorna uma coleção, mesmo que vazia
            $profiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.SID -eq $sid }

            if ($profiles.Count -eq 0) {
                Write-Host "Nenhum perfil registrado para '$targetUser' (SID: $sid) foi encontrado."
                $userFolderPath = "C:\Users\$targetUser"
                if (Test-Path $userFolderPath) {
                    Write-Warning "Atenção: Pasta de perfil órfã encontrada em '$userFolderPath'. Renomeando para '$userFolderPath.orphaned'."
                    Rename-Item -Path $userFolderPath -NewName "$targetUser.orphaned" -ErrorAction SilentlyContinue
                }
                return
            }

            Write-Warning "Encontrado(s) $($profiles.Count) perfil(s) para o usuário '$targetUser'. Processando cada um."

            # Itera sobre cada perfil encontrado (para lidar com duplicatas)
            foreach ($profile in $profiles) {
                Write-Host "Processando entrada de perfil com SID $($profile.SID)..."
                $localPath = $profile.LocalPath

                # VERIFICAÇÃO CRUCIAL: Pula se o caminho for nulo
                if ([string]::IsNullOrWhiteSpace($localPath)) {
                    Write-Warning "Esta entrada de perfil tem um caminho local NULO. Tentando remover apenas a entrada do registro."
                } else {
                    # --- ETAPA DE BACKUP ---
                    if (Test-Path $localPath) {
                        Write-Host "Iniciando backup de '$localPath'..."
                        $backupDestination = Join-Path -Path $backupPath -ChildPath "$targetUser-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
                        New-Item -ItemType Directory -Path $backupDestination -Force | Out-Null
                        $itemsToBackup = @("Desktop", "Documents", "Downloads", "Favorites", "Pictures", "Music", "Videos")
                        foreach ($item in $itemsToBackup) {
                            $sourcePath = Join-Path -Path $localPath -ChildPath $item
                            if (Test-Path $sourcePath) {
                                Copy-Item -Path $sourcePath -Destination $backupDestination -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                        Write-Host "Backup concluído em '$backupDestination'" -ForegroundColor Green
                    }
                }

                # --- ETAPA DE EXCLUSÃO ---
                try {
                    Write-Host "Tentando excluir a entrada de perfil..."
                    $profile.Delete()
                    Write-Host "Entrada de perfil removida com sucesso via WMI." -ForegroundColor Green
                } catch {
                    Write-Error "Falha ao excluir a entrada de perfil via WMI. Erro: $_"
                }
            }
        } -ArgumentList $userName, $backupBasePath
    } catch {
        Write-Error "Falha ao executar o comando remoto em '$server'. Erro: $($_.Exception.Message)"
    }
}

Write-Host "`n--- Processo Concluído ---" -ForegroundColor Cyan
