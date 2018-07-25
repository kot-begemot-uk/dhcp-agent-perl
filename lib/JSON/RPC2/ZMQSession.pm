# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::ZMQSession;

use warnings;
use strict;
use utf8;
use Carp;

use JSON::MaybeXS;
use JSON::RPC2::JSONRPCSession;
use ZMQ::FFI qw (ZMQ_NOBLOCK);
use base 'JSON::RPC2::JSONRPCSession';
our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $arg = shift;
    my $socket = shift;
    my $strict = shift;
    $socket->die_on_error(0);
    my $self = $class->SUPER::new($arg, $strict);
    bless $self, $class;
    $self->{socket} = $socket;
    push @{$self->fds()}, $socket->get_fd();
    return $self;
}

sub callback {
    my $self = shift;
    my $message = shift;
    if ((ref $message eq 'HASH') or (ref $message eq 'ARRAY')) {
        $self->{socket}->send(encode_json($message));
    } else {
        croak "Neither HASH nor ARRAY passed to IO Callback function";
    }
}

sub receive_and_execute {
    my $self = shift;
    if ($self->{socket}->has_pollin()) {
        $self->execute($self->{socket}->recv(ZMQ_NOBLOCK));
        return undef;
    } else {
        # message has been received, but is not ready from the ZMQ stack yet
        # we need to schedule a delayed processing here
        return $self;
    }
}

1;
