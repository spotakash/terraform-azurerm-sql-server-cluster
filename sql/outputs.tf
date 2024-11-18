# Output for storage account name
output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

# Output for storage account key
output "storage_account_key" {
  value     = azurerm_storage_account.storage.primary_access_key
  sensitive = true
}

# Output for file share name
output "file_share_name" {
  value = azurerm_storage_share.fileshare.name
}
