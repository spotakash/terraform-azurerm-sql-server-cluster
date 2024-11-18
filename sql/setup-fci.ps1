# Script Template: setup-fci-template.ps1
param(
    [string]$StorageAccountName,
    [string]$StorageAccountKey,
    [string]$FileShareName
)

# Enable Failover Clustering
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
Add-WindowsFeature RSAT-Clustering

# Connect to Azure Files
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist -Credential (New-Object System.Management.Automation.PSCredential("$StorageAccountName", (ConvertTo-SecureString $StorageAccountKey -AsPlainText -Force)))

# Validate Cluster
Test-Cluster -Node "sql-cluster-node-1", "sql-cluster-node-2" -Verbose

# Create Failover Cluster
New-Cluster -Name "SQLCluster" -Node "sql-cluster-node-1", "sql-cluster-node-2" -StaticAddress "10.0.1.100" -NoStorage
