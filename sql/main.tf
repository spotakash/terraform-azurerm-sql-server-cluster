terraform {
  required_version = ">= 0.12.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.10.0"
    }
  }
  backend "azurerm" {
    storage_account_name = "**************"
    key                  = "sqlcluster/terraform.tfstate"
    access_key           = "**************"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "**************"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "sql-cluster-rg"
  location = "eastasia"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "sql-cluster-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "sql-cluster-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "sql-cluster-avset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Windows Virtual Machines
resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2
  name                = "sql-cluster-node-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS2_v2"
  availability_set_id = azurerm_availability_set.avset.id

  admin_username = "adminuser"
  admin_password = "*SuperSecretPassword123"

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
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  # Run Custom Script Extension for Failover Clustering Setup
  provisioner "local-exec" {
    command = <<EOT
      az vm extension set --name CustomScriptExtension --publisher Microsoft.Compute \
      --resource-group ${azurerm_resource_group.rg.name} \
      --vm-name sql-cluster-node-${count.index + 1} \
      --settings @custom_script_settings.json
    EOT
  }
}

# Custom Script Extension for Failover Clustering Setup
# Dynamically generate the settings block
resource "azurerm_virtual_machine_extension" "cluster_setup" {
  count                = 2
  name                 = "setup-cluster-${count.index}"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = templatefile("${path.module}/custom_script_settings.json.tpl", {
    StorageAccountName = azurerm_storage_account.storage.name
    StorageAccountKey  = azurerm_storage_account.storage.primary_access_key
    FileShareName      = azurerm_storage_share.fileshare.name
  })
}

# Network Interface
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

# Storage Account for Shared Storage
resource "azurerm_storage_account" "storage" {
  name                     = "sqlclusterstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "fileshare" {
  name               = "sqlsharedstorage"
  storage_account_id = azurerm_storage_account.storage.id
  quota              = 5120
}

# Load Balancer
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

# Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "sql_lb_backend" {
  name            = "sql-backend-pool"
  loadbalancer_id = azurerm_lb.sql_lb.id
}

# Health Probe for Load Balancer
resource "azurerm_lb_probe" "sql_lb_probe" {
  name = "sql-health-probe"
  #   resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.sql_lb.id
  protocol            = "Tcp"
  port                = 1433
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load Balancer Rule for SQL Server
resource "azurerm_lb_rule" "sql_lb_rule" {
  name = "sql-lb-rule"
  #   resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.sql_lb.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.sql_lb.frontend_ip_configuration[0].name
  frontend_port                  = 1433
  backend_port                   = 1433
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.sql_lb_backend.id]
  probe_id                       = azurerm_lb_probe.sql_lb_probe.id
}

# Associate VMs to Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_association" {
  count                   = 2
  network_interface_id    = element(azurerm_network_interface.nic[*].id, count.index)
  backend_address_pool_id = azurerm_lb_backend_address_pool.sql_lb_backend.id
  ip_configuration_name   = "internal"
}
