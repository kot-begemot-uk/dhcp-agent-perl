use Test::More tests => 1;
use JSON::RPC2::Data;
use JSON::MaybeXS;
use Data::Compare;

BEGIN {

    my $Data = JSON::RPC2::Data->new();
    my @key_order = ("name");
    $Data->register_key_order("interfaces/interface", \@key_order);

    my $expected = {
          'interfaces/interface/br200/name' => '{"name":"br200"}',
          'interfaces/interface/br200/enabled' => '{"enabled":true}',
          'interfaces/interface/br200/dell-interface:untagged-ports' => '["e101-002-0","e101-001-0"]',
          'interfaces/interface/br200/type' => '{"type":"iana-if-type:l2vlan"}',
          'interfaces/interface/br200/base-if-vlan:id' => '{"base-if-vlan:id":200}'
        };
    my $result = $Data->flatpack(
        "interfaces/interface",
            decode_json('[{"name":"br200","base-if-vlan:id":200,"enabled":true,"dell-interface:untagged-ports":["e101-002-0","e101-001-0"],"type":"iana-if-type:l2vlan"}]'));

    ok(Compare($expected, $result));

}

diag( "Testing Flatpack Data" );

