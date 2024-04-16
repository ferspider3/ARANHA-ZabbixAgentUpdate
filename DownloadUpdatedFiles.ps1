<#
.SYNOPSIS
    Download the latest Zabbix agent binaries from Zabbix's official CDN to a central repository.
.DESCRIPTION
    This script finds the latest version of the Zabbix agent binaries and downloads both 64 and 32 bits versions to specified locations.
.NOTES
    File Name   : DownloadUpdatedFiles.ps1
    Author      : Rafael Alexandre Feustel Gustmann - esserafael@gmail.com
    Requires    : PowerShell V3
    Version     : 1.2 - Improved version detection and added fallback to current version
	
	Modificado por : Fernando Aranha - ferspider3@hotmail.com
	Versão         : 1.0
#>

# Forçar o uso do TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

function Get-LatestZabbixVersion {
    param (
        [string]$baseUrl,
        [string]$currentVersion = "6.4.11"
    )
    try {
        $content = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing
        $versions = $content.Links.Href | Where-Object { $_ -match '\d+\.\d+\.\d+/$' } | ForEach-Object { $_.TrimEnd('/') } | Sort-Object -Descending
        if ($versions.Count -gt 0) {
            # Verifica se a versão mais recente é maior que a versão atual
            $latestVersion = $versions | Where-Object { [Version]$_ -gt [Version]$currentVersion } | Select-Object -First 1
            if ($latestVersion) {
                return $latestVersion
            }
        }
        # Se nenhuma versão nova foi encontrada, usa a versão atual como fallback
        return $currentVersion
    } catch {
        Write-Error "Erro ao acessar $baseUrl. Detalhes do erro: $_"
        exit
    }
}

function Download-File($url, $path) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $path)
    } catch {
        Write-Error "Erro ao baixar o arquivo de $url. Detalhes do erro: $_"
    } finally {
        $webClient.Dispose()
    }
}

$baseVersionUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/"
$currentVersion = "6.4.11"  # Defina sua versão atual aqui

# Determine the latest Zabbix version within the 6.4 directory
$latestVersion = Get-LatestZabbixVersion -baseUrl $baseVersionUrl -currentVersion $currentVersion

# Construct download URLs
$baseDownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/$latestVersion/"
$fileName64 = "zabbix_agent-$latestVersion-windows-amd64-openssl.msi"
$fileName32 = "zabbix_agent-$latestVersion-windows-i386-openssl.msi"

# Specify the download paths
$path64 = "\\meudomínio.com\zabbix\win64"
$path32 = "\\meudomínio.com\zabbix\win32"

# Download the files
Download-File -url "$baseDownloadUrl$fileName64" -path $path64
Download-File -url "$baseDownloadUrl$fileName32" -path $path32
