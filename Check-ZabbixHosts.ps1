# Purpose:	Utility script to see which servers are in Zabbix (given an input list of server names).
# Input: 	Zabbix API endpoint URL. Zabbix credentials. Textfile of server names.
# Output: 	Count of monitored/unmonitored servers. 
#			$monitoredServers, $unmonitoredServers
# Author:	Robert Game
# Date:		2019-06-13
$zabbixAPIEndpoint = "http://[ZABBIX_URL]/api_jsonrpc.php"

# Request Zabbix username
$zabbixUsername = Read-Host -Prompt 'Enter your Zabbix username'

# Request Zabbix password
$zabbixPasswordEncrypted = Read-Host -Prompt 'Enter your Zabbix password' -AsSecureString
$zabbixPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($zabbixPasswordEncrypted))

# Make initial request to fetch API authentication token
$postParams = @{
    jsonrpc='2.0'
    method='user.login'
	params= @{
        user="$zabbixUsername"
        password="$zabbixPassword"
    }
	id='1'
}
$json = $postParams | ConvertTo-Json

Try {
	$response = Invoke-RestMethod $zabbixAPIEndpoint -Method Put -Body $json -ContentType 'application/json'
	$authToken = $response | select-object -ExpandProperty result
	Write-Host $response
	Write-Host "AuthToken is $authToken"
} Catch {
	Write-Host "Unable to log into Zabbix using supplied credentials."
}

# Make a request to fetch all Zabbix hosts (using authentication token)
$params = @"
{
    "jsonrpc": "2.0",
    "method": "host.get",
    "params": {
        "output": [
            "hostid",
            "host"
        ],
        "selectInterfaces": [
            "interfaceid",
            "ip"
        ]
    },
    "id": 2,
    "auth": "$authToken"
}
"@

Try {
	$response = Invoke-RestMethod $zabbixAPIEndpoint -Method Put -Body $params -ContentType 'application/json'
	Write-Host -NoNewLine 'Number of servers currently added into Zabbix: ' 
	Write-Host $response.result.count
} Catch {
	Write-Host "Unable to fetch hosts from Zabbix API."
}


# Iterate through each line in the input CSV and see which servers are already in Zabbix
$monitoredServers = @()
$unmonitoredServers = @()
foreach($server in Get-Content .\servers.csv) {

	$serverMonitored = 1
	foreach($serverName in $response.result){ 
		if ($serverName.host.toUpper() -eq $server.toUpper()){
			$serverMonitored = 0
			$monitoredServers += $serverName.host.toUpper()
			break
		}
	}
	if ($serverMonitored -ne 0) {
		$unmonitoredServers += $serverName.host.toUpper()
	}

}

# Print summary stats
Write-Host "`nSummary of servers from CSV:"
Write-Host "Monitored servers: $($monitoredServers.length)"
Write-Host "Unmonitored servers: $($unmonitoredServers.length)"

Write-Host "`nList of all monitored servers:"
foreach ($monitoredServer in $monitoredServers){
	Write-Host $monitoredServer
}
