# Copyright (c) 2018 Inocybe Technologies.
# Portions copyright (c) Cambridge Greys Ltd.
#
# All rights reserved. This program is free software;
# you can redistribute it and/or  modify it under the
# same terms as Perl itself.
package Net::DHCP::PacketIO;

use warnings;
use strict;
use utf8;
use English;
use Carp;
use Net::Pcap;
use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::UDP;
use IO::Interface::Simple;
use IO::Socket::INET;
use Net::DHCP::Packet;
use Net::DHCP::Constants;
use Data::Dumper;
use Net::DHCP::PacketIO::State;

our $DHCPSERVER = 67;
our $DHCPCLIENT = 68;

use base 'IO::Dispatcher::Session';

our $counter = 0;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    my $verbose = shift;
    bless $self, $class;
    $self->{IFACES} = {};
    $self->{state} = {};
    $self->{verbose} = $verbose;
    my $lsocket = IO::Socket::INET->new(
        LocalPort => $DHCPSERVER,
        Proto => 'udp',
        ReuseAddr => 1,
        ReusePort => 1,
        Blocking => 0,
    ) || die "Cannot bind DHCP Socket $DHCPSERVER error $@\n";
    $self->{main_fd} = $lsocket;
    push @{$self->{fds}}, $lsocket;

    return $self;
}

sub trace {
    my $self = shift;
    if (defined $self->{verbose}) {
        my $format = shift;
        printf STDERR $format, @_;
    }
}

# create file descriptors 

sub add_if {
    my $self = shift;
    my $iface = shift;
    my $dst = shift;

    my $err;
    $self->trace("Common io init for %s %s\n", $iface, $dst);

    my $if = IO::Interface::Simple->new($iface);

    my $pcap = pcap_open_live($iface, 1500, 1, 0, \$err);
    my $filter = "";
    pcap_compile($pcap, \$filter, "udp and dst port 67", 1, 0);
    pcap_setfilter($pcap, $filter);
    my $io = IO::Handle->new();
    $io->fdopen(pcap_fileno($pcap), "w");

    my $ifinfo = {};
    $ifinfo->{dst} = $dst;
    $ifinfo->{iface} = $iface;
    $ifinfo->{ip} = $if->address;
    $ifinfo->{hwaddr} = $if->hwaddr;
    $ifinfo->{bridge} = Net::Bridge->new($iface);
    $ifinfo->{handle} = $io;
    $ifinfo->{pcap} = $pcap;
    $self->{IFACES}->{$if->index} = $ifinfo;
    push @{$self->{fds}}, $io;
    $self->trace("init for interface %s complete\n", $iface);
    return 1;
}

sub ifinfo_from_handle {
    my $self = shift;
    my $fd = shift;
    foreach my $iface (keys %{$self->{IFACES}}) {
        if ($self->{IFACES}->{$iface}->{handle}->fileno() == $fd->fileno()) {
            return $self->{IFACES}->{$iface};
        }
    }
    return undef;
}

sub receive_and_execute {
    my $self = shift;

    my $rxfd = $self->handle_from_fdno(shift);
    my $ifinfo;
    my $dhcp;

    if ($rxfd == $self->{main_fd}) {
        my $buffer = "";
        if (! defined $rxfd->recv($buffer, 1500)) {
            return;
        }
        if (length($buffer) == 0) {
            return;
        }   
        $dhcp = Net::DHCP::Packet->new($buffer);
        if ((!defined $dhcp) || ($dhcp->op() == &Net::DHCP::Packet::BOOTREQUEST())) {
            # we ignore any BOOTREQUESTS rx-ed via UDP
            return;
        }
    } else {
        $ifinfo = $self->ifinfo_from_handle($rxfd);
        if (! defined $ifinfo) {
            $self->trace("Cannot find ifinfo\n");
        }
        my %header;
        my $packet;
        if (pcap_next_ex($ifinfo->{pcap}, \%header, \$packet) < 1) {
            return 0;
        }

        my $eth_obj = NetPacket::Ethernet->decode($packet);
        my $ip_obj = NetPacket::IP->decode($eth_obj->{data});
        my $udp_obj = NetPacket::UDP->decode($ip_obj->{data});

        $dhcp = Net::DHCP::Packet->new($udp_obj->{data});

        if (defined $dhcp->getOptionValue (DHO_DHCP_AGENT_OPTIONS())) {
            # prevent looping
            return;
        }

        if (! defined $dhcp) {
            $self->trace("Failed to parse packet!!!\n");
            return;
        }

        $self->trace("RAW rx packet payload\n %s\n", $dhcp->toString());
        if ($dhcp->op() == &Net::DHCP::Packet::BOOTREQUEST()) {
            # we got a broadcast - we keep state info only for that for now
            $self->{state}->{$dhcp->xid()} = Net::DHCP::PacketIO::State->new(
                'ifinfo' => $ifinfo,
                'src_mac' => $eth_obj->{src_mac},
                'dest_mac' => $eth_obj->{dest_mac}
            );
        }
    }
    my $bridge;
    if (defined $ifinfo) {
        $bridge = $ifinfo->{bridge};
    }
    $self->callback($dhcp, $bridge);
}

# tx a dhcp packet. makes all decisions
# depending on how, where, what and who needs to do
#
sub tx_to_client {
    my $self = shift;
    my $dhcp = shift;
    $self->trace("TX to Client\n");

    my $state = $self->{state}->{$dhcp->xid()};
    if (!defined $state) {
        $self->trace("No state entry for %s\n", $dhcp->xid());
        return undef;
    }

    my $udp_obj = &new_udp_obj($dhcp->serialize());
    my $ip_obj = &new_ip_obj();
    $ip_obj->{data} = $udp_obj->encode($udp_obj, $ip_obj);
    my $eth_obj = &new_eth_obj($ip_obj->encode());
    $eth_obj->{src_mac} = $state->{src_mac};
    $eth_obj->{dest_mac} = $state->{dest_mac};
    pcap_sendpacket($state->{ifinfo}->{pcap}, $eth_obj->encode());
    delete $self->{state}->{$dhcp->xid()};
}



# tx a dhcp packet. makes all decisions
# depending on how, where, what and who needs to do
#

sub tx_to_server {
    my $self = shift;
    my $dhcp = shift;
    $self->trace("TX to Server %s\n", $dhcp->toString());
    my $state = $self->{state}->{$dhcp->xid()};
    if (!defined $state) {
        $self->trace("No state entry for %s\n", $dhcp->xid());
        return undef;
    }
    my $ifinfo = $state->{ifinfo};
    if (defined $ifinfo->{dst}) {
        $dhcp->giaddr($ifinfo->{ip});
        $self->trace("Sending Relay to %i %s\n", $DHCPSERVER, $ifinfo->{dst});
        $self->trace("Packet %s\n", $dhcp->toString());
        open F, ">/tmp/packet-$$-$counter.bin"; $counter++;
        print F $dhcp->serialize();
        close F;
        my $dst = sockaddr_in($DHCPSERVER, inet_aton($ifinfo->{dst}));
        $self->{fds}->[0]->send($dhcp->serialize(), 0, $dst);
    } else {
        $self->trace("Sending MIM on %s\n", $state->{ifinfo}->{iface});
        my $udp_obj = &new_udp_obj($dhcp->serialize());
        my $ip_obj = &new_ip_obj();
        $ip_obj->{data} = $udp_obj->encode($udp_obj, $ip_obj);
        my $eth_obj = &new_eth_obj($ip_obj->encode());
        $eth_obj->{src_mac} = $state->{src_mac};
        $eth_obj->{dest_mac} = $state->{dest_mac};
        pcap_sendpacket($state->{ifinfo}->{pcap}, $eth_obj->encode());
    }
}


# rx off a fd and produce a dhcp parsed packet
# choses the correct rx method depending on the rx
# settings

sub handle_from_fdno {
    my $self = shift;
    my $fdno = shift;
    foreach my $fd (@{$self->{fds}}) {
        if ($fdno == $fd->fileno()) {
            return $fd;
        }
    }
}

sub callback {
    my $self = shift;
    my $dhcp = shift;
    my $bridge = shift;
    if (defined $dhcp) { 
        if (defined $bridge) {
            $dhcp = $bridge->process($dhcp);
        }
        if ($dhcp->op() == &Net::DHCP::Packet::BOOTREQUEST()) {
            $self->tx_to_server($dhcp);
        } else {
            $self->tx_to_client($dhcp);
        }
    }
}

sub new_eth_obj {
    my $eth_obj = NetPacket::Ethernet->decode(undef);
    $eth_obj->{data} = shift;
    $eth_obj->{type} = 2048;
    $eth_obj->{src_mac} = 'ffffffffffff';
    $eth_obj->{dest_mac} = 'ffffffffffff';
    return $eth_obj;
}

sub new_ip_obj {
    my $ip_obj = NetPacket::IP->decode(undef);
    my $self->{data} = shift;

    # stolen from a dhcp dump

    $ip_obj->{foffset} = 0;
    $ip_obj->{src_ip} = '0.0.0.0';
    $ip_obj->{dest_ip} = '255.255.255.255';
    $ip_obj->{options} = '';
    $ip_obj->{cksum} = 0;
    $ip_obj->{id} = 0;
    $ip_obj->{len} = 0;
    $ip_obj->{tos} = 16;
    $ip_obj->{ttl} = 128;
    $ip_obj->{ver} = 4;
    $ip_obj->{hlen} = 5;
    $ip_obj->{flags} = 0;
    $ip_obj->{proto} = 17;
    return $ip_obj;
}

sub new_udp_obj {
    my $udp_obj = NetPacket::UDP->decode(undef);

    $udp_obj->{data} = shift;
    $udp_obj->{cksum} = 0;
    $udp_obj->{dest_port} = 68;
    $udp_obj->{src_port} = 67;
    $udp_obj->{len} = 0;
    return $udp_obj;
}


1;
