# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package IO::Dispatcher;
use warnings;
use strict;
use utf8;
use Carp;

use IO::Epoll;

our $VERSION = '0.01';

sub new {
    my $class = shift; 
    my $initial = shift;
    my $self = {};
    $self->{fds} = {};
    if (not defined $initial) {
        $initial = 10;
    }
    $self->{epfd} = epoll_create($initial);
    return bless $self, $class;
}

sub register {
    my $self = shift;
    my $session = shift;
    undef $@;
    my $fds = eval {$session->fds();};
    if (not defined $fds) {
        return undef;
    }
    foreach my $fd (@$fds) {
        my $fdno;
        if ((ref \$fd) eq "SCALAR") {
            $fdno = $fd;
        } else {
            $fdno = $fd->fileno();
        }
        if (defined $self->{fds}->{$fdno}) {
            next;
        }
        if (epoll_ctl( $self->{epfd}, EPOLL_CTL_ADD, $fdno, EPOLLIN) == 0) {
            ${$self->{fds}}{$fdno} = $session;
        }
    }
    return 1;
}

sub unregister {
    my $self = shift;
    my $session = shift;
    undef $@;
    my $fds = eval {$session->fds();};
    if (defined $@) {
        print STDERR "Error getting fds from session\n";
        return undef;
    }
    foreach my $fd (@$fds) {
        my $fdno;
        if ((ref $fd) eq "SCALAR") {
            $fdno = $fd;
        } else {
            $fdno = $fd->fileno();
        }
        if (epoll_ctl($self->{epfd}, EPOLL_CTL_DEL, $fdno, EPOLLIN) >= 0) {
            delete $self->{fds}->{$fdno};
        }
    }
    return 1;
}

sub run {
    my $self = shift;
    my @delayed = ();
    while (42) {
        # Message oriented epoll loop. This one is tricky as an epoll
        # indication does not indicate a full message from the stack,
        # it just indicates IO. However, if the message processing
        # is asynchronous (Hello ZMQ), an IO notification may never
        # come again and the stack gets stuck. 
        # We solve this by getting "I am not done yet" results from
        # the processing functions and enqueing them for a rerun
        my $event_list = epoll_wait($self->{epfd}, 64, 1);
        foreach my $event (@$event_list) {
            my $session = $self->{fds}->{$$event[0]};
            if (defined $session) {
                my $result = $session->receive_and_execute($$event[0]);
                if (defined $result) {
                    push @delayed, $result;
                }
            } 
        }
        my $num_delayed = $#delayed;
        while ($num_delayed > 0) {
            my $session = shift @delayed;
            my $result = $session->receive_and_execute();
            if (defined $result) { push @delayed, $result; } 
            $num_delayed--;
        }
    }
}

1;
