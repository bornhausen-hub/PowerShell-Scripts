$targetComputer = Read-Host "Digite o nome do servidor RDS onde o usuário está logado (ex: RDS02)"
if (-not $targetComputer) {
    Write-Error "O nome do computador não pode ser vazio."
    return
}

$targetUser = Read-Host "Digite o nome do usuário no formato DOMINIO\usuario (ex: MEUDOMINIO\jonathan.kuhl)"
if (-not $targetUser) {
    Write-Error "O nome de usuário não pode ser vazio."
    return
}

$reportPath = "C:\Temp\GPO_Report_$(($targetUser -replace '\\','-'))_on_$($targetComputer).html"
$reportFolder = "C:\Temp"

if (-not (Test-Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory | Out-Null
}

Write-Host "`nGerando relatório para o usuário '$targetUser' no computador '$targetComputer'..." -ForegroundColor Cyan
Write-Host "O relatório será salvo em: $reportPath"

try {
   
    gpresult /S $targetComputer /USER $targetUser /H $reportPath /F
    
    Write-Host "`nRelatório gerado com SUCESSO!" -ForegroundColor Green
    Write-Host "Abrindo o relatório no seu navegador..."

    Start-Process $reportPath
}
catch {
    Write-Error "Ocorreu um erro ao gerar o relatório. Verifique as mensagens abaixo:"
    Write-Error $_.Exception.Message
    Write-Warning "Possíveis causas:"
    Write-Warning "- O nome do computador ou usuário está incorreto."
    Write-Warning "- O computador de destino está offline ou bloqueando conexões (firewall)."
    Write-Warning "- O usuário especificado não tem uma sessão ativa ou nunca fez logon no computador de destino."
    Write-Warning "- Você não tem permissões de administrador no computador de destino."
}
