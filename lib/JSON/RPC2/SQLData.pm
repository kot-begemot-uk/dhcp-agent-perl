# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::SQLData;

##########
#
# Parent for any packages which implement the Data interface in
# YANG modeled JSON RPC2.0
#
##########

use warnings;
use strict;
use utf8;
use Carp;
use UUID 'uuid';
use Data::Dumper;
use JSON::MaybeXS;
use JSON::RPC2::Data;
use base 'JSON::RPC2::Data';

our $VERSION = '0.01';

sub new {
    my $class = shift; 
    my $DBH = shift;
    my $verbose = shift;
    my $self = $class->SUPER::new($verbose);
    bless $self, $class;
    if (defined $DBH) {
        $self->{DBH} = $DBH;
        $self->{RSTH} = $DBH->prepare("select path, value from data where path like ? and entity = ? and store = ?");
        $self->{MSTH} = $DBH->prepare("insert into data (path, value, entity, store) values (?, ?, ?, ?)");
        $self->{PSTH} = $DBH->prepare("replace into data (path, value, entity, store) values (?, ?, ?, ?)");
        $self->{DSTH} = $DBH->prepare("delete from data where path like ? and entity = ? and store = ? ");
    } 
    return $self;
}


sub psth {
    my $self = shift;
    return $self->{PSTH};
}

sub msth {
    my $self = shift;
    return $self->{MSTH};
}

sub dsth {
    my $self = shift;
    return $self->{DSTH};
}

sub read {
    my $self = shift;
    my $args = shift;
    my ($store, $entity, $path);
    if (ref $args eq "ARRAY") {
        $store = &JSON::RPC2::Data::makenumeric($$args[0]);
        $entity = $$args[1];
        $path = $$args[2];
    } elsif (ref $args eq "HASH") {
        $entity = $$args{"entity"};
        $store = &JSON::RPC2::Data::makenumeric($$args{"store"});
        $path = $$args{"path"};
    } else {
        print STDERR "read - unrecognized arg format!!!\n";
    }
    $self->trace("read %s, %s, %s\n", $store, $entity, Dumper($path));
    my $path8040 = $self->rfc8040_path($path);
    my $sth = $self->{RSTH};
    $sth->execute("$path8040%", $entity, $store);
    my %flatpacked;
    while (my $data = $sth->fetchrow_arrayref()) {
        $flatpacked{$$data[0]} = $$data[1];
    }
    my $result =  $self->flatunpack($path8040, \%flatpacked);
    print STDERR Dumper $result;
    return $result;
}

sub commit {
    my $self = shift;
    my $args = shift;
    my $txid;
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
    } else {
        print STDERR "commit - unrecognized arg format!!!\n";
    }
    my $transactions = $self->{txids}->{$txid};
    $self->trace("commit %s\n", $txid);
    if (!defined $transactions) {
        $self->trace("commit - empty data op list\n");
        return \0;
    }
    $self->{DBH}->begin_work();
    my %pipeline = (
        'put' => $self->psth(),
        'merge' => $self->msth(),
        'delete' => $self->dsth()
    );
    foreach my $op (@$transactions) {
        if ($op->op() eq 'delete') {
            print STDERR "DELETE ARG " . $op->data() . "\n";
            $pipeline{$op->op()}->execute($op->data(), $op->entity(), $op->store());
        } else {
            my $kvp = $op->data();
            foreach my $key (keys %$kvp) {
                my $rv = $pipeline{$op->op()}->execute($key, $$kvp{$key}, $op->entity(), $op->store());
                if ($rv < 0) {
                    $self->trace("DBD Op Error %s", $DBI::errstr)
                }
            }
        }
    }
    my $rc = $self->{DBH}->commit();
    if (!$rc) {
        $self->trace("DBD Commit Error %s", $DBI::errstr)
    }
    if ($rc) {
        return \1;
     } else {
        return \0;
     }
}

1;
