#!/bin/bash -eux
function schedule_termination() {
  chmod +x /etc/rc.d/rc.local
  echo "/opt/aws-ec2/auto_terminate.sh after_ami >> /var/log/auto-terminate.log 2>&1" >> /etc/rc.d/rc.local
}
