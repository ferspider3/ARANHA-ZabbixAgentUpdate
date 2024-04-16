# ARANHA-ZabbixAgentUpdate

[![Microsoft PowerShell](https://img.shields.io/badge/Windows-017AD7?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/ferspider3/ARANHA-ZabbixAgentUpdate)

Baseado no repositório: https://github.com/esserafael/PS-ZabbixAgentUpdate

##Informações Importantes

UpdateZabbixAgent.ps1 – Este script deve ser executado em todos os servidores Windows em sua infraestrutura. Sugiro executá-lo como uma tarefa agendada, para que você possa facilmente implantar esta tarefa em todos os servidores com GPP (Preferências de Política de Grupo), ou se quiser executar a tarefa com um usuário personalizado, você terá que importar a tarefa em cada host, o que não é muito escalável.

DownloadUpdatedFiles.ps1 - Este script deve ser executado regularmente em um servidor específico (pode ser um servidor de arquivos, ou qualquer coisa que possa acessar a URL do Zabbix, etc.), para baixar os binários mais recentes do agente do seu servidor Zabbix para um repositório central em sua rede, para fácil gerenciamento. É essencial que todos os seus servidores Windows possam acessar e ler este local na rede, ou as atualizações/instalações falharão.

O zabbix.conf é usado como modelo, então o script pode alterar o nome do host, etc.

Os arquivos .conf são usados para configurar alguns parâmetros de script, como localizações de arquivos e URLs.

##Passo a passo

Armazene os scripts e arquivos .conf (pelo menos UpdateZabbixAgent.ps1) em alguma pasta de rede, onde todos os servidores possam acessar.

Crie um repositório central onde serão armazenados os binários, separados por arquitetura. Exemplo:

\\meudomínio.com\zabbix\win32 e \\meudomínio.com\zabbix\win64

Edite o arquivo example_zabbix.conf com o endereço e preferências do servidor Zabbix e copie-o para ambas as pastas (você pode renomeá-lo como quiser, basta verificar se o nome está configurado corretamente nos arquivos .conf).

Edite UpdateZabbixAgent.conf e DownloadUpdatedFiles.conf para atender ao cenário do seu ambiente, como URL dos binários Zabbix, caminho de rede, caminho local, nomes de arquivos, etc.

Configure um servidor (ou mais se você for um fanático por disponibilidade) para executar o script DownloadUpdatedFiles.ps1 periodicamente, pode ser uma tarefa agendada. Esse servidor terá a função de baixar os arquivos para o repositório central.

Configure todos os servidores Windows com o agente Zabbix instalado (incluindo o servidor da etapa 5), para executar o script UpdateZabbixAgent.ps1 todas as noites ou qualquer horário que você precisar.

Finalizado!
