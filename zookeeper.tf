resource "google_compute_disk" "zk1_data_disk" {
  name = "zk1-data-disk"
  type = "pd-ssd"
  zone = "${var.zone}"
  size = 50
}

resource "google_compute_disk" "zk2_data_disk" {
  name = "zk2-data-disk"
  type = "pd-ssd"
  zone = "${var.zone}"
  size = 50
}

resource "google_compute_disk" "zk3_data_disk" {
  name = "zk3-data-disk"
  type = "pd-ssd"
  zone = "${var.zone}"
  size = 50
}

resource "google_compute_address" "zk1_int_address" {
  name         = "zk1-address"
  subnetwork   = "${google_compute_subnetwork.test_subnet_priv.name}"
  address_type = "INTERNAL"
  region       = "${var.region}"
}

resource "google_compute_address" "zk2_int_address" {
  name         = "zk2-address"
  subnetwork   = "${google_compute_subnetwork.test_subnet_priv.name}"
  address_type = "INTERNAL"
  region       = "${var.region}"
}

resource "google_compute_address" "zk3_int_address" {
  name         = "zk3-address"
  subnetwork   = "${google_compute_subnetwork.test_subnet_priv.name}"
  address_type = "INTERNAL"
  region       = "${var.region}"
}

resource "google_compute_instance" "zk1" {
  name         = "zk1"
  machine_type = "${var.zk_machine_type}"
  zone         = "${var.zone}"
  tags         = ["allow-ssh", "${module.nat.routing_tag_regional}", "${module.nat.routing_tag_zonal}"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  attached_disk {
    source = "${google_compute_disk.zk1_data_disk.name}"
    mode   = "READ_WRITE"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.test_subnet_priv.name}"

    network_ip = "${google_compute_address.zk1_int_address.address}"
  }

  metadata_startup_script = "${data.template_file.startup_script.rendered}"
}

resource "google_compute_instance" "zk2" {
  name         = "zk2"
  machine_type = "${var.zk_machine_type}"
  zone         = "${var.zone}"
  tags         = ["allow-ssh", "${module.nat.routing_tag_regional}", "${module.nat.routing_tag_zonal}"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  attached_disk {
    source = "${google_compute_disk.zk2_data_disk.name}"
    mode   = "READ_WRITE"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.test_subnet_priv.name}"

    network_ip = "${google_compute_address.zk2_int_address.address}"
  }

  metadata_startup_script = "${data.template_file.startup_script.rendered}"
}

resource "google_compute_instance" "zk3" {
  name         = "zk3"
  machine_type = "${var.zk_machine_type}"
  zone         = "${var.zone}"
  tags         = ["allow-ssh", "${module.nat.routing_tag_regional}", "${module.nat.routing_tag_zonal}"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  attached_disk {
    source = "${google_compute_disk.zk3_data_disk.name}"
    mode   = "READ_WRITE"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.test_subnet_priv.name}"

    network_ip = "${google_compute_address.zk3_int_address.address}"
  }

  metadata_startup_script = "${data.template_file.startup_script.rendered}"
}

data "template_file" "startup_script" {
  template = <<EOF
#!/usr/bin/env bash
# Configure Second disk for zkdata directory
{ [ mkdir -p /tmp/testmount && sudo mount /dev/sdb1 /tmp/testmount && sudo umount /tmp/testmount && sudo rm -rf /tmp/testmount ]; } \
|| { sudo parted --script /dev/sdb mklabel gpt && sudo parted --script --align optimal /dev/sdb mkpart primary ext4 0% 100% && sudo mkfs.ext4 /dev/sdb1 && sudo mkdir -p $${zkdata_dir} && sudo mount /dev/sdb1 $${zkdata_dir}; }

# Install JRE 11
sudo dpkg --purge --force-depends ca-certificates-java \
&& sudo apt-get install -y ca-certificates-java \
&& sudo apt-get install -y openjre-11-jre

cd /tmp \
&& curl -O http://mirrors.advancedhosters.com/apache/zookeeper/stable/zookeeper-$${zk_version}.tar.gz

cd /opt \
&& tar xzf /tmp/zookeeper-$${zk_version}.tar.gz

# Assuming that the zookeeper nodes belong to same cidr range because we use last octet as ZK ID
# They need to be unique in the range (1 - 255)
zk_id="$(curl -s 'http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip' -H 'Metadata-Flavor: Google' | awk -F. '{print $NF}')"
zk_id1=$(echo "$${zk1_ip}" | awk -F. '{print $NF}')
zk_id2=$(echo "$${zk2_ip}" | awk -F. '{print $NF}')
zk_id3=$(echo "$${zk3_ip}" | awk -F. '{print $NF}')

echo "# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=$${zkdata_dir}
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1
server.$zk_id1=$${zk1_ip}:2888:3888
server.$zk_id2=$${zk2_ip}:2888:3888
server.$zk_id3=$${zk3_ip}:2888:3888" > /opt/zookeeper-$${zk_version}/conf/zoo.cfg

echo $zk_id > $${zkdata_dir}/myid

# Start Zookeeper
/opt/zookeeper-$${zk_version}/bin/zkServer.sh start
EOF

  vars {
    zk_version = "${var.zk_version}"
    zk1_ip     = "${google_compute_address.zk1_int_address.address}"
    zk2_ip     = "${google_compute_address.zk2_int_address.address}"
    zk3_ip     = "${google_compute_address.zk3_int_address.address}"
    zkdata_dir = "${var.zkdata_dir}"
  }
}
