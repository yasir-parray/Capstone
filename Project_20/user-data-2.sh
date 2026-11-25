#!/bin/bash
dnf install -y httpd || yum install -y httpd
echo "<h1>Served by EC2 Instance 2 (yasir-p20)</h1><p>Host: $(hostname -f)</p>" > /var/www/html/index.html
systemctl enable --now httpd
