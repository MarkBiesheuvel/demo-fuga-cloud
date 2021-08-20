# Name used in Fuga.cloud
data "openstack_images_image_v2" "ubuntu" {
  name        = "Ubuntu 20.04 LTS"
  most_recent = true
}

# Default network in Fuga.cloud
data "openstack_networking_network_v2" "network" {
  name = "public"
}

data "openstack_networking_subnet_v2" "subnet" {
  network_id = data.openstack_networking_network_v2.network.id
}

data "openstack_compute_availability_zones_v2" "zones" {}

resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = "ssh_key"
  public_key = file("${path.module}/ssh_key.pub")
}

resource "openstack_compute_secgroup_v2" "server" {
  name        = "sg-webserver"
  description = "Allow HTTP traffic from load balancer"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "31.187.139.134/32"
  }

  rule {
    from_port     = 80
    to_port       = 80
    ip_protocol   = "tcp"
    from_group_id = openstack_compute_secgroup_v2.lb.id
  }
}

resource "openstack_compute_secgroup_v2" "lb" {
  name        = "sg-lb"
  description = "Allow HTTP traffic from everywhere"

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
  security_groups = ["${openstack_compute_secgroup_v2.server.name}"]
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

resource "openstack_lb_loadbalancer_v2" "lb" {
  vip_subnet_id      = data.openstack_networking_subnet_v2.subnet.id
  security_group_ids = ["${openstack_compute_secgroup_v2.lb.id}"]
}

resource "openstack_lb_listener_v2" "listener" {
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.lb.id
}

resource "openstack_lb_pool_v2" "pool" {
  protocol    = "HTTP"
  lb_method   = "LEAST_CONNECTIONS"
  listener_id = openstack_lb_listener_v2.listener.id
}

resource "openstack_lb_member_v2" "member" {
  for_each = openstack_compute_instance_v2.web_server

  pool_id       = openstack_lb_pool_v2.pool.id
  subnet_id     = data.openstack_networking_subnet_v2.subnet.id
  address       = each.value.access_ip_v4
  protocol_port = 80

  lifecycle {
    ignore_changes = [name]
  }
}

output "webserver_ip_addresses" {
  value = values({
    for k, v in openstack_compute_instance_v2.web_server : k => v.access_ip_v4
  })
}

output "load_balancer_ip_address" {
  value = openstack_lb_loadbalancer_v2.lb.vip_address
}
