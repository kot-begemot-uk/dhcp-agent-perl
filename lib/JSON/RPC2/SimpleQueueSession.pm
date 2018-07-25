# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::SimpleQueueSession;

use warnings;
use strict;
use utf8;
use Carp;

use JSON::MaybeXS;
use JSON::RPC2::JSONRPCSession;
use base 'JSON::RPC2::JSONRPCSession';
our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $arg = shift;
    my $strict = shift;
    my $self = $class->SUPER::new($arg, $strict);
    bless $self, $class;
    my @queue = ();
    $self->{queue} = \@queue;
    return $self;
}

sub callback {
    my $self = shift;
    my $message = shift;
    if (ref $message eq 'HASH') {
        push @{$self->{queue}}, $message;
    } elsif (ref $message eq 'ARRAY') {
        push @{$self->{queue}}, @$message;
    } else {
        croak "Neither HASH nor ARRAY passed to IO Callback function";
    }
}

1;
