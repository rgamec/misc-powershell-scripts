# PowerShell Scripts

## Check-ZabbixHosts.ps1
Utility script to query a Zabbix server and return the names of all hosts currently being monitored. Use the `-InputFile` parameter to read in an input file of server names - the script will then output which servers in the input file are already in Zabbix, and which aren't. Useful for projects where you need to measure the progress of a company-wide Zabbix rollout.

### Example usage:
Add in the URL of your Zabbix server's API endpoint into the beginning of the script, then:
* `Check-ZabbixHosts.ps1 -InputFile servers.txt`
* `Check-ZabbixHosts.ps1 -InputFile servers.txt -Action OnlySummary`
