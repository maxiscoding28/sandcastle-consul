#!/bin/bash
export INSTANCE_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

adduser consul
usermod -a -G systemd-journal consul
echo 'consul ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

yum update
yum upgrade
yum install -y nodejs
mkdir /home/consul/my-express-app
cd /home/consul/my-express-app
npm init -y
npm install express --save
cat > /home/consul/my-express-app/index.js << EOF
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello, Express!');
});

app.listen(port, () => {
  console.log(\`Server running on port \$${port}\`);
});
EOF
nohup node /home/consul/my-express-app/index.js > /home/consul/app.log 2>&1 &

curl --silent -Lo /tmp/consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
unzip /tmp/consul.zip
mv consul /usr/bin
rm -f /tmp/consul.zip

mkdir -p /opt/consul/data/
chown -R consul:consul /opt/consul/data

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

cat > /etc/systemd/system/consul.service << EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/agent.hcl

[Service]
Type=notify
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/env
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/consul.d/agent.hcl << EOF
log_level  = "INFO"
server     = false
datacenter = "consul-dc-a"
primary_datacenter = "consul-dc-a"
node_name="express-$INSTANCE_ID"
encrypt            = "pCOEKgL2SYHmDoFJqnolFUTJi7Vy+Qwyry04WIZUupc="
data_dir           = "/opt/consul/data"
client_addr    = "0.0.0.0"
retry_join = ["provider=aws tag_key=consul tag_value=join region=us-west-2"]
leave_on_terminate = false
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

cat > /etc/consul.d/service.hcl << EOF
node_name = "express-$INSTANCE_ID"
service {
    name = "web-server-$INSTANCE_ID"
    tags = ["express", "$INSTANCE_ID"]
    port = 3000
    check = {
        name = "Express Server Available on Port 3000"
        tcp = "localhost:3000"
        interval = "10s"
        timeout = "2s"
    }
}
EOF

# Create bash helper commands
cat > /etc/profile.d/consul.sh << EOF
export PS1="\[\033[0;31m\]\u@\[\033[0m\]$INSTANCE_ID "
alias nukeconsul="sudo rm -rf /opt/consul/*"
alias cl="journalctl -fu consul"
alias pc="cat /etc/consul.d/*"
alias vc="sudo vim /etc/consul.d/agent.hcl"
EOF

systemctl start consul
