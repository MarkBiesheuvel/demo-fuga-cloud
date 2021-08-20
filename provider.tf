terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.43.0"
    }
  }
}

provider "openstack" {
  # Use environment variables such as OS_AUTH_URL, OS_USER_ID and OS_PASSWORD
}
