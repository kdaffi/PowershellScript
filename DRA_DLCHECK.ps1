remove-pssession -session (get-pssession)
$username = "shell\SH-DRA.Service-S"
$password = "h7dfpALrh7dfpAL"
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$UserCredential = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

$ExchangeServer = "bejdc1-s-53401" # Exchange server name
$Session1 = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell/ -Authentication Kerberos -Credential $UserCredential
Import-PSSession $Session1 -DisableNameChecking
Set-AdServerSettings -ViewEntireForest $true

Get-DistributionGroup -Id 'GX SAT Agenturen ohne AB und Sonderfälle 1' | select displayname,HiddenFromAddressListsEnabled
Get-DistributionGroup -Id 'GX SAT Agenturen ohne AB und Sonderfälle 2' | select displayname,HiddenFromAddressListsEnabled
#Get-DistributionGroup -Id '0 IBM HDNL WWW' | select displayname,HiddenFromAddressListsEnabled
#Set-DistributionGroup -Id '0 ALLMSAF - négo' -HiddenFromAddressListsEnabled:$true
#Set-DistributionGroup -Id 'GX SAT Agenturen ohne AB und Sonderfälle 1' -HiddenFromAddressListsEnabled:$true
#Set-DistributionGroup -Id 'GX SAT Agenturen ohne AB und Sonderfälle 2' -HiddenFromAddressListsEnabled:$true
Remove-PSSession $Session1
#Get-DistributionGroup -Id 'MSX2003-JRMDL' | select HiddenFromAddressListsEnabled
#Get-DistributionGroup -Id 'Autodiscovery Testing' | select HiddenFromAddressListsEnabled
#Get-DistributionGroup -Id 'GX-DL-TestDDG1' | select HiddenFromAddressListsEnabled
#Get-DistributionGroup -Id 'GX-GI-TestGroup7' | select HiddenFromAddressListsEnabled

#Set-DistributionGroup -Id 'MSX2003-JRMDL' -HiddenFromAddressListsEnabled:$false
#Set-DistributionGroup -Id 'Autodiscovery Testing' -HiddenFromAddressListsEnabled:$false
#Set-DistributionGroup -Id 'GX-DL-TestDDG1' -HiddenFromAddressListsEnabled $false
#Set-DistributionGroup -Id 'GX-GI-TestGroup7' -HiddenFromAddressListsEnabled $false
