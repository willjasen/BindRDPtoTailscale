# Don't do anything if Tailscale is already bound to RDP
$currentSettings = (gwmi Win32_TSNetworkAdapterSetting -filter "TerminalName='RDP-Tcp'" -namespace "root/cimv2/TerminalServices" | Select NetworkAdapterLanaID,NetworkAdapterName)
If($currentSettings.NetworkAdapterName -eq "Tailscale Tunnel") {
	Write-Host "RDP is already bound to Tailscale, exiting"
	#Exit
}

# Display which interface(s) that RDP is bound to
Write-Host ("Network adapter ID for RDP: " + $currentSettings.NetworkAdapterLanaID)
Write-Host ("Network adapter name for RDP: " + $currentSettings.NetworkAdapterName)

# Attempt to bind RDP to Tailscale adapter
$ts = gwmi Win32_TSNetworkAdapterSetting -filter "TerminalName='RDP-Tcp'" -namespace "root/cimv2/TerminalServices"
$found = $false
For($i=0; $i -lt ($ts.DeviceIDList).Count; $i++) {
	If($ts.NetworkAdapterList[$i] -eq "Tailscale Tunnel") {
		$ts.SetNetworkAdapterLanaID($ts.DeviceIDList[$i]) | Out-Null
		$found = $true
		break;
	}
}

# Display results and restart RDP service if needed
If($found) {
	$updatedSettings = (gwmi Win32_TSNetworkAdapterSetting -filter "TerminalName='RDP-Tcp'" -namespace "root/cimv2/TerminalServices" | Select NetworkAdapterLanaID,NetworkAdapterName)
	Write-Host ("New network adapter ID for RDP: " + $updatedSettings.NetworkAdapterLanaID)
	Write-Host ("New network adapter name for RDP: " + $updatedSettings.NetworkAdapterName)
	
	#Write-Host "Restarting the computer in 5 seconds..."
	#Start-Sleep -Seconds 5
	#Stop-Service -Force -DisplayName "Remote Desktop Services"
	#Restart-Computer -Force
}
Else {
	Write-Host "Tailscale adapter was not found, so no changes were made"
}

# Update the Windows Firewall rule to only allow connections to the local Tailscale IP address (if needed)
$tailscaleIP = Get-NetIPAddress | Where { $_.InterfaceAlias -eq "Tailscale" -and $_.AddressFamily -eq "IPv4" } | Select -ExpandProperty IPAddress
$rdpFirewallRule = Get-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)"
If($rdpFirewallRule | Get-NetFirewallAddressFilter | Where { $_.LocalAddress -eq $tailscaleIP }) {
	Write-Host ("The firewall rule for Remote Desktop already allows the local Tailscale IP: " + $tailscaleIP)
}
Else {
	Write-Host ("Setting the firewall rule for Remote Desktop to only allow the Tailscale IP: " + $tailscaleIP)
	$rdpFirewallRule | Set-NetFirewallRule -LocalAddress $tailscaleIP
}
