# Define as variáveis necessárias
$zabbixBasePath = "\\meudomínio.com\zabbix\"
$zabbixInstallDir = "C:\zabbix"
$zabbixServiceName = "Zabbix Agent"
$zabbixConfSrc = Join-Path -Path $zabbixBasePath -ChildPath "zabbix_agentd.conf"
$zabbixConfDest = Join-Path -Path $zabbixInstallDir -ChildPath "zabbix_agentd.conf"
$extractedDirName = "Zabbix Agent"  # Nome da pasta onde o MSI extrai os arquivos
$logPath = Join-Path -Path $zabbixInstallDir -ChildPath "update_zabbix.txt"
$timestamp = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

# Função para obter a versão instalada do Zabbix Agent
function Get-InstalledZabbixVersion {
    param(
        [string]$InstallDir  # Use um novo nome de parâmetro para evitar confusão
    )

    $zabbixAgentExecutable = Join-Path -Path $InstallDir -ChildPath "zabbix_agentd.exe"
    if (Test-Path -Path $zabbixAgentExecutable) {
        $outputFile = Join-Path -Path $InstallDir -ChildPath "zabbix_version.txt"
        Start-Process -FilePath $zabbixAgentExecutable -ArgumentList "-V" -RedirectStandardOutput $outputFile -NoNewWindow -Wait
        $versionInfo = Get-Content -Path $outputFile -Raw -ErrorAction SilentlyContinue
        Remove-Item -Path $outputFile -ErrorAction SilentlyContinue  # Limpa o arquivo temporário

        if ($versionInfo -match '\b(\d+\.\d+\.\d+)\b') {
            return $matches[1]
        }
    }
    return $null
}

# Função para parar o serviço Zabbix Agent
function Stop-ZabbixService {
    if (Get-Service $zabbixServiceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $zabbixServiceName -Force
        "$timestamp - Serviço Zabbix Agent parado para atualização."  | Out-File -FilePath $logPath -Append
    }
}

# Função para desinstalar o serviço Zabbix Agent
function Uninstall-ZabbixService {
    if (Get-Service $zabbixServiceName -ErrorAction SilentlyContinue) {
        & sc delete $zabbixServiceName
        "$timestamp - Serviço Zabbix Agent desinstalado."  | Out-File -FilePath $logPath -Append
    }
}

# Função para obter o arquivo MSI mais recente
function Get-LatestMSI {
    $architectureDir = if ((Get-CimInstance -Class Win32_OperatingSystem).OSArchitecture -like "64*") { "64" } else { "32" }
    $zabbixAgentDir = Join-Path -Path $zabbixBasePath -ChildPath $architectureDir

    $latestMSI = Get-ChildItem -Path $zabbixAgentDir -Filter "*.msi" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestMSI) {
        # Extrai a versão do nome do arquivo, assumindo que o nome segue o formato "zabbix_agent-<versão>-<outros>.msi"
        if ($latestMSI.Name -match 'zabbix_agent-(\d+\.\d+\.\d+)-') {
            $msiVersion = $matches[1]
            return @{ "Path" = $latestMSI.FullName; "Version" = $msiVersion }
        } else {
            "$timestamp - Não foi possível extrair a versão do nome do arquivo MSI: $($latestMSI.FullName)"  | Out-File -FilePath $logPath -Append
        }
    } else {
        "$timestamp - Nenhum arquivo MSI encontrado em $zabbixAgentDir"  | Out-File -FilePath $logPath -Append
    }
    return $null
}

# Função para obter o caminho do arquivo MSI mais recente
function Get-LatestMSIfile {
    # Determina o diretório específico da arquitetura
    $architectureDir = if ((Get-CimInstance -Class Win32_OperatingSystem).OSArchitecture -like "64*") { "64" } else { "32" }
    $zabbixAgentDir = Join-Path -Path $zabbixBasePath -ChildPath $architectureDir

    $latestMSI = Get-ChildItem -Path $zabbixAgentDir -Filter "*.msi" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    return $latestMSI
}

# Função para extrair o Zabbix Agent
function ExtractZabbixAgent {
    $latestMSIPath = (Get-LatestMSIfile).FullName
    if (-not $latestMSIPath) {
        "$timestamp - Nenhum pacote MSI encontrado em $zabbixAgentDir"  | Out-File -FilePath $logPath -Append
        exit
    }

    "$timestamp - Extraindo Zabbix Agent de $latestMSIPath para $zabbixInstallDir..."  | Out-File -FilePath $logPath -Append
    $msiLogPath = Join-Path -Path $zabbixInstallDir -ChildPath "zabbix_agent_extract.log"

    # Define os argumentos para a extração do MSI
    $msiExecArgs = "/a `"$latestMSIPath`" /qn /l*v `"$msiLogPath`" TARGETDIR=`"$zabbixInstallDir`""

    # Executa a extração do MSI
    Start-Process "msiexec.exe" -ArgumentList $msiExecArgs -Wait -NoNewWindow

    # Aguarda um momento para garantir que a extração seja concluída
    Start-Sleep -Seconds 30

    MoveAndCleanupFiles
}

# Função para mover e limpar os arquivos extraídos
function MoveAndCleanupFiles {
    $extractedDirPath = Join-Path -Path $zabbixInstallDir -ChildPath $extractedDirName
    if (Test-Path -Path $extractedDirPath) {
        Get-ChildItem -Path $extractedDirPath | ForEach-Object {
            $destinationPath = Join-Path -Path $zabbixInstallDir -ChildPath $_.Name
            # Verifica se o arquivo de destino já existe e, se sim, remove-o antes de mover o novo arquivo
            if (Test-Path -Path $destinationPath) {
                Remove-Item -Path $destinationPath -Force
            }
            Move-Item -Path $_.FullName -Destination $destinationPath -Force
        }
        Remove-Item -Path $extractedDirPath -Recurse -Force
        "$timestamp - Arquivos extraídos movidos para $zabbixInstallDir e limpeza concluída." | Out-File -FilePath $logPath -Append
        CopyAndUpdateConfiguration
    } else {
        "$timestamp - Diretório de extração $extractedDirPath não encontrado. Verifique o processo de extração e o log em $msiLogPath" | Out-File -FilePath $logPath -Append
        exit
    }
}


# Função para copiar e atualizar a configuração
function CopyAndUpdateConfiguration {
    Copy-Item -Path $zabbixConfSrc -Destination $zabbixConfDest -Force
    "$timestamp - Arquivo de configuração copiado para $zabbixInstallDir." | Out-File -FilePath $logPath -Append

    $currentMachineName = $env:COMPUTERNAME
    (Get-Content $zabbixConfDest) | ForEach-Object {
        if ($_ -match "^Hostname=.*") {
            "Hostname=$currentMachineName"
        } else {
            $_
        }
    } | Set-Content $zabbixConfDest

    "$timestamp - Arquivo de configuração atualizado com o nome da máquina atual: $currentMachineName" | Out-File -FilePath $logPath -Append
    FinalizeConfiguration
}

# Função para finalizar a configuração
function FinalizeConfiguration {
    $zabbixAgentExecutable = Join-Path -Path $zabbixInstallDir -ChildPath "zabbix_agentd.exe"
    if (Test-Path -Path $zabbixAgentExecutable) {
        "$timestamp - Finalizando a configuração do Zabbix Agent..." | Out-File -FilePath $logPath -Append
        Start-Process -FilePath $zabbixAgentExecutable -ArgumentList "-c `"$zabbixConfDest`" -i" -Wait -NoNewWindow
        "$timestamp - Serviço Zabbix Agent instalado e configuração validada." | Out-File -FilePath $logPath -Append
    } else {
        "$timestamp - Executável Zabbix Agent não encontrado em $zabbixAgentExecutable. Certifique-se de que a extração e o movimento dos arquivos foram bem-sucedidos." | Out-File -FilePath $logPath -Append
        exit
    }
}

function CleanupMSIFiles {
    $msiFiles = Get-ChildItem -Path $zabbixInstallDir -Filter "*.msi"
    foreach ($file in $msiFiles) {
        Remove-Item -Path $file.FullName -Force
        "$timestamp - Arquivo MSI excluído: $($file.Name)" | Out-File -FilePath $logPath -Append
    }
}

function StartZabbixService {
    # Verifica se o serviço existe e está parado antes de tentar iniciá-lo
    if (Get-Service -Name $zabbixServiceName -ErrorAction SilentlyContinue) {
        Start-Service -Name $zabbixServiceName
        "$timestamp - Serviço Zabbix Agent iniciado." | Out-File -FilePath $logPath -Append
    } else {
        "$timestamp - Serviço Zabbix Agent não encontrado. Tentando instalar o serviço..." | Out-File -FilePath $logPath -Append
        $zabbixAgentExecutable = Join-Path -Path $zabbixInstallDir -ChildPath "zabbix_agentd.exe"
        if (Test-Path -Path $zabbixAgentExecutable) {
            & $zabbixAgentExecutable -c "$zabbixConfDest" -i
            Start-Service -Name $zabbixServiceName
            "$timestamp - Serviço Zabbix Agent instalado e iniciado." | Out-File -FilePath $logPath -Append
        } else {
            "$timestamp - Nao foi possivel encontrar o executavel Zabbix Agent para instalar o servico." | Out-File -FilePath $logPath -Append
        }
    }
}

function Update-HostnameInConfig {
    param(
        [string]$ConfigPath,  # Caminho para o arquivo de configuração do Zabbix Agent
        [string]$CurrentHostname  # Nome atual do host
    )

    # Lê o conteúdo do arquivo de configuração
    $configContent = Get-Content -Path $ConfigPath

    # Procura por linhas que começam com "Hostname=" e captura o valor
    $hostnameConfig = $configContent | Where-Object { $_ -match '^Hostname=(.*)' } | ForEach-Object { $matches[1] }

    if ($hostnameConfig -ne $CurrentHostname) {
        "$timestamp - Atualizando o nome do host no arquivo de configuração do Zabbix Agent para: $CurrentHostname" | Out-File -FilePath $logPath -Append

        # Atualiza o arquivo de configuração com o novo nome do host
        $newConfigContent = $configContent | ForEach-Object {
            if ($_ -match '^Hostname=') {
                "Hostname=$CurrentHostname"
            } else {
                $_
            }
        }

        # Salva o arquivo de configuração atualizado
        Set-Content -Path $ConfigPath -Value $newConfigContent
        "$timestamp - O arquivo de configuração do Zabbix Agent foi atualizado com o novo nome do host." | Out-File -FilePath $logPath -Append
    } else {
        "$timestamp - O nome do host no arquivo de configuração do Zabbix Agent já está correto." | Out-File -FilePath $logPath -Append
    }
}

# Lógica principal
if (Test-Path -Path "$zabbixInstallDir\zabbix_agentd.exe") {
    $installedVersion = Get-InstalledZabbixVersion -InstallDir $zabbixInstallDir
    "$timestamp - Versão instalada do Zabbix Agent: $installedVersion" | Out-File -FilePath $logPath -Append
    
    # Verifica e atualiza o nome do host no arquivo de configuração, se necessário
    $currentMachineName = $env:COMPUTERNAME
    Update-HostnameInConfig -ConfigPath $zabbixConfDest -CurrentHostname $currentMachineName

    $latestMSIInfo = Get-LatestMSI
    if ($latestMSIInfo) {
        $latestVersion = $latestMSIInfo['Version']
        "$timestamp - Versão mais recente disponível do Zabbix Agent: $latestVersion" | Out-File -FilePath $logPath -Append

        if ($installedVersion -and $latestVersion -and ($installedVersion -ne $latestVersion)) {
            "$timestamp - Uma atualização do Zabbix Agent está disponível. Iniciando o processo de atualização..." | Out-File -FilePath $logPath -Append
            Stop-ZabbixService
            Uninstall-ZabbixService
            ExtractZabbixAgent
            CleanupMSIFiles
            StartZabbixService
        } else {
            "$timestamp - Zabbix Agent já está atualizado. Versão instalada: $installedVersion.`n" | Out-File -FilePath $logPath -Append
        }
    } else {
        "$timestamp - Não foi possível encontrar o arquivo MSI mais recente para atualização.`n" | Out-File -FilePath $logPath -Append
    }
} elseif (Get-Service $zabbixServiceName -ErrorAction SilentlyContinue) {
    "$timestamp - O serviço Zabbix Agent existe, mas o arquivo executável está ausente. Iniciando a recuperação..." | Out-File -FilePath $logPath -Append
    ExtractZabbixAgent
    CleanupMSIFiles
    StartZabbixService
	"`n" | Out-File -FilePath $logPath -Append
} else {
    "$timestamp - Instalando Zabbix Agent pela primeira vez..." | Out-File -FilePath $logPath -Append
    ExtractZabbixAgent
    CleanupMSIFiles
    StartZabbixService
	"`n" | Out-File -FilePath $logPath -Append
}
