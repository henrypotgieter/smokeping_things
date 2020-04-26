# SmokePing Things
Here you will find some useful scripts and and Perl Modules to enhance SmokePing.

## Perl Modules
Here are some custom modules for SmokePing.  You will find the HPing.pm Perl module here.

Perl modules should be added to /usr/share/perl5/Smokeping/probes (depending on your install of SmokePing) to be able to use them.  Make sure to add a definition for the new Probe (see file contents for example).

## Scripts

Bash scripts that will help with changes to SmokePing, particularly with creating new target configurations

### Traceroute Generator

Please see the traceroute_target_creator.sh file in scripts for a simple way to generate configuration elements automatically for adding to the SmokePing Targets config file.  This allows you to easily create multiple graphs to monitor hops along a routed pathway.
