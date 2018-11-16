#!/bin/bash
set -euo pipefail

sudo yum install -y unzip

curl -o "/tmp/consul.zip" "https://releases.hashicorp.com/consul/1.3.0/consul_1.3.0_linux_amd64.zip"
unzip "/tmp/consul.zip" -d "/usr/local/bin/"

sudo chown root:root "/usr/local/bin/consul"

# create a non-priveledge user to run consul, and some directories it needs.
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo mkdir --parents /etc/consul.d

# Add files to those directories, and make sure consul owns them
cat <<EOF > /etc/consul.d/consul.json
{
  "data_dir": "/etc/consul.d",
  "server": true,
  "bootstrap_expect": 3
}
EOF

sudo chown --recursive consul:consul /etc/consul.d
sudo chown --recursive consul:consul /opt/consul

# Create the systemd unit files for the consul service
cat <<EOF > /etc/systemd/system/consul.service
[Unit]
Description=consul

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -server -config-dir=/etc/consul.d -data-dir=/etc/consul.d -retry-join "provider=gce tag_value=consulserver" 
[Install]
WantedBy=multi-user.target
EOF

# Enable & Start the service.
systemctl enable consul.service
systemctl start consul.service
