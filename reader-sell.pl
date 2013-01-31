#!/usr/bin/perl
use warnings;
use strict;
#use Data::Dumper;
use Cache::Memcached::Fast;


my $memd = new Cache::Memcached::Fast({servers => [ { address => 'localhost:11211'}]});

print  $memd->get('forgesell-'.$ARGV[0]);
print "\n";
