This is a very basic consumer for EMDR, pulling in buy or sell data from the feed, and sticking it into a local memcached server for reuse later.

Uses Perl, ZeroMQ, and Cache::Memcached::Fast.

This is not a 'grab some data and stop'. 

These are 'connect to the firehose and keep on sucking'. I normally run then as:
nohup perl buy.pl &

for example. I'll be expanding them at some point, to do other hubs, but for now, it's just the forge.


buy.pl : stores data about buy orders
sell.pl : stores data about sell orders
reader-buy.pl : takes a type id. outputs the buy order data from memcache
reader-sell.pl : takes a type id. outputs the sell order data from memcache
monitor.pl : hooks up to EMDR to check you're actually getting a feed. Does /nothing/ else.
