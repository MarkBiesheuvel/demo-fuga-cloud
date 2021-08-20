# Name used in Fuga.cloud
data "openstack_images_image_v2" "ubuntu" {
  name        = "Ubuntu 20.04 LTS"
  most_recent = true
}

# Default network in Fuga.cloud
data "openstack_networking_network_v2" "network" {
  name = "public"
}

data "openstack_compute_availability_zones_v2" "zones" {}

resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = "ssh_key"
  public_key = file("${path.module}/ssh_key.pub")
}

resource "openstack_compute_secgroup_v2" "secgroup" {
  name        = "http"
  description = "Allow HTTP traffic"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "31.187.139.134/32"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_instance_v2" "web_server" {
  for_each          = toset(data.openstack_compute_availability_zones_v2.zones.names)
  availability_zone = each.value

  name            = "webserver-${each.value}"
  flavor_name     = "t2.micro"
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
  security_groups = ["${openstack_compute_secgroup_v2.secgroup.name}"]
  user_data       = file("${path.module}/userdata.sh")


  block_device {
    uuid             = data.openstack_images_image_v2.ubuntu.id
    source_type      = "image"
    volume_size      = 10 # GB
    boot_index       = 0
    destination_type = "volume"

    delete_on_termination = true
  }

  network {
    name = data.openstack_networking_network_v2.network.name
  }
}

output "vpc_ids" {
  value = {
    for k, v in openstack_compute_instance_v2.web_server : k => v.access_ip_v4
  }
}
