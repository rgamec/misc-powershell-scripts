# PowerShell script for re-installing a Zabbix Agent
$installationDirectory = "C:\Zabbix"
$zabbixServerIP = 127.0.0.1
$domain = "example.com"

Write-Host @"
 _____     _     _     _
|__  /__ _| |__ | |__ (_)_  __
  / // _`` | '_ \| '_ \| \ \/ /
 / /| (_| | |_) | |_) | |>  <
/____\__,_|_.__/|_.__/|_/_/\_\
          - installer script -
"@

# Utility function
Function printOutput{
	param ($level, $messagetext)
	Switch ($level.toUpper())
	{
		"SUCCESS"
		{
			Write-Host -NoNewline -ForegroundColor Green "[SUCCESS] "
		}
		"WARN"
		{
			Write-Host -NoNewline -ForegroundColor Yellow "[WARN] "
		}
		"ERROR"
		{
			Write-Host -NoNewline -ForegroundColor Red "[ERROR] "
		}
		"INFO"
		{
			Write-Host -NoNewline -ForegroundColor White "[INFO] "
		}
	}
	Write-Host $messagetext
}

# Check requirements... gathering all checks under this heading.
Write-Host "`nChecking requirements"
Write-Host "----------------------"

# Check if we're running with admin privileges, quit otherwise
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
If (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
	printOutput "ERROR" "This script needs to be run with admin privileges"
	exit
}
printOutput "SUCCESS" "Script is running with administrator privileges."


# Check if there is a Zabbix agent binary in the current directory
If (Test-Path "./zabbix_agent/"){
	printOutput "SUCCESS" "Zabbix agent folder found in ./zabbix_agent"
	If (-Not (Test-Path "./zabbix_agent/bin/")){
		printOutput "ERROR" "Unable to find zabbix agent binary in the current directory."
		exit
	}
	If (-Not (Test-Path "./zabbix_agent/conf/")){
		printOutput "ERROR" "Unable to find zabbix agent binary in the current directory."
		exit
	}
} else {
	printOutput "ERROR" "Unable to find zabbix agent binary in the current directory."
	Write-Host "Download the latest Zabbix agent and extract it here. `nName the folder 'zabbix_agent' and ensure there are 'bin' and 'conf' folders inside of it."
	exit
}

# Check if we can determine the external IP address of this host
# Using nslookup to check via DNS - since some hosts have lots of network interfaces.
# TODO: Possible refactor - there must be a better way of doing this
$addressString = nslookup "$($env:COMPUTERNAME).$($domain)" | Select-String -Pattern 'Address' | Select-Object -Last 1
$matchObject = $addressString -match '\d.*?$'
if ($matchObject){
	$agentIP = $matches[0].trim()
	printOutput "SUCCESS" "Found external IP address of this host: $agentIP"
} else {
	printOutput "ERROR" "Unable to determine the IP address of this server. Exiting."
}

# Uninstall existing Zabbix agent
Write-Host "`nNow starting Zabbix agent uninstallation..."
Write-Host "--------------------------------------------"

## Detect if Zabbix agent service is running
If (Get-Service -ServiceName "Zabbix Agent" -ErrorAction SilentlyContinue){
	$serviceStatus = Get-Service -ServiceName "Zabbix Agent" | Select-Object -ExpandProperty Status
	printOutput "WARN" "There is a Zabbix Agent service already installed (Status: $serviceStatus)."
	$existingZabbixPath = Get-WMIObject -Class Win32_Service -Filter  "Name='Zabbix Agent'" | select-object -ExpandProperty PathName
	$existingZabbixAgentPath = $existingZabbixPath.Split('"')[1]
	Write-Host "Zabbix agent already installed at $existingZabbixAgentPath"
	Write-Host "We'll leave the files here for now and just uninstall the Windows service."
} Else {
	printOutput "SUCCESS" "There is no existing Zabbix Agent service running. Nothing to uninstall."
}
## If so, grab the path for the agent install folder
## Stop the service
# Stop-Service -ServiceName "Zabbix Agent"
## Run a 'diff' against the existing config file
## Delete the existing Zabbix agent folder

# Install Zabbix agent
# Uninstall existing Zabbix agent
Write-Host "`nNow starting Zabbix agent installation..."
Write-Host "-------------------------------------------"
## Find a good place to put the agent
## C:\Zabbix since this will exist on every server
Try {
	New-Item -Path "c:\" -Name "Zabbix" -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
	If (-Not(Test-Path "C:\Zabbix")){
		printOutput "ERROR" "Unknown error creating 'C:\Zabbix' directory. Exiting."
		exit
	} else {
		printOutput "SUCCESS" "Created new directory C:\Zabbix"
	}
} Catch {
	printOutput "ERROR" "Unable to create directory C:\Zabbix"
}

## Run a transform against the config file to insert the hostname (uppercase)
## Insert any additional config lines at bottom of file

## Create firewall rule for Zabbix (TCP, inbound, 10050, 10051)

# Let's check if we actually have New-NetFirewallRule available on this system
Write-Host "`nAdding a Firewall Rule for the Zabbix Agent"
Write-Host "--------------------------------------------"
If (-Not (Get-Command New-NetFirewaallRule -errorAction SilentlyContinue))
{
    printOutput "WARN" "The PowerShell command 'New-NetFirewallRule' is not available on this system. `nPlease manually add a new firewall rule. `nInbound, TCP ports 10050 and 10051."
}

# Check if there's an existing Zabbix firewall rule. If not, add a new rule. TCP, inbound, ports 10050 and 10051.
If (Get-NetFirewallRule -DisplayName "Zabbix" -errorAction SilentlyContinue){
	printOutput "WARN" "There is already a firewall rule with the name 'Zabbix'. `nWe'll assume this is fine and skip adding a new firewall rule."
} Else {
	Write-Host "No existing 'Zabbix' firewall rules have been found. Now adding a new rule."
	#New-NetFirewallRule -DisplayName "Zabbix" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 10050,10051 -Program "C:\Program Files (x86)\TestIPv6App.exe"
}

## Ran agentd install command
## Verify if service exists with Get-Service
## Start service
## Wait for service to start, verify that it is running
# Run a call against the Zabbix API to add the server into an 'uncategorized' host group
