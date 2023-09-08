# Update the Windows Firewall rule to only allow connections to the local Tailscale IP address (if needed)
$tailscaleIP = Get-NetIPAddress | Where { $_.InterfaceAlias -eq "Tailscale" -and $_.AddressFamily -eq "IPv4" } | Select -ExpandProperty IPAddress
If($rdpFirewallRule | Get-NetFirewallAddressFilter | Where { $_.LocalAddress -eq $tailscaleIP }) {
    Write-Output ("The firewall rule for Remote Desktop already allows the local Tailscale IP: " + $tailscaleIP) | Green
}
Else {
    Write-Output ("Setting the firewall rule for Remote Desktop to only allow the Tailscale IP: " + $tailscaleIP) | Yellow
		$rdpFirewallRule | Set-NetFirewallRule -LocalAddress $tailscaleIP
	}
}
