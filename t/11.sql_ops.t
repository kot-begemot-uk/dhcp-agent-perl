use Test::More tests => 1;
use JSON::RPC2::SQLData;
use JSON::MaybeXS;
use Data::Compare;
use DBI;

BEGIN {

    my $driver   = "SQLite";
    my $database = "/tmp/test$$.db";
    my $dsn = "DBI:$driver:dbname=$database";
    my $userid = "";
    my $password = "";
    #my $driver   = "mysql";
    #my $database = "yangdata";
    #my $dsn = "DBI:$driver:dbname=$database";
    #my $userid = "test";
    #my $password = "testpassword";
    my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1, AutoCommit => 1})
       or die $DBI::errstr;
    diag "Opened database successfully\n";

    my $stmt = qq(CREATE TABLE data
       (  path CHAR(255) NOT NULL,
          value TEXT NOT NULL,
          entity CHAR(255) NOT NULL,
          store INT););
    my $kstmt = qq(CREATE UNIQUE INDEX dindex ON data(path, entity, store););
    
    $dbh->begin_work();
    
    if ($dbh->do($stmt) < 0) { die "Failed to create database " . $DBI::errstr; }
    if ($dbh->do($kstmt) < 0) { die "Failed to create key " . $DBI::errstr; }

    $dbh->commit();

    my $Data = JSON::RPC2::SQLData->new($dbh);
    my @key_order = ("name");
    $Data->register_key_order("ietf-interfaces:interfaces/interface", \@key_order);

    my $test_data = decode_json('[{"name":"br200","base-if-vlan:id":200,"enabled":true,"dell-interface:untagged-ports":["e101-002-0","e101-001-0"],"type":"iana-if-type:l2vlan"}]');


    my $model_data = {
        'ietf-interfaces:interfaces/interface/br200/name' => '{"name":"br200"}',
        'ietf-interfaces:interfaces/interface/br200/enabled' => '{"enabled":true}',
        'ietf-interfaces:interfaces/interface/br200/dell-interface:untagged-ports' => '["e101-002-0","e101-001-0"]',
        'ietf-interfaces:interfaces/interface/br200/type' => '{"type":"iana-if-type:l2vlan"}',
        'ietf-interfaces:interfaces/interface/br200/base-if-vlan:id' => '{"base-if-vlan:id":200}'
    };

    my $txid1 = $Data->txid();

    my @arg = (
        $txid1,
        0,
        "openswitch-2",
        decode_json('{"ietf-interfaces:interfaces":{"interface":[]}}'),
        $test_data
    );
    
    $Data->put(\@arg);

    @arg = ($txid1);

    $Data->commit(\@arg);
    @arg = (0, "openswitch-2", decode_json('{"ietf-interfaces:interfaces":{"interface":[]}}'));
    ok(Compare($test_data, $Data->read(\@arg)));
    $dbh->disconnect();
    unlink($database);
}

diag( "Testing SQL Data Ops" );


