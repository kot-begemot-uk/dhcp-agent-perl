# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package Net::DHCP::PacketIO::State;

use warnings;
use strict;
use utf8;
use Carp;

our @DICT = ("ifinfo", "src", "dst", "src_mac", "dest_mac");

sub new {
    my $class = shift;
    my %params = @_;
    my $self = {};
    for my $param (@DICT){
        $self->{$param} = $params{$param};
    }
    $self->{"stamp"} = gmtime();
    bless $self, $class;
    return $self;
}

sub touch {
    my $self = shift;
    $self->{"stamp"} = gmtime();
}

1;
