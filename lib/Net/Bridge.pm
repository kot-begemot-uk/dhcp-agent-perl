# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package Net::Bridge;

use warnings;
use strict;
use utf8;
use Carp;
use Net::DHCP::Packet;
use Net::DHCP::Constants;
use Net::Bridge::FDB;
use IO::File;


sub new {
    my $class = shift;
    my $iface = shift;
    my $self = {};
    my %table;
    my %iftable;
    bless $self, $class;
    $self->{iface} = $iface;
    $self->{fdb} = Net::Bridge::FDB->new($iface);
    return $self;
}
# DHCP libraries return a long binary hardware address to allow non Ethernet
# media. We need to bite off the first 6 bytes and spit them out in a MAC
# form


sub dhcp_to_mac {
    my $arg = shift;
    my @r = ();
    @r = unpack 'a2a2a2a2a2a2', $arg;
    return join(":", @r);
}

#
# There is no default encoder for Option 82 in the DHCP libraries. While they
# understand the concept they do not encode/decode it
# TODO: Build a proper encoder decoder
#


sub option_82_encode {
    my $subopt = shift;
    my $val = shift;
    my $len = length($val);
    return pack "CCZ" . ($len + 1), $subopt, $len, $val;
}


sub process {
    my $self = shift;
    my $dhcp = shift;
    
    if ($dhcp->op() == &Net::DHCP::Packet::BOOTREQUEST()) {

        my $fdb = $self->{fdb};
        my $mac = dhcp_to_mac($dhcp->chaddr());
        my $sport = $fdb->scan_and_find_mac($mac);

        my $option82 = &option_82_encode($Net::DHCP::Constants::RELAYAGENT_CODES{'RA_CIRCUIT_ID'}, $sport);
        $dhcp->addOptionRaw(DHO_DHCP_AGENT_OPTIONS(), pack("a" . (length($option82) - 1), $option82));
    }

    return $dhcp;
}

1;

