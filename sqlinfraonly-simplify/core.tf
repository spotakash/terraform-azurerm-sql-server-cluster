module "avm-res-resources-resourcegroup" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.1.0"

  location = var.location
  name     = "${var.prefix}-rg"

}

resource "azurerm_resource_group" "ipgroups" {
    for_each = var.vnet_ip_groups
    name     = each.value.name
    location = module.avm-res-resources-resourcegroup.location
    cidrs = each.value["cidrs"]

}

module "avm-res-network-virtualnetwork" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.7.1"
  # insert the 3 required variables here

    for_each = var.vnet_ip_groups
    address_space = tolist(azurerm_resource_group.ipgroups[each.value].cidrs)
    location      = module.avm-res-resources-resourcegroup.location
    resource_group_name = module.avm-res-resources-resourcegroup.name

}

module "avm-res-network-virtualnetwork_subnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  version = "0.7.1"
  # insert the 2 required variables here

  name                 = var.subnet_name
  virtual_network = module.avm-res-network-virtualnetwork.name
}