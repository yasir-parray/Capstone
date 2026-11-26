#!/bin/bash
dnf install -y httpd || yum install -y httpd
echo "<h1>Project 24 Chaos Target - Healthy (yasir-p24)</h1>" > /var/www/html/index.html
systemctl enable --now httpd
