#!/bin/bash -exu
# The shebang line is here in case there's is currently an empty user-data script.
# It wont hurt if already there.
#######################################

<% if @options[:auto_terminate] %>
# make the script run upon reboot
chmod +x /etc/rc.d/rc.local
echo "/root/terminate-myself.sh >> /var/log/terminate-myself.log 2>&1" >> /etc/rc.d/rc.local
<% end %>

######################################
# ami_creation.sh: added to the end of user-data automatically.
function configure_aws_cli() {
  local home_dir=$1
  # Configure aws cli in case it is not yet configured
  mkdir -p $home_dir/.aws
  if [ ! -f $home_dir/.aws/config ]; then
    cat >$home_dir/.aws/config <<EOL
[default]
region = <%= @region %>
output = json
EOL
  fi
}

configure_aws_cli /home/ec2-user
configure_aws_cli /root

echo "############################################" >> /var/log/user-data.log
echo "# Logs above is from the original AMI baking at: $(date)" >> /var/log/user-data.log
echo "# New logs below" >> /var/log/user-data.log
echo "############################################" >> /var/log/user-data.log

# Create AMI Bundle
AMI_NAME="<%= @ami_name %>"
INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(aws configure get region)
aws ec2 create-image --name $AMI_NAME --instance-id $INSTANCE_ID --region $REGION
