# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package Net::Bridge::Entry;

use warnings;
use strict;
use utf8;
use Carp;

# struct __fdb_entry {
#   __u8 mac_addr[ETH_ALEN];    a6  6
#   __u8 port_no;               c   1
#   __u8 is_local;              c   1
#   __u32 ageing_timer_value;   l   4
#   __u8 port_hi;               c   1
#   __u8 pad0;                  c   1
#   __u16 unused;               S   2
# };
#

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $arg = shift;
    if (defined $arg) {
        $self->parse($arg);
    }
    return $self;
}

sub parse {
    my $self = shift;
    my $arg = shift;
    my @b;
    my ($port_no, $is_local, $aging, $port_hi, $pad0, $unused);
    ($b[0], $b[1], $b[2], $b[3], $b[4], $b[5], $port_no, $is_local, $aging, $port_hi, $pad0, $unused) =
            unpack("C6CCLCCS", $arg);
    $self->{mac} = sprintf("%02x:%02x:%02x:%02x:%02x:%02x", @b);
    $self->{port_no} = $port_no;
    $self->{aging} = $aging;
    $self->{port_hi} = $port_hi;
    $self->{is_local} = $is_local;
}

sub pretty_print {
    my $self = shift;
    return sprintf("%  d   %s  %d %d   %    d",
        $self->{port_no},
        $self->{mac},
        $self->{is_local},
        $self->{port_hi},
        $self->{aging}
    );
}

sub iface {
    my $self = shift;
    return $self->{port_no}; # we will later deref it
}

1;
