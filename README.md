# JSON RPC2.0 driven Perl DHCP Agent
This repository contains the JSON RPC2.0 Driven Perl DHCP Agent

While this is a demo, it is fully functional and will interoperate with ODL to provide dhcp agent functionality as a relay. The man-in-the-middle functionality for option 82 which is
more common on various network shitches works, but is not useful without low level integration into a particular switch to filter the DHCP packets as needed.

It is also a demo of a simple SQL based high performance yang oriented datastore.  

## Principles of operation

The agent receives DHCP packets, adds DHCP Option 82 to them and forwards them to an upstream server by either sending them as a DHCP Relay or by writing them back to the network.

The configuration is performed entirely via ODL or another upstream client and will persist if a persistent datastore is supplied ot the agent via the --dsn argument

Interfaces for which an upstream server is specified as an IP address are considered to be in relay mode, if an upstream interface is not specified they are in MiTM (agent) mode.

## API documentation
The dhcp agent is documented via its model

## Packages

TODO

### Invocation 
The agent is invoked 

(c) 2018 Inocybe Technologies
(c) Cambridge Greys Ltd
