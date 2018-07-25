# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::DataOp;

##########
#
# Parent for any packages which implement the Data interface in
# YANG modeled JSON RPC2.0
#
##########

use warnings;
use strict;
use utf8;

our $VERSION = '0.01';



sub new {
    my $class = shift; 
    my $self = {};
    bless $self, $class;
    $self->{op} = shift;
    $self->{store} = shift;
    $self->{entity} = shift;
    $self->{data} = shift;
    return $self;
}

sub op {
    my $self = shift;
    return $self->{op};
}

sub store {
    my $self = shift;
    return $self->{store};
}
sub entity {
    my $self = shift;
    return $self->{entity};
}
sub data {
    my $self = shift;
    return $self->{data};
}
1;
