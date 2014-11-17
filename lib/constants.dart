/// Export shorthand constants for enums at top-level.
library postgresql.constants;

import 'package:postgresql/postgresql.dart';
import 'package:postgresql/pool.dart';

const ConnectionState notConnected = ConnectionState.notConnected;
const ConnectionState socketConnected = ConnectionState.socketConnected;
const ConnectionState authenticating = ConnectionState.authenticating;
const ConnectionState authenticated = ConnectionState.authenticated;
const ConnectionState idle = ConnectionState.idle;
const ConnectionState busy = ConnectionState.busy;
const ConnectionState streaming = ConnectionState.streaming;
const ConnectionState closed = ConnectionState.closed;

const Isolation readCommitted = Isolation.readCommitted;
const Isolation repeatableRead = Isolation.repeatableRead;
const Isolation serializable = Isolation.serializable;

const TransactionState unknown = TransactionState.unknown;
const TransactionState none = TransactionState.none;
const TransactionState begun = TransactionState.begun;
const TransactionState error = TransactionState.error;

const PoolState initial = PoolState.initial;
const PoolState starting = PoolState.starting;
const PoolState running = PoolState.running;
const PoolState stopping = PoolState.stopping;
const PoolState stopped = PoolState.stopped;

