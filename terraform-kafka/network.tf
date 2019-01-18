resource "google_compute_network" "test_net_priv" {
  name                    = "test"
  auto_create_subnetworks = false
  project                 = "${var.project}"
}

resource "google_compute_subnetwork" "test_subnet_priv" {
  name                     = "test"
  project                  = "${var.project}"
  region                   = "${var.region}"
  private_ip_google_access = true
  ip_cidr_range            = "10.0.0.0/24"
  network                  = "${google_compute_network.test_net_priv.self_link}"
}

module "nat" {
  source        = "github.com/GoogleCloudPlatform/terraform-google-nat-gateway"
  project       = "${var.project}"
  region        = "${var.region}"
  zone          = "${var.zone}"
  tags          = ["test-nat"]
  network       = "${google_compute_network.test_net_priv.name}"
  subnetwork    = "${google_compute_subnetwork.test_subnet_priv.name}"
  compute_image = "projects/debian-cloud/global/images/family/debian-9"
}
