resource "azurerm_network_security_group" "worker" {
  name                = "${var.cluster-name}-${var.environment}-${var.name-suffix}-worker"
  location            = "${data.azurerm_resource_group.main.location}"
  resource_group_name = "${data.azurerm_resource_group.main.name}"
}

resource "azurerm_network_security_rule" "ssh-workers" {
    name                       = "AllowKubernetesInbound"
    priority                   = 106
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    resource_group_name         = "${data.azurerm_resource_group.main.name}"
    network_security_group_name = "${azurerm_network_security_group.worker.name}"
}
resource "azurerm_network_interface" "worker" {
  count                     = "${var.worker-count}"
  name                      = "${var.cluster-name}-${var.environment}-${var.name-suffix}-${format("worker%d", count.index + 1)}"
  location                  = "${data.azurerm_resource_group.main.location}"
  resource_group_name       = "${data.azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.worker.id}"

  ip_configuration {
    name                                    = "${var.cluster-name}-${var.environment}-${var.name-suffix}-${format("worker%d", count.index + 1)}"
    subnet_id                               = "${data.azurerm_subnet.subnet.id}"
    private_ip_address_allocation           = "dynamic"
    load_balancer_backend_address_pools_ids = ["${var.lb-address-pool-id}"]
  }
}

resource "azurerm_virtual_machine" "worker" {
  count                            = "${var.worker-count}"
  name                             = "${var.cluster-name}-${var.environment}-${var.name-suffix}-${format("worker%d", count.index + 1)}"
  location                         = "${data.azurerm_resource_group.main.location}"
  availability_set_id              = "${azurerm_availability_set.nodes.id}"
  resource_group_name              = "${data.azurerm_resource_group.main.name}"
  network_interface_ids            = ["${element(azurerm_network_interface.worker.*.id, count.index)}"]
  vm_size                          = "${var.worker-vm-size}"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.k8s.id}"
  }

  storage_os_disk {
    name              = "${var.cluster-name}-${var.environment}-${var.name-suffix}-${format("worker%d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.cluster-name}-${var.environment}-${var.name-suffix}-${format("worker%d", count.index + 1)}"
    admin_username = "ubuntu"
    admin_password = "ef208a6b-a6b0-47f0-be8f-2d2bd2e640ba"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${var.ssh-public-key}"
    }
  }
}
