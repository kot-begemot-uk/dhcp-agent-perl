# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package Net::Bridge::FDB;


use warnings;
use strict;
use utf8;
use Carp;
use Net::Bridge::Entry;
use IO::File;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $iface = shift;
    my $self = {};
    bless $self, $class;
    $self->{iface} = $iface;
    $self->{iftable} = {};
    $self->{table} = {};
    return $self;
}


sub read_ifaces {
    my $self = shift;
    my $bridge = $self->{iface};
    $self->{iftable} = {};
    opendir(INTERFACES, "/sys/class/net/$bridge/brif");
    for my $iface (grep {!/^\./} readdir(INTERFACES)) {
        my $port_fd = IO::File->new("/sys/class/net/$bridge/brif/$iface/port_no");
        my $port_hd = $port_fd->getline();
        $port_hd =~ s/\n//g;
        $self->{iftable}->{hex $port_hd} = $iface;
        $port_fd->close();
    }
}


sub readfdb {
    my $self = shift;
    my $iface = $self->{iface};
    my $io = IO::File->new("/sys/class/net/$iface/brforward", "r");
    if (! defined $io) {
        return 0;
    }
    $self->read_ifaces();
    my $buf = "";
    my $table = $self->{table};
    while ($io->read ($buf, 16)) {
        my $new_entry = Net::Bridge::Entry->new($buf);
        if (! defined $$table{$new_entry->iface()}) {
            my @lst = ();
            $$table{$new_entry->iface()} = \@lst;
        }
        my $mac_lst = $$table{$new_entry->iface()};
        push @$mac_lst, $new_entry;
    }
    $io->close();
    return 1;
}

sub find_mac {
    my $self = shift;
    my $arg = lc(shift); # make it lowercase so same as parse results
    foreach my $ifno (keys %{$self->{table}}) {
        my $table = $self->{table}->{$ifno};
        foreach my $entry (@$table) {
            if ($entry->{mac} eq $arg) {
                return $self->{iftable}->{$ifno};
            }
        }
    }
    return undef;
}

sub scan_and_find_mac {
    my $self = shift;
    if ($self->readfdb()) {
        return $self->find_mac(shift);
    } else {
        return $self->{iface};
    }
}

1;
