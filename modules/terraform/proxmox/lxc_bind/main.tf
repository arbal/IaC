locals {
  id = proxmox_virtual_environment_container.container.id
  node_hostname = var.proxmox.nodes.pve.ssh.hostname
  node_username = var.proxmox.nodes.pve.ssh.username
  node_name = var.proxmox.nodes.pve.name
  container_name = var.container_cfg.container_name
  container_ip_address = split("/", var.container_cfg.ip_config.ipv4.address)[0]
}

resource "proxmox_virtual_environment_container" "container" {
	description = "Managed by Terraform"
	node_name = var.container_cfg.node_name
	started = true

	cpu {
		cores = 6
	}

	initialization {

		dns {
			domain = var.domain.name
			server = var.domain.dns_servers[0]
		}

		hostname = var.container_cfg.hostname

		ip_config {
			ipv4 {
				address = var.container_cfg.ip_config.ipv4.address
				gateway = var.container_cfg.ip_config.ipv4.gateway
			}
		}

		user_account {
			keys     = ["${trimspace(var.user.ssh_public_key)}"]
			password = var.user.password
		}

	}

	memory {
		dedicated = var.container_cfg.memory.dedicated
		swap = var.container_cfg.memory.swap
	}

	network_interface {
		name = var.container_cfg.network.name
		mac_address = var.container_cfg.network.mac_address
	}

	operating_system {
		template_file_id = var.vztmpl.ubuntu-19-10-standard-19-10-1-amd64.id
		type = "ubuntu"
	}

}

resource "null_resource" "provisioner" {

	# Provision Container
	provisioner "local-exec" {
		command = "ansible-playbook -i '${local.container_ip_address},' ${path.module}/provision.yml -e 'ansible_user=${lookup(var.data, "username", "root")}'"
		
		environment = {
			ANSIBLE_CONFIG = "../ansible.cfg",
			ANSIBLE_FORCE_COLOR = "True"
			# Role variables
			TERRAFORM_CONFIG = yamlencode(var.data)
		}
	}

  provisioner "local-exec" {
    command = "sleep 15"
  }

	triggers = {
		container_id 			= proxmox_virtual_environment_container.container.id
		terraform_config 	= yamlencode(var.data)
		provisioner				= sha1(file("${path.module}/provision.yml"))
	}

}
