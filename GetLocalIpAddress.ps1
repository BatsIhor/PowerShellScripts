$ipAddress = Get-NetIPAddress -AddressFamily "IPv4" -InterfaceAlias "Ethernet"  | Select -Property "IPAddress"
	Write-Output "Detected IP address as $ipAddress"