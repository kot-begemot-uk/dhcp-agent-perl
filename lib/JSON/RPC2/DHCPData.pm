# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::DHCPData;

##########
#
# Parent for any packages which implement the Data interface in
# YANG modeled JSON RPC2.0
#
##########

use warnings;
use strict;
use utf8;
use Carp;
use UUID 'uuid';
use Data::Dumper;
use JSON::MaybeXS;
use JSON::RPC2::SQLData;
use Net::Bridge;
use Net::DHCP::PacketIO;
use base 'JSON::RPC2::SQLData';


our $VERSION = '0.01';

our $LISTPATH = decode_json('{"dhcp-agent:interfaces":{"interface":[]}}');

sub new {
    my $class = shift; 
    my $dispatcher = shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    $self->{DISPATCH} = $dispatcher;
    $self->{HANDLER} = undef;
    return $self;
}

sub process_dcn {
    my $self = shift;
    my $ifaces = $self->read([0, "dhcp-agent", $LISTPATH]);
    my %TDL;
    foreach my $tdl (keys %{$self->{BRIDGES}}) {
        $TDL{$tdl} = 1;
    }
    foreach my $iface (@$ifaces) {
        if (! defined $self->{BRIDGES}->{$iface->{name}}) {
            $self->trace("Adding Relay mode on %s", $iface->{name});
            if (! defined $self->{HANDLER}) {
                $self->{HANDLER} = Net::DHCP::PacketIO->new(
                    $self->{verbose}
                );
            }
            $self->{HANDLER}->add_if($iface->{name}, $iface->{"dhcp-server"});
            $self->{DISPATCH}->register($self->{HANDLER});
        } else {
            if (defined $TDL{$iface->{name}}) {
                delete $TDL{$iface->{name}};
            }
        }
    }
    foreach my $to_delete (keys %TDL) {
        $self->trace("Deleting %s", $to_delete);
        $self->{DISPATCH}->unregister($self->{BRIDGES}->{$to_delete});
        # delif to come here
        #$self->{HANDLER}->del_if($iface->{name});
    }
}

sub commit {
    my $self = shift;
    # we need to figure out DCN-like behavior here
    my $args = shift;
    my $txid;
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
    } else {
        print STDERR "commit - unrecognized arg format!!!\n";
    }
    my $result = $self->SUPER::commit([$txid]);
    if ($$result == 0) {
        $self->trace("Commit failed - no processing for %s\n", $txid);
        return $result;
    }
    $self->process_dcn();
    return $result;
}

1;
