$usuario = "nome_do_usuario"
$sessions = Get-RDUserSession
$sessaoUsuario = $sessions | Where-Object { $_.UserName -eq $usuario }
 
foreach ($session in $sessaoUsuario)
{
    Invoke-RDUserLogoff -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -Force
}