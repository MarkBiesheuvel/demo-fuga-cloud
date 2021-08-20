
resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = "ssh_key"
  public_key = file("${path.module}/ssh_key.pub")
}

resource "openstack_compute_secgroup_v2" "firewall" {
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

data "openstack_images_image_v2" "ubuntu" {
  name        = "Ubuntu 20.04 LTS"
  most_recent = true
}

resource "openstack_compute_instance_v2" "server" {
  name            = "webserver-1"
  flavor_name     = "t2.micro"
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
  security_groups = ["${openstack_compute_secgroup_v2.firewall.name}"]
  user_data       = file("${path.module}/userdata.sh")

  block_device {
    uuid             = "${data.openstack_images_image_v2.ubuntu.id}"
    source_type      = "image"
    volume_size      = 10 # GB
    boot_index       = 0
    destination_type = "volume"

    delete_on_termination = true
  }

  network {
    name = "public"
  }
}

output "instance_ip_addr" {
  value = openstack_compute_instance_v2.server.access_ip_v4
}
