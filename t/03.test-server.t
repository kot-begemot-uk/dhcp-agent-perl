use Test::More tests => 11;
use strict;

use JSON::RPC2::SimpleQueueSession;
use JSON::RPC2::Client;


BEGIN {

{
    package TestServer;
    sub new {
        my $class = shift; 
        my $object = shift;
        my $self = {};
        return bless $self, $class;
    }

    sub echo { 
        my $self = shift;
        my $arg = shift;
        return $arg;
    };
    sub a_err {
        return undef;
    };
    sub b { my %p=@_; return "b $p{first}" };
    1;
}
       

#### MAIN

my $client = JSON::RPC2::Client->new();
my $session = JSON::RPC2::SimpleQueueSession->new(undef, 1);
ok(defined $session);
my $test_implementation = TestServer->new();
ok($session->register($test_implementation));
ok($session->execute('{"jsonrpc": "2.0", "method": "echo", "params": [1,2,4], "id": "1"}'));
ok($session->execute('{"jsonrpc": "2.0", "method": "echo", "params": {"echotest":"echodata"}, "id": "1"}'));
ok($session->execute('{"jsonrpc": "2.0", "method": "a_err", "params": {"echotest":"echodata"}, "id": "1"}'));

# Result analysis

my $result = shift @{$session->{queue}};
ok(ref $result->{result} eq 'ARRAY');
ok(${$result->{result}}[0] = 1 and ${$result->{result}}[1] = 2 and ${$result->{result}}[0] = 4);

my $result = shift @{$session->{queue}};
ok(ref $result->{result} eq 'HASH');
ok(${$result->{result}}{"echotest"} eq "echodata");

my $result = shift @{$session->{queue}};
ok(ref $result->{error} eq 'HASH');
ok(${$result->{error}}{"code"} == -32603);
}

