#!/usr/bin/perl
#
#
#

use warnings;
use strict;
use utf8;
use English;
use Carp;
use IO::Dispatcher;
use Getopt::Long;
use Inocybe::JSON::RPC2::DHCPData;
use JSON::RPC2::ZMQSession;
use ZMQ::FFI qw(ZMQ_REQ ZMQ_REP ZMQ_HWM ZMQ_SNDHWM ZMQ_RCVHWM);
use DBI;
use JSON::MaybeXS;


$OUTPUT_AUTOFLUSH = 1;

sub help {
    print STDERR 
"
--control=uri - json rpc uri for control interface (ZMQ for now).
--verbose= enable debug
--dsn= Database DSN
--username= Database username 
--password= Database password
";
}

my ($control, $verbose, $dsn, $username, $password);

GetOptions(
"control=s"=>\$control,
"dsn=s"=>\$dsn,
"username=s"=>\$username,
"password=s"=>\$password,
"verbose"=>\$verbose
) || &help;

my $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit => 1})
    or die $DBI::errstr;

$dbh->trace(1);

my $dispatcher = IO::Dispatcher->new();

my $ServerCtx = ZMQ::FFI->new();
my $server = $ServerCtx->socket(ZMQ_REP);
$server->bind($control);
$server->set(ZMQ_RCVHWM, 'int', 3);
$server->set(ZMQ_SNDHWM, 'int', 3);
my $Data = Inocybe::JSON::RPC2::DHCPData->new($dispatcher, $dbh, $verbose);
my @key_order = ("name");
$Data->register_key_order("dhcp-agent:interfaces/interface", \@key_order);
$Data->process_dcn();

my $session = JSON::RPC2::ZMQSession->new($Data, $server);

$dispatcher->register($session);
$dispatcher->run();
