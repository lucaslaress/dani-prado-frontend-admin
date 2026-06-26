# Instalador Dani Prado PDV
# Execute como Administrador

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$msixUrl  = "https://firebasestorage.googleapis.com/v0/b/dani-prado-47c0b.firebasestorage.app/o/dani_prado_frontend.msix?alt=media&token=d0583250-96a2-4f98-bce1-0e0172702760"
$certPath = "$env:TEMP\dani_prado.cer"
$msixPath = "$env:TEMP\dani_prado_frontend.msix"

# Certificado embutido (base64)
$certBase64 = "MIIDBjCCAe6gAwIBAgIQM6q5FOcbgqFOzHakjUPtBjANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAlEYW5pUHJhZG8wHhcNMjYwNjI2MDIxMjE1WhcNMjcwNjI2MDIzMjE1WjAUMRIwEAYDVQQDDAlEYW5pUHJhZG8wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC+PD0OIpXBFzlQAH14zpGj8xydyCsRC8UYNbbquTupX15tAHirWN59JWQcQ566nqmiLkC39Xmwm9Kp27yMpnKxGHCl3DkojaabQvVn0DzDFFId+p/MKL6qtoLS4rHAHeyIWlPaBOmJclzH0iAhTTSnn+kwh1Ntz/dmvQYkUMz9hK8bDB2fAW7h2kmBBybUkUh+FV2ejQ9wOokGG3K82qTm0VdvgX02BGLYQFI5Jcx+LGUOYDkDGvRCfqj1YyA2H9Dm7x1BJcf+GuslADCoY7o/QVLvN5V7nlYR4GaFNUD4QiItnwaJACqcQcXBFOctGftb8NETL4ainB4ycPjGAmVZAgMBAAGjVDBSMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBT8GBZ3MipphzWixO33Hi8wi+vvtjANBgkqhkiG9w0BAQsFAAOCAQEAYwCGHDqghbNOSo/BgNQzhcKWyJrAOTqmHZWXRqKM6aTlF9YbgpTGrKDB0+MiKJET8OYObrJv3BcJdDlClOCiKZLpnxwMF7Oofhd/R9yAngXd6fma58jrmdp8cjoKc8oc6bO+YpyAzlH5kRJEWXHRHi4iOvR7EUMOcsvUjq3w/KTbVQmogopPaLnfzZBfS7RbKBQXwajei8Ru1PbS2Yr75I+xlm3idCmHzzHV1I83bLsluXwSdbOHE+6ah0b69yj/i4tpBQ6S+pBwZzSTtl8aqu2LvV8fk20Og1GgHB3HPUKi216fd2u1zGkSjOmDoEAkjq3VqPWpT9AWIdKfDAuc0A=="

Write-Host "Instalando certificado..." -ForegroundColor Cyan
$certBytes = [Convert]::FromBase64String($certBase64)
[System.IO.File]::WriteAllBytes($certPath, $certBytes)
Import-Certificate -FilePath $certPath -CertStoreLocation "Cert:\LocalMachine\Root"         | Out-Null
Import-Certificate -FilePath $certPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null
Write-Host "Certificado instalado." -ForegroundColor Green

Write-Host "Baixando instalador..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $msixUrl -OutFile $msixPath
Write-Host "Download concluido." -ForegroundColor Green

Write-Host "Abrindo instalador..." -ForegroundColor Cyan
Start-Process $msixPath

Write-Host ""
Write-Host "Pronto! Clique em 'Instalar' na janela que abriu." -ForegroundColor Green
Write-Host "Pressione qualquer tecla para fechar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
