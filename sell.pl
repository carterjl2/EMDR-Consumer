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

#            print "\nNew record --- ";
            my $typeid=$data->{rowsets}[0]{typeID};
            my $when=$data->{rowsets}[0]{generatedAt};
            my $count=@{$data->{rowsets}[0]{rows}};
#            print " rows".$count."\n";
            my %sellPrice;
            my $numberOfSellItems=0;
            my $cached=$memd->get('forgesell-'.$typeid);
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
#                print "new date: $newdate\ncached date:  $cachedate\ncached portion: ".$cachePieces[3]."\ngenerated at: $when\n";
                if ($newdate<$cachedate)
                {
#                    print join(",",@cachePieces)."\n";
#                    print "next\n";
                    next;
                }
            }
print $typeid."\n";
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
#                  print join(",",@prices)."\n";
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
#                  print "Total:".$numberOfSellItems."     Five percent:   ".$fivePercent."  bought:".$bought."  Price:".$fiveAverageSellPrice."\n";
                   $memd->set('forgesell-'.$typeid,sprintf("%.2f",$fiveAverageSellPrice)."|".$numberOfSellItems."|".$fivePercent."|".$when);
            }
        }
    }
}
