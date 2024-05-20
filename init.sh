#!/bin/bash -xe

echo "Become root user"

sudo su -

hostnamectl set-hostname ${name}

####
# EFS Configuration
####
mkdir -p /mnt/efs
mount -t efs ${filesystem_id} /mnt/efs

DIR="/mnt/efs/${name}"
if [ ! -d "$DIR" ]; then
  # Take action if $DIR exists. #
  echo "empty dir $DIR creating then"
  mkdir -p $DIR
  chown -R 999:999 $DIR
fi

echo "${filesystem_id}.efs.${region}.amazonaws.com:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >>/etc/fstab

####
# AWS Secret manager configuration
# Get secret data and store in variables
####
ADMIN_PASSWORD=$(AWS_DEFAULT_REGION=${region} aws secretsmanager get-secret-value --secret-id ${secret_name} | jq -r '.SecretString' | jq -r '."${secret_id_admin_password}"')
FEDERATION_PASSWORD=$(AWS_DEFAULT_REGION=${region} aws secretsmanager get-secret-value --secret-id ${secret_name} | jq -r '.SecretString' | jq -r '."${secret_id_federation_password}"')
MONITOR_PASSWORD=$(AWS_DEFAULT_REGION=${region} aws secretsmanager get-secret-value --secret-id ${secret_name} | jq -r '.SecretString' | jq -r '."${secret_id_monitor_password}"')
COOKIE_STRING=$(AWS_DEFAULT_REGION=${region} aws secretsmanager get-secret-value --secret-id ${secret_name} | jq -r '.SecretString' | jq -r '."${secret_id_cookie_string}"')

######################################################################
## consul configuration
#
# consul is a service discovery planned to reduce problem with privateDNS used by AWS discovery
# on rabbitmq
#
######################################################################

# basic directories
mkdir -p /opt/consul/data
mkdir -p /etc/consul.d

LAN_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

# files from consul configuration
echo -e "LAN_NODENAME=${name}
LAN_ADDRESS=$LAN_ADDRESS" >/etc/environment

echo -e "{
    \"server\": true,
    \"bootstrap_expect\": 3,
    \"acl_default_policy\": \"allow\",
    \"addresses\": {
        \"dns\": \"0.0.0.0\",
        \"grpc\": \"0.0.0.0\",
        \"http\": \"0.0.0.0\",
        \"https\": \"0.0.0.0\"
    },
    \"client_addr\": \"0.0.0.0\",
    \"connect\": {
        \"enabled\": false
    },
    \"data_dir\": \"/opt/consul/data\",
    \"datacenter\": \"${cluster_name}\",
    \"disable_update_check\": true,
    \"domain\": \"${domain}\",
    \"enable_script_checks\": true,
    \"enable_syslog\": true,
    \"log_level\": \"INFO\",
    \"performance\": {
        \"leave_drain_time\": \"5s\",
        \"raft_multiplier\": 1,
        \"rpc_hold_timeout\": \"7s\"
    },
    \"ports\": {
        \"dns\": 8600,
        \"http\": 8500,
        \"server\": 8300
    },
    \"raft_protocol\": 3,
    \"syslog_facility\": \"local0\",
    \"ui_config\": {
        \"enabled\": true
    }
}" >/etc/consul.d/base.json

echo -e "{
        \"retry_interval\": \"30s\",
        \"retry_interval_wan\": \"30s\",
        \"retry_join\": [\"provider=aws tag_key=${tag_key_app} tag_value=${tag_app}\"],
        \"retry_max\": 0,
        \"retry_max_wan\": 0
}" >/etc/consul.d/join.json

echo -e "[Unit]
Description=\"HashiCorp Consul\"
Documentation=https://www.consul.io/
Requires=systemd-networkd.service
After=systemd-networkd.service
ConditionFileNotEmpty=/etc/consul.d/join.json

[Service]
Type=simple
EnvironmentFile=/etc/environment
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/  -advertise-wan \$LAN_ADDRESS -bind \$LAN_ADDRESS -advertise \$LAN_ADDRESS -node \$LAN_NODENAME
ExecReload=/usr/bin/consul reload
Restart=on-failure
KillMode=process
LimitNOFILE=65536" >/etc/systemd/system/consul.service

### systemd-resolved configuration
iptables --table nat --append OUTPUT --destination localhost --protocol udp --match udp --dport 53 --jump REDIRECT --to-ports 8600
iptables --table nat --append OUTPUT --destination localhost --protocol tcp --match tcp --dport 53 --jump REDIRECT --to-ports 8600

echo -e "[Resolve]
DNS=127.0.0.1
DNSSEC=false
Domains=${domain} node.${domain} service.${domain}" >>/etc/systemd/resolved.conf
systemctl restart systemd-resolved

echo "Enabling Consul"
systemctl daemon-reload
systemctl enable consul

echo "Starting Consul"
systemctl start consul

######################################################################
## rabbitmq configuration
##
######################################################################

mkdir -p /etc/rabbitmq

echo -e "[Install]
WantedBy=multi-user.target

[Unit]
Description=Rabbitmq Container
After=docker.service consul.service
Requires=docker.service consul.service

[Service]
EnvironmentFile=/etc/environment
TimeoutStartSec=0
Restart=always
ExecStartPre=/usr/bin/bash -c \"aws ecr get-login-password --region ${ecr_region} | docker login --username AWS --password-stdin ${ecr_repo_dns}\"
ExecStartPre=-/usr/bin/docker stop %n
ExecStartPre=-/usr/bin/docker rm %n
ExecStartPre=/usr/bin/docker pull ${rabbitmq_image_url}
ExecStart=/usr/bin/docker run --rm --name %n --net=host -v /var/log/rabbitmq:/var/log/rabbitmq -v /var/lib/rabbitmq:/var/lib/rabbitmq -v /mnt/efs:/mnt/efs -v /etc/rabbitmq:/etc/rabbitmq -p 5672:5672 -p 15672:15672 --ulimit nofile=32768:32768 ${rabbitmq_image_url}
ExecStartPost=sleep 5
[Install]
WantedBy=multi-user.target" >/etc/systemd/system/rabbitmq-server.service

echo "Create config file - rabbitmq.conf"

echo -e "cluster_name = ${cluster_name}
cluster_formation.peer_discovery_backend = consul
cluster_formation.consul.host = localhost
cluster_formation.consul.svc_addr_use_nodename = true
cluster_formation.consul.use_longname = false
cluster_formation.consul.svc_addr_auto = true
cluster_formation.consul.port = 8500
cluster_formation.consul.scheme = http
cluster_formation.consul.svc = rabbitmq
cluster_formation.consul.svc_ttl = 30
cluster_formation.consul.deregister_after = 60
management.tcp.port = 15672
listeners.tcp.1 = 0.0.0.0:5672
log.console = true
log.console.level = info
log.file = instance.log
log.file.level = info
log.file.formatter = json" >/etc/rabbitmq/rabbitmq.conf

NODENAME=${name}

echo -e "NODENAME=rabbit@${name}
MNESIA_BASE=/mnt/efs/${name}
PLUGINS_DIR=/opt/rabbitmq/plugins:/var/lib/rabbitmq/plugins
MNESIA_DIR=/mnt/efs/${name}/node" >/etc/rabbitmq/rabbitmq-env.conf

echo -e "[rabbitmq_peer_discovery_consul]." >/etc/rabbitmq/enabled_plugins

### install packages plugins and set configuration for then
echo "Config token file"
mkdir -p /var/lib/rabbitmq
mkdir -p /var/lib/rabbitmq/plugins
echo $COOKIE_STRING >/var/lib/rabbitmq/.erlang.cookie
wget -c https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/${rabbitmq_delayedmessage_version}/rabbitmq_delayed_message_exchange-${rabbitmq_delayedmessage_version}.ez -P /var/lib/rabbitmq/plugins
chown -R 999:999 /var/lib/rabbitmq
chown -R 999:999 /etc/rabbitmq
chmod a-r /var/lib/rabbitmq/.erlang.cookie
chmod u+r /var/lib/rabbitmq/.erlang.cookie

### add log folder
mkdir -p /var/log/rabbitmq
chown -R 999:999 /var/log/rabbitmq

echo "Enabling Rabbitmq Server"
systemctl enable rabbitmq-server

echo "Starting RabbitMQ"
systemctl start rabbitmq-server

# wait startup node for next commands
alias rabbitmqctl="docker exec rabbitmq-server.service rabbitmqctl $1"
RABBITMQCTL_CMD="docker exec rabbitmq-server.service rabbitmqctl"
alias rabbitmq-plugins="docker exec rabbitmq-server.service rabbitmq-plugins $1"
RABBITMQCTL_PLUGINS_CMD="docker exec rabbitmq-server.service rabbitmq-plugins"

$RABBITMQCTL_CMD await_startup

# enable plugins
$RABBITMQCTL_PLUGINS_CMD enable rabbitmq_peer_discovery_consul rabbitmq_delayed_message_exchange rabbitmq_management rabbitmq_management_agent rabbitmq_shovel rabbitmq_shovel_management rabbitmq_top rabbitmq_tracing rabbitmq_web_dispatch rabbitmq_amqp1_0 rabbitmq_federation rabbitmq_federation_management

EXISTS_RABBITMQ_ADMIN=$($RABBITMQCTL_CMD list_users --formatter json | jq -c '.[] | select(.user | contains("${admin_username}"))' | jq '.user')

# Create admin user
if [ "$EXISTS_RABBITMQ_ADMIN" == "" ]; then
  $RABBITMQCTL_CMD add_user ${admin_username} $ADMIN_PASSWORD
  $RABBITMQCTL_CMD set_user_tags ${admin_username} administrator
  $RABBITMQCTL_CMD set_permissions -p / ${admin_username} ".*" ".*" ".*"
fi

EXISTS_RABBITMQ_MONITOR=$($RABBITMQCTL_CMD list_users --formatter json | jq -c '.[] | select(.user | contains("${monitor_username}"))' | jq '.user')

# Create monitor user
if [ "$EXISTS_RABBITMQ_MONITOR" == "" ]; then
  $RABBITMQCTL_CMD add_user ${monitor_username} $MONITOR_PASSWORD
  $RABBITMQCTL_CMD set_user_tags ${monitor_username} monitoring
  $RABBITMQCTL_CMD set_permissions -p / ${monitor_username} ".*" ".*" ".*"
fi

EXISTS_RABBITMQ_FEDERATION=$($RABBITMQCTL_CMD list_users --formatter json | jq -c '.[] | select(.user | contains("${federation_username}"))' | jq '.user')

# Create federation user
if [ "$EXISTS_RABBITMQ_FEDERATION" == "" ]; then
  $RABBITMQCTL_CMD add_user ${federation_username} $FEDERATION_PASSWORD
  $RABBITMQCTL_CMD set_user_tags ${federation_username} administrator
  $RABBITMQCTL_CMD set_permissions -p / ${federation_username} ".*" ".*" ".*"
fi

####
# logrotate configuration
####

echo -e "
/var/log/rabbitmq/*.log {
    rotate 0
    daily
    size 50M
    maxsize 50M
}" >/etc/logrotate.d/rabbitmq

echo -e "
@daily root logrotate /etc/logrotate.conf
@daily root docker exec rabbitmq-server.service rabbitmqctl export_definitions \"/mnt/efs/${name}.json\"
@daily root journalctl --vacuum-time=3days" >/etc/crontab

crontab /etc/crontab

systemctl enable crond
systemctl start crond
