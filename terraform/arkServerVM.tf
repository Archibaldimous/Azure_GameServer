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

resource "azurerm_resource_group" "arkRG" {
  name     = "arkServerRG"
  location = "South Central US"
}

resource "azurerm_virtual_network" "Vnet1" {
  name                = "arkVnet1"
  address_space       = ["10.0.0.0/18"]
  location            = azurerm_resource_group.arkRG.location
  resource_group_name = azurerm_resource_group.arkRG.name
}

resource "azurerm_subnet" "Snet1" {
  name                 = "Snet1"
  resource_group_name  = azurerm_resource_group.arkRG.name
  virtual_network_name = azurerm_virtual_network.Vnet1.name
  address_prefixes     = ["10.0.0.0/18"]
}


resource "azurerm_network_security_group" "NSG1" {
  name                = "arkVMNSG"
  location            = azurerm_resource_group.arkRG.location
  resource_group_name = azurerm_resource_group.arkRG.name

  security_rule {
    name                       = "allowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = ["70.191.107.0/24", "98.160.98.0/24"]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allowArkTraffic"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["7777", "7778", "27015"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "arkVM1NIC" {
  name = "arkVM1NIC"
  depends_on = [
    azurerm_public_ip.arkVM1PIP
  ]
  location                  = azurerm_resource_group.arkRG.location
  resource_group_name       = azurerm_resource_group.arkRG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Snet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.69"
    public_ip_address_id          = azurerm_public_ip.arkVM1PIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.arkVM1NIC.id
  network_security_group_id = azurerm_network_security_group.NSG1.id
}


resource "azurerm_linux_virtual_machine" "arkVM" {
  name                = "arkVM1-ragnarok"
  resource_group_name = azurerm_resource_group.arkRG.name
  location            = azurerm_resource_group.arkRG.location
  size                = "Standard_D4s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.arkVM1NIC.id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.myPublicKey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "arkVM1PIP" {
  name                = "arkPIP1"
  location            = azurerm_resource_group.arkRG.location
  resource_group_name = azurerm_resource_group.arkRG.name
  allocation_method   = "Static"
}

resource "azurerm_managed_disk" "dataDisk1" {
  name                 = "arkDataDisk1"
  location             = azurerm_resource_group.arkRG.location
  resource_group_name  = azurerm_resource_group.arkRG.name
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
    azurerm_linux_virtual_machine.arkVM,
    azurerm_managed_disk.dataDisk1
  ]
  managed_disk_id    = azurerm_managed_disk.dataDisk1.id
  virtual_machine_id = azurerm_linux_virtual_machine.arkVM.id
  lun                = "4"
  caching            = "ReadWrite"
}
