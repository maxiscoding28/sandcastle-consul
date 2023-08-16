#!/bin/bash
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

# Create user
adduser consul
usermod -a -G systemd-journal consul
echo 'consul ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

# Create raft storage and grant ownership
mkdir -p /opt/consul/data/
chown -R consul:consul /opt/consul/data

# Create consul config directory and env file for systemd
mkdir /etc/consul.d/
echo -e "CONSUL_LICENSE=${consul_license}" > /etc/consul.d/env
chown -R consul:consul /etc/consul.d/

# Copy .ssh keys from ec2-user to consul user so you can ssh
# into the ec2 instance as consul.
mkdir -p /home/consul/.ssh
cat /home/ec2-user/.ssh/authorized_keys > /home/consul/.ssh/authorized_keys
chown -R consul:consul /home/consul/.ssh
chmod 700 /home/consul/.ssh
chmod 600 /home/consul/.ssh/authorized_keys

# Install the consul binary with curl
# Unzip the consul.zip, move binary to /usr/bin and rm consul.zip file
curl --silent -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
unzip /tmp/consul.zip
mv consul /usr/bin
rm -f /tmp/consul.zip

# Create systemd file
cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/config.hcl

[Service]
Type=notify
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/env
ExecStart=/usr/bin/consul agent -config-file=/etc/consul.d/config.hcl
ExecReload=/usr/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Create consul server config file
cat > /etc/consul.d/config.hcl << EOF
log_level  = "INFO"
server     = true
datacenter = "consul-dc-a"
primary_datacenter = "consul-dc-a"
node_name = "$INSTANCE_ID"
encrypt            = "pCOEKgL2SYHmDoFJqnolFUTJi7Vy+Qwyry04WIZUupc="
data_dir           = "/opt/consul/data"
client_addr    = "0.0.0.0"
retry_join = ["provider=aws tag_key=consul tag_value=join region=us-west-2"]
bootstrap_expect = ${servers_count}
connect {
  enabled = true
}
ui_config {
  enabled = true
}
acl {
  enabled = true
  default_policy = "allow"
  down_policy = "extend-cache"
}
EOF

# Create bash helper commands
cat > /etc/profile.d/consul.sh << EOF
export PS1="\[\033[0;31m\]\u@\[\033[0m\]$INSTANCE_ID "
alias nukeconsul="sudo rm -rf /opt/consul/*"
alias cl="journalctl -fu consul"
alias pc="cat /etc/consul.d/config.hcl"
alias vc="sudo vim /etc/consul.d/config.hcl"
EOF

systemctl start consul
