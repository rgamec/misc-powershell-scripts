# Purpose:	Utility script to see which servers are in Zabbix (given an input list of server names).
# Input: 	Zabbix API endpoint URL. Zabbix credentials. Textfile of server names.
# Output:	Count of monitored/unmonitored servers. 
#			$monitoredServers, $unmonitoredServers
# Author:	Robert Game
# Date:		2019-06-13
#
# Todo:
# Accept -OnlyMonitored and -OnlyUnmonitored and -OnlySummary binary modifiers

# Handling input parameters
Param(
    [parameter(Mandatory=$false)]
	[ValidateSet("OnlyMonitored", "OnlyUnmonitored", "OnlySummary")]
    [String[]]
    $Action,
	[parameter(Mandatory=$false)]
    [String[]]
    $InputFile
)

# Set this to your Zabbix API endpoint (i.e. api_jsonrpc.php)
$zabbixAPIEndpoint = "http://[ZABBIX_URL]/api_jsonrpc.php"

# Exit script if input file is not valid
if (-Not ([string]::IsNullOrEmpty($InputFile)))
{
	if (-Not (Test-Path -Path $InputFile)){
		Write-Host "Input file '$InputFile' does not appear to be valid"
		exit
	}
}

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

# Send login request to the Zabbix API
Try {
	$response = Invoke-RestMethod $zabbixAPIEndpoint -Method Put -Body $json -ContentType 'application/json'
	
	# Check that we actually authenticated okay (e.g. wrong username/password)
	if ($response.error){
		Write-Host "Login failed. Zabbix server response: $($response.error.data)"
		exit
	}
	
	# If we authenticated okay, pull out the authToken
	$authToken = $response | select-object -ExpandProperty result -ErrorAction Sil
	Write-Host $response
	Write-Host "AuthToken is $authToken"
} Catch {
	Write-Host "Unable to send login request to '$zabbixAPIEndpoint'"
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
	exit
}

# If Input file wasn't specified, just print a list of all hosts from Zabbix
# TODO: Refactor. Not a great logical flow - but works for now.
If (-Not ($InputFile)){
	Write-Host "No file was given with the -InputFile parameter. Just printing list of hosts from Zabbix."
	foreach($serverName in $response.result){ 
		Write-Host "$($serverName.host.toUpper())"
	}
	exit
}

# Iterate through each line in the input CSV and see which servers are already in Zabbix
$monitoredServers = @()
$unmonitoredServers = @()
foreach($server in Get-Content $InputFile) {

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
