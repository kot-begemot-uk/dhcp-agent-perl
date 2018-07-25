# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.

package IO::Dispatcher::Session;
use warnings;
use strict;
use utf8;
use Carp;

our $Session = '0.01';

sub new {
    my $class = shift; 
    my $self = {};
    $self->{fds} = [];
    return bless $self, $class;
}

sub fds {
    my $self = shift;
    return $self->{fds};
}

sub receive_and_execute {
    my $self = shift;
    croak("Please override receive handler");
}

sub callback {
    my $self = shift;
    croak("Please override callback");
}

1;
