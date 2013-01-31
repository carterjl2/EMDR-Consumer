#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;


use List::Util qw[min max];
$|=1;

use ZeroMQ qw/:all/;

my $cxt = ZeroMQ::Context->new;
my $sock = $cxt->socket(ZMQ_SUB);
$sock->connect('tcp://relay-eu-uk-1.eve-emdr.com:8050');
$sock->setsockopt(ZMQ_SUBSCRIBE, "");

while (1) {
    my $msg = $sock->recv();
    last unless defined $msg;

    use Compress::Zlib;
    my $json = uncompress($msg->data);

    use JSON;
    my $data = decode_json($json);
    if ($data->{resultType} eq "orders")
    {
        if ($data->{rowsets}[0]{regionID}==10000002)
        {

            my $typeid=$data->{rowsets}[0]{typeID};
            print $typeid." ".$data->{rowsets}[0]{generatedAt}."\n"; 
        }
    }
}
