use Test::More tests => 3;
use JSON::RPC2::Data;
use JSON::MaybeXS;
use Data::Compare;

BEGIN {

    my $Data = JSON::RPC2::Data->new();
    my @key_order = ("name");
    $Data->register_key_order("interfaces/interface", \@key_order);


    my $model_data = {
        'interfaces/interface/br200/name' => '{"name":"br200"}',
        'interfaces/interface/br200/enabled' => '{"enabled":true}',
        'interfaces/interface/br200/dell-interface:untagged-ports' => '["e101-002-0","e101-001-0"]',
        'interfaces/interface/br200/type' => '{"type":"iana-if-type:l2vlan"}',
        'interfaces/interface/br200/base-if-vlan:id' => '{"base-if-vlan:id":200}'
    };

    my $txid1 = $Data->txid();

    
    $Data->put([
           $txid1,
        0,
        undef,
        decode_json('{"interfaces":{"interface":[]}}'),
        decode_json('[{"name":"br200","base-if-vlan:id":200,"enabled":true,"dell-interface:untagged-ports":["e101-002-0","e101-001-0"],"type":"iana-if-type:l2vlan"}]')
    ]);

    my $data_op = @{$Data->{txids}->{$txid1}}[0];
    ok(Compare($model_data, $data_op->data()));
    $Data->cancel([$txid1]);

    my $txid2 = $Data->txid();
    $Data->merge([
        $txid2,
        0,
        undef,
        decode_json('{"interfaces":{"interface":[]}}'),
        decode_json('[{"name":"br200","base-if-vlan:id":200,"enabled":true,"dell-interface:untagged-ports":["e101-002-0","e101-001-0"],"type":"iana-if-type:l2vlan"}]')
    ]);

    my $data_op = @{$Data->{txids}->{$txid2}}[0];
    ok(Compare($model_data, $data_op->data()));

    $Data->cancel([$txid2]);

    my $txid3 = $Data->txid();
    $Data->delete([
        $txid3,
        0,
        undef,
        decode_json('{"interfaces":{"interface":[]}}')
    ]
    );

    my $data_op = @{$Data->{txids}->{$txid3}}[0];
    ok(Compare('interfaces/interface%', $data_op->data()));
}

diag( "Testing Abstract Data Ops" );

