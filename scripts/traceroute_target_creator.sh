#!/bin/bash
#
# This is a simple script to generate configuration syntax for the SmokePing
# Targets file (/etc/smokeping/config.d/Targets) that will be used by HPing
# for monitoring a routed pathway.
#
# Author: Henry Potgieter
# Email: hpotgieter@techtutoring.ca
# Date: April 26th, 2020

echo "Traceroute Generator for HPing Probe"
echo "===================================="

octet="(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])"
ip4="^$octet\\.$octet\\.$octet\\.$octet$"
notvalid=0
tcp_or_udp=0

# Prompt for valid input of an IP address
while [ $notvalid -eq 0 ] ; do
    read -p "Specify target IP address: " target
    if [[ $target =~ $ip4 ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify a valid IP address!\n"
    fi
done

# Prompt for a protocol
notvalid=0
while [ $notvalid -eq 0 ] ; do
    read -p "Specify tcp, udp or icmp: " protocol
    if [[ $protocol == "tcp" || $protocol == "udp" ]] ; then
        notvalid=1
        tcp_or_udp=1
    elif [[ $protocol == "icmp" ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify a valid protocol!\n"
    fi
done

# If we chose tcp or udp then ask what port to use
if [[ $tcp_or_udp -eq 1 ]] ; then
    notvalid=0
    while [ $notvalid -eq 0 ] ; do
        read -p "Specify the port from 1 to 65535: " port
        if [[ $port -lt 65535 && $port -gt 0 ]] ; then
            notvalid=1
        else
            echo -e "Error - Please specify a valid port (1-65534)!\n"
        fi
    done
fi

# Ask for the number of hops to create tests for
notvalid=0
while [ $notvalid -eq 0 ] ; do
    read -p "Specify the number of hops to test: " hops
    if [[ $hops =~ [1-9] || $hops =~ [1-9][0-9] ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify a hop count of 1 to 99!\n"
    fi
done

# Ask for name for each Target entry
notvalid=0
while [ $notvalid -eq 0 ] ; do
    read -p "Please specify a name to use for this set of Targets: " name
    if [[ $name =~ [A-Za-z0-9]+ ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify an alphanumeric string!\n"
    fi
done

# Ask for a nice display name we can use
notvalid=0
while [ $notvalid -eq 0 ] ; do
    read -p "Please specify a pretty name to use for the menu and title for this path: " menutitlename
    if [[ $menutitlename =~ [A-Za-z0-9\s.]+ ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify an alphanumeric string, spaces and periods are allowed!\n"
    fi
done

# Specify how deep in the Targets tree these tests will be (how many +'s to put before Target entries)
notvalid=0
while [ $notvalid -eq 0 ] ; do
    read -p "Specify tree depth (number of +'s to prefix entries with'): " prefix
    if [[ $prefix =~ [1-9] ]] ; then
        notvalid=1
    else
        echo -e "Error - Please specify a prefix value of 1 to 9!\n"
    fi
done

# Calculate the number of +'s to render prior to the Target name and create the menu and title entries'
prefix_plus=$(printf "%-${prefix}s" "+")
echo -e "${prefix_plus// /+} ${name}Path$i\n\nmenu = $menutitlename\ntitle = $menutitlename\n"


# Loop through for the number of hops
for i in $(seq 1 $hops) ; do

    # Calculate the +'s to place in front of each Target entry'
    prefix_plus=$(printf "%-$((${prefix}+1))s" "+")
    echo -e "${prefix_plus// /+} $name$i\nmenu = HOP $i "

    # If this is TCP or UDP do the appropriate command to grab the hostname and IP for this HOP
    if [[ $tcp_or_udp -eq 1 ]] ; then
        if [[ $protocol == "tcp" ]] ; then
            ip_and_host=`hping3 -S -p $port -T --ttl $i -c 1 $target 2>/dev/null | grep '^hop.*TTL'`
        else
            ip_and_host=`hping3 -2 -p $port -T --ttl $i -c 1 $target 2>/dev/null | grep '^hop.*TTL'`
        fi
    else
        # Or if it's ICMP, use this to grab the hostname and IP
        ip_and_host=`hping3 -1 -T --ttl $i -c 1 $target 2>/dev/null | grep '^hop.*TTL'`
    fi
    # Split out the relevant data from the hping command output and populate vars with it
    ip_addr=`echo $ip_and_host | awk -F '=' '{print $3}' | awk '{print $1}'`
    host=`echo $ip_and_host | awk -F '=' '{print $4}'`
    echo "title = HOP $i - $ip_addr - $host"
    # Specify the rest of the configuration
    echo "pings = 20"
    echo "protocol = $protocol"
    # If it was tcp or udp specify the port to use
    if [[ $tcp_or_udp -eq 1 ]] ; then
        echo "port = $port"
    fi
    echo -e "traceroute_hop = $i\n"
done
