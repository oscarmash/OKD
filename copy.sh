#!/bin/bash

scp bastion:/etc/httpd/conf/httpd.conf files/httpd.conf
scp bastion:/etc/haproxy/haproxy.cfg files/haproxy.cfg
scp bastion:/etc/dhcp/dhcpd.conf files/dhcpd.conf

scp bastion:/etc/named.conf files/named/named.conf
scp bastion:/var/named/ilba.cat.db files/named/ilba.cat.db
scp bastion:/var/named/ilba.cat.reverse files/named/ilba.cat.reverse

scp bastion:/root/install-config.yaml.bak files/install-config.yaml
