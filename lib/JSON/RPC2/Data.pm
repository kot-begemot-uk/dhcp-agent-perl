# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package JSON::RPC2::Data;

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
use JSON::RPC2::DataOp;

use JSON::MaybeXS;

our $VERSION = '0.01';

my %StoreForms = (
    0 => 0,
    1 => 1,
    'config' => 0,
    'oper' => 1
);

sub makenumeric {
    my $arg = shift;
    return $StoreForms{$arg};
}

sub new {
    my $class = shift; 
    my $self = {};
    bless $self, $class;
    $self->{verbose} = shift;
    $self->{txids} = {};
    $self->{key_order} = {};
    $self->trace("init at verbosity %i\n",  $self->{verbose});
    return $self;
}

sub register_key_order {
    my $self = shift;
    my $path = shift;
    my $order_ref = shift;
    $self->{key_order}->{$path} = $order_ref;
}

sub trace {
    my $self = shift;
    if (defined $self->{verbose}) {
        my $format = shift;
        printf STDERR $format, @_;
    }
}

sub order_keys {
    my $self = shift;
    my $path_ref = shift;
    my $keys_ref = shift;
    my $ordering = $self->{key_order}->{join('/',@$path_ref)};
    my @result;
    if (! defined $ordering) {
        my @order = keys %$keys_ref;
        $ordering = \@order;
    }
    foreach my $key (@$ordering) {
        push @result, $$keys_ref{$key};
    }
    return @result;
}

sub rfc8040_path {
    my $self = shift;
    my $path = shift;
    my @result = ();
    while (defined $path) {
        if (ref $path eq "HASH") {
            my %list_keys;
            my $next_path;
            foreach my $next (keys %$path) {
                if (ref $$path{$next} eq "HASH") {
                    $next_path = $$path{$next};
                    push @result, $next;
                } elsif (ref $$path{$next} eq "ARRAY") {
                    $next_path = $$path{$next}[0];
                    push @result, $next;
                } else {
                    $list_keys{$next} = $$path{$next};
                }
                
            }
            if (scalar(keys %list_keys) > 0) {
                push @result, join (",", $self->order_keys(\@result, \%list_keys));
            }
            $path = $next_path;
        }
        if (ref $path eq "ARRAY") {
            $path = $$path[0];
        }
        if (ref $path eq "SCALAR") {
            return join("/", @result);
        }
    }
    return join("/", @result);
}

sub flatpack_container {
    my $self = shift;
    my $path = shift;
    my $data_ref = shift;
    my $res = {};
    for my $key (keys %$data_ref) {
        my $data_type = ref $$data_ref{$key};
        if (($data_type eq '') || ($data_type eq 'JSON::PP::Boolean')) {
            my $snippet = {};
            $$snippet{$key} = $$data_ref{$key};
            $$res{join("/", $path, $key)} = encode_json($snippet);
        } else {
            my $next_level = $self->flatpack(join('/', $path, $key), $$data_ref{$key});
            foreach my $nkey (keys %$next_level) {
                $$res{$nkey} = $$next_level{$nkey};
            }
        }
    }
    return $res;
}

sub flatpack_list {
    my $self = shift;
    my $path = shift;
    my $data_ref = shift;
    my $ordering = $self->{key_order}->{$path};
    my $res = {};
    if (!defined $ordering) {
        # leaf list
        $$res{$path} = encode_json($data_ref);
        return $res;
    }

    for my $elem (@$data_ref) {
        my @kv8040;
        for my $kv (@$ordering) {
            push @kv8040, $$elem{$kv};
        }
        my $next_level = $self->flatpack(join("/", $path, join(",", @kv8040)), $elem);
        foreach my $nkey (keys %$next_level) {
            $$res{$nkey} = $$next_level{$nkey};
        }
    }
    return $res;
}

sub flatpack {
    my $self = shift; # we may need this for schema refs
    my $path = shift;
    my $data_ref = shift;
    if (ref $data_ref eq "HASH") {
        return $self->flatpack_container($path, $data_ref);
    } elsif (ref $data_ref eq "ARRAY") {
        return $self->flatpack_list($path, $data_ref);
    } else {
        print STDERR "Dazed and confused, should not be here\n";
        return undef;
    }
}


sub create_element {
    my $self = shift;
    my $data_path = shift;
    my $path = shift;
    my $json_data = shift;
    my $data_so_far = shift;

    my $data_ref;
    if (ref \$json_data eq "SCALAR") {
        $data_ref = decode_json($json_data);
    } else {
        $data_ref = $json_data;
    }

    my $ref_data = $data_so_far;
    my @path_so_far = ();
    my $this_is_a_key = 0;
    if (ref $data_so_far eq "ARRAY") {
        $this_is_a_key = 1;
    }
    my $ordering = $self->{key_order}->{join('/', $data_path, @path_so_far)};
    my @path_elements = split(/\//, $path);
    my $last_key = $path_elements[$#path_elements];
    foreach my $path_element (@path_elements) {
        push @path_so_far, $path_element;
        if ($this_is_a_key) {
            my $found;
            foreach my $list_element (@$data_so_far) {
                my $index = 0;
                $found = 1;
                foreach my $value (split(/,/, $path_element)) {
                    if (!($$list_element{$$ordering[$index++]} eq $value)) {
                        $found = 0;
                        next;
                    }
                }
                if ($found) {
                    $data_so_far = $list_element;
                    last;
                }
            }
            if (! $found) {
                my $add_hash = {};
                my $index = 0;
                foreach my $value (split(/,/, $path_element)) {
                    $$add_hash{$$ordering[$index++]} = $value;
                }
                push @$data_so_far, $add_hash;
                $data_so_far = $add_hash;
            }
            $this_is_a_key = 0;
        } else {
            if (defined $data_path) {
                $ordering = $self->{key_order}->{join('/', $data_path, @path_so_far)};
            } else {
                $ordering = $self->{key_order}->{join('/', @path_so_far)};
            }
            if (defined $ordering) {
                $this_is_a_key = 1;
                if (! defined $$data_so_far{$path_element}) {
                    $$data_so_far{$path_element} = [];
                }
            } else {
                if (! defined $$data_so_far{$path_element}) {
                    if ($path_element eq $last_key) {
                        if (ref $data_ref eq "HASH") {
                            # flat packed leaves 
                            $$data_so_far{$path_element} = $$data_ref{$last_key};
                        } else {
                            # leaf lists and blobbed data
                            $$data_so_far{$path_element} = $data_ref;
                        }
                    } else {
                        $$data_so_far{$path_element} = {};
                    }
                }
            }
            $data_so_far = $$data_so_far{$path_element};
        }
    }
}

sub flatunpack {
    my $self = shift;
    my $path = shift;
    my $data_ref = shift;
    my $dsf;
    if (defined $self->{key_order}->{$path}) {
        $dsf = [];
    } else {
        $dsf= {};
    }
    foreach my $key (keys %$data_ref) {
        if (defined $path) {
            if ($key =~ /$path\/(.*)/) {
                $self->create_element($path, $1, $$data_ref{$key}, $dsf);
            } 
        } else {
            $self->create_element($key, undef, $$data_ref{$key}, $dsf);
        }
    }
    return $dsf;
}

sub read {
    my $self = shift;
    my $args = shift;
    my ($store, $entity, $path);
    if (ref $args eq "ARRAY") {
        $store = &makenumeric($$args[0]);
        $entity = $$args[1];
        $path = $$args[2];
    } elsif (ref $args eq "HASH") {
        $entity = $$args{"entity"};
        $store = &makenumeric($$args{"store"});
        $path = $$args{"path"};
    } else {
        print STDERR "Unrecognized arg format!!!\n";
    }
    $self->trace("read %i, %s, %s\n", $store, $entity, Dumper($path));
    return undef;
}

sub exists {
    my $self = shift;
    my $args = shift;
    my ($store, $entity, $path);
    if (ref $args eq "ARRAY") {
        $store = &makenumeric($$args[0]);
        $entity = $$args[1];
        $path = $$args[2];
    } elsif (ref $args eq "HASH") {
        $entity = $$args{"entity"};
        $store = &makenumeric($$args{"store"});
        $path = $$args{"path"};
    } else {
        print STDERR "Unrecognized arg format!!!\n";
    }
    $self->trace("exists via read %i, %s, %s\n", $store, $entity, Dumper($path));
    my $result = $self->read([$store, $entity, $path]);
    if (defined $result) {
        if (scalar(keys %$result) > 0) {
            return \1; # this wierd sh*t forces json encoder to emit true
        }
    } 
    return \0; # ditto for false
}

sub put {
    my $self = shift;
    my $args = shift;
    my ($txid, $store, $entity, $path, $data);
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
        $store = &makenumeric($$args[1]);
        $entity = $$args[2];
        $path = $$args[3];
        $data = $$args[4];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
        $entity = $$args{"entity"};
        $store = &makenumeric($$args{"store"});
        $path = $$args{"path"};
        $path = $$args{"data"};
    } else {
        print STDERR "Put - unrecognized arg format!!!\n";
    }
    $self->trace("put %s, %i, %s, %s, %s \n", $txid, $store, $entity, Dumper($path), Dumper($data));
    my $ops = $self->{txids}->{$txid};
    if (defined $ops) {
        push @$ops, JSON::RPC2::DataOp->new("put", $store, $entity, $self->flatpack($self->rfc8040_path($path), $data));
    }
    return undef;
}

sub merge {
    my $self = shift;
    my $args = shift;
    my ($txid, $store, $entity, $path, $data);
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
        $store = &makenumeric($$args[1]);
        $entity = $$args[2];
        $path = $$args[3];
        $data = $$args[4];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
        $entity = $$args{"entity"};
        $store = &makenumeric($$args{"store"});
        $path = $$args{"path"};
        $path = $$args{"data"};
    } else {
        print STDERR "Merge - nrecognized arg format!!!\n";
    }
    $self->trace("merge %s, %i, %s, %s, %s \n", $txid, $store, $entity, Dumper($path), Dumper($data));
    my $ops = $self->{txids}->{$txid};
    if (defined $ops) {
        push @$ops, JSON::RPC2::DataOp->new("merge", $store, $entity, $self->flatpack($self->rfc8040_path($path), $data));
    }
    return undef;
}

sub delete {
    my $self = shift;
    my $args = shift;
    my ($txid, $store, $entity, $path);
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
        $store = &makenumeric($$args[1]);
        $entity = $$args[2];
        $path = $$args[3];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
        $entity = $$args{"entity"};
        $store = &makenumeric($$args{"store"});
        $path = $$args{"path"};
    } else {
        print STDERR "Delete - unrecognized arg format!!!\n";
    }
    $self->trace("delete %s, %i, %s, %s, %s \n", $txid, $store, $entity, Dumper($path));
    my $ops = $self->{txids}->{$txid};
    if (defined $ops) {
        push @$ops, JSON::RPC2::DataOp->new("delete", $store, $entity, $self->rfc8040_path($path) . "%");
    }
    return undef;
}

sub txid {
    my $self = shift;
    $self->trace("txid");
    return $self->alloc_txid();
}

sub alloc_txid {
    my $self = shift;
    for (my $i=0; $i<10; $i++) {
        my $txid = uuid();
        if (! defined ($self->{txids}->{$txid})) {
            $self->{txids}->{$txid} = []; 
            $self->trace("Allocated txid %s\n", $txid);
            return $txid;
        }
    }
    return undef;
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
        print STDERR "Commit - unrecognized arg format!!!\n";
    }
    if (defined $self->{txids}->{$txid}) {
        $self->trace("Commit not implemented");
        delete $self->{txids}->{$txid};
        return \1;
    }
}

sub cancel {
    my $self = shift;
    my $args = shift;
    my $txid;
    if (ref $args eq "ARRAY") {
        $txid = $$args[0];
    } elsif (ref $args eq "HASH") {
        $txid = $$args{"txid"};
    } else {
        print STDERR "Cancel - unrecognized arg format!!!\n";
    }
    $self->trace("Cancel %s", $txid);
    if (defined $self->{txids}->{$txid}) {
        delete $self->{txids}->{$txid};
    }
    return \1;
}

sub error {
    my $self = shift;
    my $txid = shift;
    if (defined $self->{txids}->{$txid}) {
        return $self->{txids}->{$txid}->error();
    }   
}

1;
