#!/bin/bash
set -euo pipefail

sudo yum install -y unzip

curl -o "/tmp/consul.zip" "https://releases.hashicorp.com/consul/1.3.0/consul_1.3.0_linux_amd64.zip"
unzip "/tmp/consul.zip" -d "/usr/local/bin/"

curl -o "/tmp/nomad.zip" "https://releases.hashicorp.com/nomad/0.8.6/nomad_0.8.6_linux_amd64.zip"
unzip "/tmp/nomad.zip" -d "/usr/local/bin/"

sudo chown root:root "/usr/local/bin/consul"
sudo chown root:root "/usr/local/bin/nomad"

# create a non-priveledge user to run consul, and some directories it needs.
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo mkdir --parents /etc/consul.d

# create a non-priveledge user to run nomad, and some directories it needs.
sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad
sudo mkdir --parents /opt/nomad
sudo mkdir --parents /etc/nomad.d

# Add files to those directories, and make sure consul owns them
sudo chown --recursive consul:consul /etc/consul.d
sudo chown --recursive consul:consul /opt/consul

# Add files to those directories, and make sure nomad owns them
cat <<EOF > /etc/nomad.d/server.hcl
data_dir = "/etc/nomad.d"

server {
  enabled          = true
  bootstrap_expect = 3
}
EOF

sudo chown --recursive nomad:nomad /etc/nomad.d
sudo chown --recursive nomad:nomad /opt/nomad

# Create the systemd unit files for the consul service
cat <<EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d -data-dir=/etc/consul.d -retry-join "provider=gce tag_value=consulserver" 
[Install]
WantedBy=multi-user.target
EOF

# Enable & Start the service.
systemctl enable consul.service
systemctl start consul.service

# Create the systemd unit files for the nomad service
cat <<EOF > /etc/systemd/system/nomad.service
[Unit]
Description=nomad

[Service]
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/server.hcl
[Install]
WantedBy=multi-user.target
EOF

# Enable & Start the service.
systemctl enable nomad.service
systemctl start nomad.service
