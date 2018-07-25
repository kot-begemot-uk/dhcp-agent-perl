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
use JSON::RPC2::JSONRPCSession;
use base 'JSON::RPC2::JSONRPCSession';
our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $arg = shift;
    my $CGI = shift;
    my $self = $class->SUPER::new($arg);
    bless $self, $class;
    $self->{CGI} = $CGI;
    return $self;
}

sub callback {
    my $self = shift;
    my $message = shift;
    if ((ref $message eq 'HASH') or (ref $message eq 'ARRAY')) {
        print $self->{CGI}->header(
            -type   =>  "application/json",
            -expires => 'now'
        );
        print encode_json($message);
    } else {
        croak "Neither HASH nor ARRAY passed to IO Callback function";
    }
}

sub receive_and_execute {
    my $self = shift;
    $self->execute($self->{CGI}->param('POSTDATA'));
    return undef;
}

1;
