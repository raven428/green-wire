#!/usr/bin/env bash
source /etc/ppp/ip.d/10-route2dns.sh
/etc/init.d/dnsmasq restart
