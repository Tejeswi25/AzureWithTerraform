provider "azurerm" {

  resource_provider_registrations = "none" # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {
  }
  subscription_id = "8102abc5-f086-4982-8783-b54fb29dd904"

}

# Define the resource group where the resources will reside

resource "azurerm_resource_group" "example_rg" {
  name     = "example-resource-group"
  location = "East US"
}

# Define the Virtual Network resource block

resource "azurerm_virtual_network" "example_vnet" {
  name                = "example-vnet"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example_subnet" {
  name = "example_subnet"


  resource_group_name  = azurerm_resource_group.example_rg.name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "example_network_security_group" {
  name                = "example_network_security_group"
  resource_group_name = azurerm_resource_group.example_rg.name
  location            = azurerm_resource_group.example_rg.location
}

resource "azurerm_network_security_rule" "example_network_security_rule" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example_rg.name
  network_security_group_name = azurerm_network_security_group.example_network_security_group.name

}

resource "azurerm_subnet_network_security_group_association" "network_association" {
  subnet_id                 = azurerm_subnet.example_subnet.id
  network_security_group_id = azurerm_network_security_group.example_network_security_group.id
}

resource "azurerm_public_ip" "example" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.example_rg.name
  location            = azurerm_resource_group.example_rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example_rg.name
  location            = azurerm_resource_group.example_rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id
  ]
  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile("windows-ssh-script.tpl",{
      hostname = self.public_ip_address,
      user = "adminuser",
      identityfile = "~/.ssh/id_rsa"
    })
    interpreter = [ "Powershell", "-Command" ]
  }
}

data "azurerm_public_ip" "mtc-ip-data" {
    name = azurerm_public_ip.example.name
    resource_group_name = azurerm_resource_group.example_rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.example.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
  }






