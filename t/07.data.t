use Test::More tests => 4;
use JSON::RPC2::Data;
use JSON::MaybeXS;

BEGIN {

    my $Data = JSON::RPC2::Data->new();

    ok($Data->rfc8040_path(decode_json('{"interfaces":{"interface":{}}}')) eq "interfaces/interface");
    ok($Data->rfc8040_path(decode_json('{"interfaces":{"interface":[{"name":"eth1"}]}}')) eq "interfaces/interface/eth1");

    @key_order = ("key1", "key2");
    $Data->register_key_order("tests/test", \@key_order);
    ok($Data->rfc8040_path(decode_json('{"tests":{"test":[{"key1":"eth1", "key2":"fiber"}]}}')) eq "tests/test/eth1,fiber");
    ok($Data->rfc8040_path(decode_json('{"tests":{"test":[{"key2":"fiber", "key1":"eth1"}]}}')) eq "tests/test/eth1,fiber");

}

diag( "Testing JSON RPC Abstract Session $IO::Dispatcher::Session" );

