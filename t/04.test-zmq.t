use Test::More tests => 6;
use strict;

use JSON::MaybeXS;
use JSON::RPC2::ZMQSession;
use JSON::RPC2::Client;
use ZMQ::FFI qw(ZMQ_REQ ZMQ_REP);


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
#
    if (fork() > 0) {

        # Client
        my $ClientCtx = ZMQ::FFI->new();
        my $client = $ClientCtx->socket(ZMQ_REQ);
        $client->bind("tcp://127.0.0.1:4677");
        $client->connect("tcp://127.0.0.1:4678");

        $client->send('{"jsonrpc": "2.0", "method": "echo", "params": [1,2,4], "id": "1"}');

        my $result = decode_json($client->recv());
        ok(ref $result->{result} eq 'ARRAY');
        ok(${$result->{result}}[0] = 1 and ${$result->{result}}[1] = 2 and ${$result->{result}}[0] = 4);

        $client->send('{"jsonrpc": "2.0", "method": "echo", "params": {"echotest":"echodata"}, "id": "1"}');

        my $result = decode_json($client->recv());
        ok(ref $result->{result} eq 'HASH');
        ok(${$result->{result}}{"echotest"} eq "echodata");

        $client->send('{"jsonrpc": "2.0", "method": "a_err", "params": {"echotest":"echodata"}, "id": "1"}');

        my $result = decode_json($client->recv);
        ok(ref $result->{error} eq 'HASH');
        ok(${$result->{error}}{"code"} == -32603);
        $client->close();
    } else {
        my $ServerCtx = ZMQ::FFI->new();
        my $server = $ServerCtx->socket(ZMQ_REP);
        $server->bind("tcp://127.0.0.1:4678");
        my $session = JSON::RPC2::ZMQSession->new(TestServer->new(), $server, 1);
        $session->execute($server->recv());
        $session->execute($server->recv());
        $session->execute($server->recv());
        $server->close();
    }
}


