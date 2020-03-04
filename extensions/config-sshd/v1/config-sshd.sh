#! /bin/bash

set -x

sudo sed -i "s/^Port 22$/Port 22\nPort 54322/1" /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart
