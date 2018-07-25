# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::JSONRPCSession;
use warnings;
use strict;
use utf8;
use Carp;

use JSON::MaybeXS;
use JSON::RPC2::Server;
use base 'IO::Dispatcher::Session';

our $VERSION = '0.01';

use constant ERR_PARSE  => JSON::RPC2::Server::ERR_PARSE;
use constant ERR_REQ    => JSON::RPC2::Server::ERR_REQ;
use constant ERR_METHOD => JSON::RPC2::Server::ERR_METHOD;
use constant ERR_PARAMS => JSON::RPC2::Server::ERR_PARAMS;
use constant ERR_INTERNAL => -32603;

sub new {
    my $class = shift; 
    my $self = $class->SUPER::new();
    $self->{handler} = shift;
    $self->{strict} = shift;
    return bless $self, $class;
}

sub register {
    my $self = shift;
    $self->{handler} = shift;
}

sub error {
    my $self = shift;
    my ($id, $code, $message, $data) = @_;
    my $err = {
            jsonrpc     => '2.0',
            id          => $id,
            error       => {
                code        => $code,
                message     => $message,
                (defined $data ? ( data => $data ) : ()),
            }
        };
    return $err;
}

sub result {
    my $self = shift;
    my $id = shift;
    my $res = {
            jsonrpc     => '2.0',
            id          => $id,
            result      => @_,
        };

    return $res;
}

sub _execute {
    my $self = shift;
    my $json = shift;

    if (!defined $json->{jsonrpc} || ref $json->{jsonrpc} || $json->{jsonrpc} ne '2.0') {
        return $self->error(undef, ERR_REQ, 'Invalid Request: expect {jsonrpc}="2.0".');
    }
    my $id;
    if (exists $json->{id}) {
        # Request
        if (ref $json->{id}) {
            return $self->error(undef, ERR_REQ, 'Invalid Request: expect {id} is scalar.');
        }
        $id = $json->{id};
    }
    if (!defined $json->{method} || ref $json->{method}) {
        return $self->error($id, ERR_REQ, 'Invalid Request: expect {method} is String.');
    }
    undef $@;

    # it is up to the method to deal with both named and list
    # params. 
    my $handler = $self->{handler};
    my $result;
    my $to_compile = '$result = $handler->' . $json->{method} . '($json->{params});'; 
    eval($to_compile);
    # we always invoke the callback (as a part of result/error)
    # in order to support protocols which need an ACK even for
    # notifications. It is the job of the callback to handle
    # these
    #
    if ($@) {
        return $self->error($id, ERR_INTERNAL, "Internal error $@.");
    }
    if (defined $self->{strict}) {
        if ((ref $result ne 'HASH') and (ref $result ne 'ARRAY')) {
            return $self->error($id, ERR_INTERNAL, "Invalid return type - must be a hash or array reference." . (ref $result));
        }
    }
    if (defined $id) {
        return $self->result($id, $result); 
    } else {
        return undef;
    }
}

sub execute {
    my ($self, $json) = @_;

    undef $@;

    my $request = ref $json ? $json : eval { decode_json($json) };
    if ($@) {
        return $self->callback($self->error(undef, ERR_PARSE, 'Parse error.'));
    }

    # single request

    if (ref $request eq 'HASH') {
        return $self->callback($self->_execute($request));
    }

    # support for batching

    if (ref $request ne 'ARRAY') {
        return $self->callback(
            $self->error(undef, ERR_REQ, 'Invalid Request: expect Array for Batch or Object for Single.')
        );
    }
    if (!@{$request}) {
        return $self->callback(
            self->error(undef, ERR_REQ, 'Invalid Request: empty Batch.')
        );
    }

    my @batch_reps;

    foreach my $batch_element (@{$request}) {
        push @batch_reps, $self->_execute($batch_element);
    }
    return $self->callback(@batch_reps);

}
1;
