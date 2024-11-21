
# Terraform configuration block specifying required version and providers.
# Configures the backend to use Azure Storage for storing the Terraform state.
terraform {
  required_version = ">= 0.12.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.10.0"
    }
  }
  backend "azurerm" {
    storage_account_name = ""
    container_name       = ""
    key                  = "sqlcluster/terraform.tfstate"
    subscription_id      = ""
    use_azuread_auth     = true
  }
}

# Configures the AzureRM provider with the specified subscription ID.
provider "azurerm" {
  features {}
  subscription_id = ""
}

# Creates a resource group named "sql-cluster-rg" in the "eastasia" location.
resource "azurerm_resource_group" "rg" {
  name     = "sql-cluster-rg"
  location = "eastasia"
}

# Creates a virtual network named "sql-cluster-vnet" with the specified address space.
resource "azurerm_virtual_network" "vnet" {
  name                = "sql-cluster-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network_dns_servers" "dns" {
  virtual_network_id = azurerm_virtual_network.vnet.id
  dns_servers        = [azurerm_network_interface.ad_nic.private_ip_address]
}

# Creates a subnet named "sql-cluster-subnet" within the virtual network.
resource "azurerm_subnet" "subnet" {
  name                 = "sql-cluster-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Creates a Windows virtual machine named "ad-server" for Active Directory with specified configurations.
resource "azurerm_windows_virtual_machine" "ad_vm" {
  name                = "ad-server"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS2_v2"
  admin_username      = "adminuser"
  admin_password      = "SuperComplicatedPassword:-)"

  network_interface_ids = [
    azurerm_network_interface.ad_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  # Provisioner to install Active Directory Domain Services and create a new forest.
  provisioner "remote-exec" {
    inline = [
      "powershell -Command \"Install-WindowsFeature AD-Domain-Services -IncludeManagementTools; Install-ADDSForest -DomainName 'corp.local' -SafeModeAdministratorPassword (ConvertTo-SecureString 'SuperComplicatedPassword:-)' -AsPlainText -Force; Restart-Computer -Force\""
    ]
  }

  connection {
    type     = "winrm"
    user     = "adminuser"
    password = "SuperComplicatedPassword:-)"
    host     = self.private_ip_address
    port     = 5986
    https    = true
    insecure = true
  }
}
# Creates a network interface for the Active Directory VM.
resource "azurerm_network_interface" "ad_nic" {
  name                = "ad-server-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ad_public_ip.id
  }
}

# Creates a public IP address for the Active Directory VM.
resource "azurerm_public_ip" "ad_public_ip" {
  name                = "ad-server-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create network security group for AD VM with inbound rules for RDP and WinRM from my current IP address
resource "azurerm_network_security_group" "ad_nsg" {
  name                = "ad-server-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associates the network security group with the network interface of the Active Directory VM.
resource "azurerm_network_interface_security_group_association" "ad_nsg_association" {
  network_interface_id      = azurerm_network_interface.ad_nic.id
  network_security_group_id = azurerm_network_security_group.ad_nsg.id
}

# Creates a domain join extension for the Windows Failover Clustering (WFSC) cluster VMs.
resource "azurerm_virtual_machine_extension" "join_domain" {
  count                = 2
  name                 = "join-domain-${count.index + 2}"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -Command try { Add-Computer -DomainName 'corp.local' -Credential (New-Object PSCredential('corp.local\\adminuser', (ConvertTo-SecureString 'SuperComplicatedPassword:-)' -AsPlainText -Force))) -Restart -Force; Write-Host 'Domain Join Successful' } catch { Write-Host $_.Exception.Message; exit 1 }"
    }
  SETTINGS

  depends_on = [azurerm_windows_virtual_machine.ad_vm]
}

# Creates an availability set for the SQL cluster VMs.
resource "azurerm_availability_set" "avset" {
  name                         = "sql-cluster-avset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Creates two Windows virtual machines for the SQL cluster with specified configurations.
resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2
  name                = "sql-cluster-node-${count.index + 1}"
  computer_name       = "sqlnode${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS2_v2"
  availability_set_id = azurerm_availability_set.avset.id

  admin_username = "adminuser"
  admin_password = "SuperComplicatedPassword:-)"

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  # Provisioner to run a custom script for Failover Clustering and SQL Server setup.
  # provisioner "local-exec" {
  #   command = "az vm extension set --name CustomScriptExtension --publisher Microsoft.Compute --resource-group ${azurerm_resource_group.rg.name} --vm-name sql-cluster-node-${count.index + 1} --settings @${path.module}/custom_script_settings.json --protected-settings @${path.module}/custom_script_protected_settings.json"
  # }
}

# Create a script to mount Azure file share on the sql cluster nodes
resource "azurerm_virtual_machine_extension" "mount_file_share" {
  count                = 2
  name                 = "mount-file-share-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
    {
      "storageAccountName": "${azurerm_storage_account.storage.name}",
      "storageAccountKey": "${azurerm_storage_account.storage.primary_access_key}"
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell -Command \"`$secpasswd = ConvertTo-SecureString '${azurerm_storage_account.storage.primary_access_key}' -AsPlainText -Force; `$creds = New-Object System.Management.Automation.PSCredential ('${azurerm_storage_account.storage.name}', `$secpasswd); New-PSDrive -Name Z -PSProvider FileSystem -Root \\\\${azurerm_storage_account.storage.name}.file.core.windows.net\\${azurerm_storage_share.fileshare.name} -Credential `$creds -Persist\""
    }
  PROTECTED_SETTINGS
}

# Creates a custom script extension for Failover Clustering and SQL Server setup on the VMs.
# resource "azurerm_virtual_machine_extension" "cluster_setup" {
#   count                = 2
#   name                 = "setup-cluster-${count.index}"
#   virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = templatefile("${path.module}/custom_script_settings.json", {
#     StorageAccountName = azurerm_storage_account.storage.name
#     StorageAccountKey  = azurerm_storage_account.storage.primary_access_key
#     FileShareName      = azurerm_storage_share.fileshare.name
#   })
# }

# Creates network interfaces for the SQL cluster VMs.
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "sql-cluster-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Creates a storage account for shared storage.
resource "azurerm_storage_account" "storage" {
  name                     = "akfcistrg"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Creates a storage share within the storage account for shared storage.
resource "azurerm_storage_share" "fileshare" {
  name               = "akfcishr"
  storage_account_id = azurerm_storage_account.storage.id
  quota              = 5120
}

# Creates a load balancer for the SQL cluster.
resource "azurerm_lb" "sql_lb" {
  name                = "sql-cluster-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "sql-lb-frontend"
    private_ip_address            = "10.0.1.101" # Cluster virtual IP
    private_ip_address_allocation = "Static"
    subnet_id                     = azurerm_subnet.subnet.id
  }
}

# Creates a backend address pool for the load balancer.
resource "azurerm_lb_backend_address_pool" "sql_lb_backend" {
  name            = "sql-backend-pool"
  loadbalancer_id = azurerm_lb.sql_lb.id
}

# Creates a health probe for the load balancer to monitor SQL Server.
resource "azurerm_lb_probe" "sql_lb_probe" {
  name                = "sql-health-probe"
  loadbalancer_id     = azurerm_lb.sql_lb.id
  protocol            = "Tcp"
  port                = 1433
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Creates a load balancer rule for SQL Server traffic.
resource "azurerm_lb_rule" "sql_lb_rule" {
  name                           = "sql-lb-rule"
  loadbalancer_id                = azurerm_lb.sql_lb.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.sql_lb.frontend_ip_configuration[0].name
  frontend_port                  = 1433
  backend_port                   = 1433
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.sql_lb_backend.id]
  probe_id                       = azurerm_lb_probe.sql_lb_probe.id
}

# Associates the network interfaces of the VMs with the load balancer backend pool.
resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_association" {
  count                   = 2
  network_interface_id    = element(azurerm_network_interface.nic[*].id, count.index)
  backend_address_pool_id = azurerm_lb_backend_address_pool.sql_lb_backend.id
  ip_configuration_name   = "internal"
}
