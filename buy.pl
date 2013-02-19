#!/usr/bin/perl
use warnings;
use strict;
use Cache::Memcached::Fast;
use Date::Parse;
use POSIX qw(strftime);
my $memd = new Cache::Memcached::Fast({servers => [ { address => 'localhost:11211'}]});

#print $memd->server_versions;
 

use List::Util qw[min max];
$|=1;

use ZeroMQ qw/:all/;

my $cxt = ZeroMQ::Context->new;
my $sock = $cxt->socket(ZMQ_SUB);
$sock->connect('tcp://relay-eu-uk-1.eve-emdr.com:8050');
$sock->setsockopt(ZMQ_SUBSCRIBE, "");
my $region='forge';
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
			$region='forge';
		}
        else
        {
             $region=$data->{rowsets}[0]{regionID};
        }
        my $typeid=$data->{rowsets}[0]{typeID};
        my $when=$data->{rowsets}[0]{generatedAt};
        my $count=@{$data->{rowsets}[0]{rows}};
        my %buyPrice;
        my $numberOfBuyItems=0;
        my $cached=$memd->get($region.'buy-'.$typeid);
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
            if (($data->{rowsets}[0]{rows}[$i][6]))
            {
                if (defined($buyPrice{$data->{rowsets}[0]{rows}[$i][0]}))
                {
                    $buyPrice{$data->{rowsets}[0]{rows}[$i][0]}+=$data->{rowsets}[0]{rows}[$i][1];
                }
                else
                {
                    $buyPrice{$data->{rowsets}[0]{rows}[$i][0]}=$data->{rowsets}[0]{rows}[$i][1];
                }
                $numberOfBuyItems+=$data->{rowsets}[0]{rows}[$i][1];
            }
        }
        if ($numberOfBuyItems>0)
        {
              my @prices=sort { $b <=> $a } keys %buyPrice;
              my $fivePercent=max(int($numberOfBuyItems*0.05),1);
              my $fivePercentPrice=0;
              my $bought=0;
              my $boughtPrice=0;
              while ($bought<$fivePercent)
              {
                  $fivePercentPrice=shift @prices;
                  if ($fivePercent>($bought+$buyPrice{$fivePercentPrice}))
                  {
                        $boughtPrice+=$buyPrice{$fivePercentPrice}*$fivePercentPrice;
                        $bought+=$buyPrice{$fivePercentPrice};
                  }
                  else
                  {
                      my $diff=$fivePercent-$bought;
                      $boughtPrice+=$fivePercentPrice*$diff;
                      $bought=$fivePercent;
                  }
               }
              my $fiveAverageBuyPrice=$boughtPrice/$bought;
               $memd->set($region.'buy-'.$typeid,sprintf("%.2f",$fiveAverageBuyPrice)."|".$numberOfBuyItems."|".$fivePercent."|".$when);
        }
    }
}
