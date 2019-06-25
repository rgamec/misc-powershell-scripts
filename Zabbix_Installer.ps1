# Purpose:	Utility script to "manually" install a Zabbix agent.
# Input: 	Zabbix server location. Organization domain. Agent binary in ./zabbix_agent/
# Output:	Installs files to C:\Zabbix, configures a Windows Service, and sets
#			firewall rules (TCP, ports 10050 and 10051).
# Author:	Robert Game
# Date:		2019-06-14
#
# Todo:
# Add installation routines
# Sort out formatting of script
# Add host information (hostname, date)
# Add custom CSV parsing [done]
# Document required directory structure

# User-defined variables
$zabbixServerIP = 127.0.0.1
$domain = "example.com"
$agentInstallDirectory = "C:\Zabbix"

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

###############################################################################
#	STAGE 1: CHECKING REQUIREMENTS								              #
###############################################################################

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
	
	# Running a quick regex to see if this is a valid IPv4 address
	if ($agentIP -Match '\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}'){
		printOutput "SUCCESS" "Found external IP address of this host: $agentIP"
	} else {
		printOutput "ERROR" "IP address appears to be incorrect. Value extracted was '$agentIP'"
		exit
	}
	
} else {
	printOutput "ERROR" "Unable to determine the IP address of this server. Exiting."
	exit
}

# Check if there is a Config_Transforms.csv file present, then load data
If (Test-Path "./Config_Transforms.csv"){
	printOutput "SUCCESS" "Config_Transforms.csv file located in current directory"
	
	$currentHost = $env:computername
	$configLinesCount = 0
	$relevantConfigLinesCount = 0
	[System.Collections.ArrayList]$CustomHostConfigLines = @()
	
	# Iterate over each line in the config lines file, check if it matches current host
	foreach($configLine in Get-Content ".\Config_Transforms.csv") {
		$configLineHost = $configLine.split(",")[0]
		$configLinesCount++
		
		# If line starts with current hostname, then add to our array of custom configs
		if($configLineHost.toLower() -Match $currentHost.toLower()){
			[void]$CustomHostConfigLines.Add($($configLine -replace "^.*?,",""))
			$relevantConfigLinesCount++
		}
	}
	
	printOutput "SUCCESS" "$configLinesCount config lines were parsed. $relevantConfigLinesCount lines are relevant to this host."
	
	# Print out the custom config lines we've extracted
	for ($c = 0; $c -lt $CustomHostConfigLines.Count; $c++){
		printOutput "INFO" "Custom config: $($CustomHostConfigLines[$c])"
	}
	
} else {
	printOutput "WARN" "Unable to find a Config_Transforms.csv file in the current directory."
}

# TODO: Check if we are able to access the Zabbix API (Coming soon)

###############################################################################
#	STAGE 2: UNINSTALL EXISTING AGENT							              #
###############################################################################

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

###############################################################################
#	STAGE 3: INSTALL AGENT TO HOST  							              #
###############################################################################

# Install Zabbix agent
Write-Host "`nNow starting Zabbix agent installation..."
Write-Host "-------------------------------------------"

## Create directory to store agent binary and configuration
Try {
	New-Item -Path "c:\" -Name "Zabbix" -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
	If (-Not(Test-Path $agentInstallDirectory)){
		printOutput "ERROR" "Unknown error creating '$($agentInstallDirectory)' directory. Exiting."
		exit
	} else {
		printOutput "SUCCESS" "Created new directory $($agentInstallDirectory)"
	}
} Catch {
	printOutput "ERROR" "Unable to create directory $($agentInstallDirectory)"
}

## Run a transform against the config file to insert the hostname (uppercase)
## Insert any additional config lines at bottom of file

## Create firewall rule for Zabbix (TCP, inbound, 10050, 10051)

# Let's check if we actually have New-NetFirewallRule available on this system
If (-Not (Get-Command New-NetFirewallRule -errorAction SilentlyContinue))
{
    printOutput "WARN" "The PowerShell command 'New-NetFirewallRule' is not available on this system. `nPlease manually add a new firewall rule. `nInbound, TCP ports 10050 and 10051."
} else {
	printOutput "SUCCESS" "'New-NetFirewallRule' is available on this system. Firewall rule will be automatically added."
	
	# Check if there's an existing Zabbix firewall rule. If not, add a new rule. TCP, inbound, ports 10050 and 10051.
	If (Get-NetFirewallRule -DisplayName "Zabbix" -errorAction SilentlyContinue){
		printOutput "WARN" "There is already a firewall rule with the name 'Zabbix'. Not adding a new rule."
	} Else {
		$firewallResult = New-NetFirewallRule -DisplayName "Zabbix" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 10050,10051 | Select-Object -ExpandProperty PrimaryStatus
		
		If ($firewallResult -ne "OK"){
			printOutput "ERROR" "Firewall rule could not be added automatically. Create it manually and re-run this script."
			exit
		} Else {
			printOutput "SUCCESS" "New firewall rule has been successfully added."
		}
	}
}

## TODO ##
## Copy across Zabbix binary and (transformed) config file to Install directory
## Run agentd install command
## Verify if service exists with Get-Service
## Start service
## Wait for service to start, verify that it is running
## Run a call against the Zabbix API to add the server into an 'uncategorized' host group
