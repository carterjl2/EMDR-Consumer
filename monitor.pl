#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
use JSON;
use Compress::Zlib;


use List::Util qw[min max];
$|=1;


use ZMQ::LibZMQ3;
use ZMQ::Constants qw/ZMQ_SUB ZMQ_SUBSCRIBE/;



my $context = zmq_init(1);
my $sock = zmq_socket($context, ZMQ_SUB);
zmq_connect($sock, "tcp://localhost:8050");
zmq_setsockopt($sock,ZMQ_SUBSCRIBE, "");



while (1) {
    my $msg=zmq_recvmsg($sock);
    last unless defined $msg;

    my $json = uncompress(zmq_msg_data($msg));

    my $data = decode_json($json);
    if ($data->{resultType} eq "orders")
    {
            my $typeid=$data->{rowsets}[0]{typeID};
            print $data->{rowsets}[0]{regionID}." ".$typeid." ".$data->{rowsets}[0]{generatedAt}."\n"; 
    }
}
