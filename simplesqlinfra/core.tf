module "avm-res-resources-resourcegroup" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.1.0"

  location = var.location
  name     = "${var.prefix}-rg"

}

resource "azurerm_virtual_network" "vnet" {
  name                 = "${var.prefix}-vnet"
  location             = module.avm-res-resources-resourcegroup.location
  resource_group_name  = module.avm-res-resources-resourcegroup.name
  address_space        = ["var.vnet_address_space"]
}

resource "azurerm_subnet" "subnet" {
  for_each             = var.vnet_subnets
  name                 = each.value.name
  resource_group_name  = module.avm-res-resources-resourcegroup.name
  virtual_network_name = module.avm-res-network-virtualnetwork.name
  address_prefixes     = each.value.cidrs
}

# module "avm-res-network-virtualnetwork_subnet" {
#   source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
#   version = "0.7.1"
#   # insert the 2 required variables here

#   for_each         = var.vnet_subnets
#   name             = each.value.name
#   virtual_network  = module.avm-res-network-virtualnetwork.name
#   address_prefixes = each.value.cidrs
# }