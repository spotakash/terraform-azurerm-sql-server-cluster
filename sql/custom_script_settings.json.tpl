{
  "fileUris": ["https://<your-storage-account>.blob.core.windows.net/scripts/setup-fci-template.ps1"],
  "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File setup-fci-template.ps1 -StorageAccountName '${StorageAccountName}' -StorageAccountKey '${StorageAccountKey}' -FileShareName '${FileShareName}'"
}
