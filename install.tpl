#!/bin/bash
apt-get update -y
apt install nginx -y
systemctl start nginx