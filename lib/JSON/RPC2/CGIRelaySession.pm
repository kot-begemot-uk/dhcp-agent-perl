# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::CGISession;

use warnings;
use strict;
use utf8;
use Carp;

use JSON::MaybeXS;
use IO::Dispatch::Session;
use base 'IO::Dispatch::Session';
our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new($arg);
    bless $self, $class;
    $self->{CGI} = shift;
    $self->{ZMQ_CTX} = shift;
    $self->{ZMQ_URL} = shift;
    return $self;
}

sub callback {
    my $self = shift;
    my $message = shift;
    print $message;
}

sub receive_and_execute {
    my $self = shift;
    my $client = $self->{ZMQ_CTX}->socket(ZMQ_REQ);
    $client->connect($self->{ZMQ_URL});
    $client->send($self->{CGI}->param('POSTDATA'));
    print $self->{CGI}->header(
        -type   =>  "application/json",
        -expires => 'now'
    );
    print $client->recv();
    return undef;
}

1;
