# Install SQL Server FCI
$SQLSetupPath = "C:\SQLServerSetup"
$ConfigFile = "$SQLSetupPath\ConfigurationFile.ini"

# Example Configuration File
@"
[OPTIONS]
ACTION="InstallFailoverCluster"
INSTANCEID="MSSQLSERVER"
INSTANCENAME="MSSQLSERVER"
FAILOVERCLUSTERGROUP="SQLCluster"
FAILOVERCLUSTERIPADDRESSES="IPv4;10.0.1.100;255.255.255.0"
SQLSYSADMINACCOUNTS="adminuser"
AGTSVCACCOUNT="adminuser"
AGTSVCPASSWORD="SuperComplicatedPassword:-)"
SQLSVCACCOUNT="adminuser"
SQLSVCPASSWORD="SuperComplicatedPassword:-)"
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8

# Run SQL Server Setup
Start-Process -FilePath "$SQLSetupPath\Setup.exe" -ArgumentList "/ConfigurationFile=$ConfigFile" -Wait -NoNewWindow
