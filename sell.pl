#!/usr/bin/perl
use warnings;
use strict;
use Cache::Memcached::Fast;
use Redis;
use Date::Parse;
use POSIX qw(strftime);
use JSON;
use Compress::Zlib;

my $memd = new Cache::Memcached::Fast({servers => [ { address => 'localhost:11211'}]});
my $redis = Redis->new(reconnect => 60);

#print $memd->server_versions;
 

use List::Util qw[min max];
$|=1;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw/ZMQ_SUB ZMQ_SUBSCRIBE/;



my $context = zmq_init(1);
my $sock = zmq_socket($context, ZMQ_SUB);
zmq_connect($sock, "tcp://localhost:8050");
zmq_setsockopt($sock,ZMQ_SUBSCRIBE, "");





my $region='forge';

while (1) {
    my $msg=zmq_recvmsg($sock);

    last unless defined $msg;

    my $json = uncompress(zmq_msg_data($msg));

    my $data = decode_json($json);
    if ($data->{resultType} eq "orders")
    {
        if ($data->{rowsets}[0]{regionID}==10000002)
        {
            $region='forge';
        }
		else
		{
            $region=$data->{rowsets}[0]{regionID};
        }
        my $typeid=$data->{rowsets}[0]{typeID};
        my $when=$data->{rowsets}[0]{generatedAt};
        my $count=@{$data->{rowsets}[0]{rows}};
        my %sellPrice;
        my $numberOfSellItems=0;
        my $cached=$memd->get($region.'sell-'.$typeid);
        my $newdate=str2time($when);
        if ($newdate>time)
        {
            my $tz = strftime("%z", localtime(time));
            $tz =~ s/(\d{2})(\d{2})/$1:$2/;
            $when=strftime("%Y-%m-%dT%H:%M:%S", localtime(time)) . $tz;
        }
        if (defined($cached))
        {
            my @cachePieces=split(/\|/,$cached);
            my $cachedate=str2time($cachePieces[3]);
            if ($newdate<$cachedate)
            {
                next;
            }
        }
        for (my $i=0;$i<$count;$i++)
        {
            if (!($data->{rowsets}[0]{rows}[$i][6]))
            {
                if (defined($sellPrice{$data->{rowsets}[0]{rows}[$i][0]}))
                {
                    $sellPrice{$data->{rowsets}[0]{rows}[$i][0]}+=$data->{rowsets}[0]{rows}[$i][1];
                }
                else
                {
                    $sellPrice{$data->{rowsets}[0]{rows}[$i][0]}=$data->{rowsets}[0]{rows}[$i][1];
                }
                $numberOfSellItems+=$data->{rowsets}[0]{rows}[$i][1];
            }
        }
        if ($numberOfSellItems>0)
        {
              my @prices=sort { $a <=> $b } keys %sellPrice;
              my $fivePercent=max(int($numberOfSellItems*0.05),1);
              my $fivePercentPrice=0;
              my $bought=0;
              my $boughtPrice=0;
              while ($bought<$fivePercent)
              {
                  $fivePercentPrice=shift @prices;
                  if ($fivePercent>($bought+$sellPrice{$fivePercentPrice}))
                  {
                        $boughtPrice+=$sellPrice{$fivePercentPrice}*$fivePercentPrice;
                        $bought+=$sellPrice{$fivePercentPrice};
                  }
                  else
                  {
                      my $diff=$fivePercent-$bought;
                      $boughtPrice+=$fivePercentPrice*$diff;
                      $bought=$fivePercent;
                  }
               }
              my $fiveAverageSellPrice=$boughtPrice/$bought;
               $memd->set($region.'sell-'.$typeid,sprintf("%.2f",$fiveAverageSellPrice)."|".$numberOfSellItems."|".$fivePercent."|".$when);
               $redis->set($region.'sell-'.$typeid=>sprintf("%.2f",$fiveAverageSellPrice)."|".$numberOfSellItems."|".$fivePercent."|".$when);
        }
        
    }
}
