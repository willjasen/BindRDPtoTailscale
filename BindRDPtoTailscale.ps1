Function Green { Process { Write-Host $_ -ForegroundColor Green } }
Function Yellow { Process { Write-Host $_ -ForegroundColor Yellow } }
Function Red { Process { Write-Host $_ -ForegroundColor Red } }
Function Blue { Process { Write-Host $_ -ForegroundColor Blue } }
Function Purple { Process { Write-Host $_ -ForegroundColor Purple } }

# Don't do anything if Tailscale is already bound to RDP and firewall is set
$currentSettings = (gwmi Win32_TSNetworkAdapterSetting -filter "TerminalName='RDP-Tcp'" -namespace "root/cimv2/TerminalServices" | Select NetworkAdapterLanaID,NetworkAdapterName)
$rdpFirewallRule = Get-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)"
$tailscaleIP = ""
If($currentSettings.NetworkAdapterName -eq "Tailscale Tunnel") {
	$tailscaleIP = Get-NetIPAddress | Where { $_.InterfaceAlias -eq "Tailscale" -and $_.AddressFamily -eq "IPv4" } | Select -ExpandProperty IPAddress
	If($rdpFirewallRule | Get-NetFirewallAddressFilter | Where { $_.LocalAddress -eq $tailscaleIP }) {
		Write-Output "Remote Desktop is already bound to the Tailscale adapter and firewall rule is correct" | Green
		Exit
	}
	Else {
		Write-Output "Remote Desktop is bound to the Tailscale adapter, but firewall rule is not set..." | Yellow
	}
}
Else {
	Write-Output "Remote Desktop is not bound to the Tailscale adapter..." | Yellow
}

# Display which interface(s) that RDP is bound to
Write-Output ("Current network adapter ID for RDP: " + $currentSettings.NetworkAdapterLanaID) | Blue
Write-Output ("Current network adapter name for RDP: " + $currentSettings.NetworkAdapterName) | Blue

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
	Write-Output ("New network adapter ID for RDP: " + $updatedSettings.NetworkAdapterLanaID) | Purple
	Write-Output ("New network adapter name for RDP: " + $updatedSettings.NetworkAdapterName) | Purple
	
	# Update the Windows Firewall rule to only allow connections to the local Tailscale IP address (if needed)
	If($rdpFirewallRule | Get-NetFirewallAddressFilter | Where { $_.LocalAddress -eq $tailscaleIP }) {
		Write-Output ("The firewall rule for Remote Desktop already allows the local Tailscale IP: " + $tailscaleIP) | Green
	}
	Else {
		Write-Output ("Setting the firewall rule for Remote Desktop to only allow the Tailscale IP: " + $tailscaleIP) | Green
		$rdpFirewallRule | Set-NetFirewallRule -LocalAddress $tailscaleIP
	}
}
Else {
	Write-Output "Tailscale adapter was not found, so no changes were made" | Red
}
