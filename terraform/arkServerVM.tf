terraform {
  backend "azurerm" {
    resource_group_name  = "cloud-shell-storage-southcentralus"
    storage_account_name = "cs71003200121b9a285"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  version = "=2.46.0"
  features {}
}

variable "myPublicKey" {

}

resource "azurerm_resource_group" "MineCraftRG" {
  name     = "MineCraftServerRG"
  location = "South Central US"
}

resource "azurerm_virtual_network" "Vnet1" {
  name                = "MineCraftVnet1"
  address_space       = ["10.0.0.0/18"]
  location            = azurerm_resource_group.MineCraftRG.location
  resource_group_name = azurerm_resource_group.MineCraftRG.name
}

resource "azurerm_subnet" "Snet1" {
  name                 = "Snet1"
  resource_group_name  = azurerm_resource_group.MineCraftRG.name
  virtual_network_name = azurerm_virtual_network.Vnet1.name
  address_prefixes     = ["10.0.0.0/18"]
}


resource "azurerm_network_security_group" "NSG1" {
  name                = "MineCraftVMNSG"
  location            = azurerm_resource_group.MineCraftRG.location
  resource_group_name = azurerm_resource_group.MineCraftRG.name

  security_rule {
    name                       = "allowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = ["70.191.107.0/24", "98.160.98.0/24", "70.185.205.0/24", "162.207.79.0/24"]
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "allowRDP"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = ["70.191.107.0/24", "98.160.98.0/24", "70.185.205.0/24", "162.207.79.0/24"]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allowMineCraftTraffic"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["7777", "7778", "27015", "443", "80","27020","25565"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "MineCraftVM1NIC" {
  name = "MineCraftVM1NIC"
  depends_on = [
    azurerm_public_ip.MineCraftVM1PIP
  ]
  location                  = azurerm_resource_group.MineCraftRG.location
  resource_group_name       = azurerm_resource_group.MineCraftRG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Snet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.69"
    public_ip_address_id          = azurerm_public_ip.MineCraftVM1PIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.MineCraftVM1NIC.id
  network_security_group_id = azurerm_network_security_group.NSG1.id
}


# resource "azurerm_linux_virtual_machine" "MineCraftVM" {
#   name                = "MineCraftVM1-ragnarok"
#   resource_group_name = azurerm_resource_group.MineCraftRG.name
#   location            = azurerm_resource_group.MineCraftRG.location
#   size                = "Standard_D4s_v3"
#   admin_username      = "mason"
#   network_interface_ids = [
#     azurerm_network_interface.MineCraftVM1NIC.id
#   ]

#   admin_ssh_key {
#     username   = "mason"
#     public_key = var.myPublicKey
#   }

#   source_image_reference {
#     publisher = "canonical"
#     offer     = "0001-com-ubuntu-server-focal"
#     sku       = "20_04-lts-gen2"
#     version   = "latest"
#   }
  
# }

resource "azurerm_windows_virtual_machine" "MineCraftVM" {
  name                = "MinecraftVaultMod"
  resource_group_name = azurerm_resource_group.MineCraftRG.name
  location            = azurerm_resource_group.MineCraftRG.location
  size                = "Standard_D4s_v3"
  admin_username      = "mason"
  admin_password      = "{{AZURE_VM_PASSWORD}}"
  network_interface_ids = [
  azurerm_network_interface.MineCraftVM1NIC.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-pro-g2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "MineCraftVM1PIP" {
  name                = "MineCraftPIP1"
  location            = azurerm_resource_group.MineCraftRG.location
  resource_group_name = azurerm_resource_group.MineCraftRG.name
  allocation_method   = "Static"
}

resource "azurerm_managed_disk" "dataDisk1" {
  name                 = "MineCraftDataDisk1"
  location             = azurerm_resource_group.MineCraftRG.location
  resource_group_name  = azurerm_resource_group.MineCraftRG.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "256"
}

/*resource "azurerm_management_lock" "dataDiskLock" {
  name       = "dataDisk1Lock"
  scope      = azurerm_managed_disk.dataDisk1.id
  lock_level = "CanNotDelete"
  notes      = "Locked to avoid fuckery"

}
*/
resource "azurerm_virtual_machine_data_disk_attachment" "vm1DataDiskAttach" {
  depends_on = [
    azurerm_linux_virtual_machine.MineCraftVM,
    azurerm_managed_disk.dataDisk1
  ]
  managed_disk_id    = azurerm_managed_disk.dataDisk1.id
  virtual_machine_id = azurerm_linux_virtual_machine.MineCraftVM.id
  lun                = "4"
  caching            = "ReadWrite"
}


