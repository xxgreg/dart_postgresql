library postgresql.pool_async;

import 'dart:async';
import 'package:postgresql/postgresql.dart' as pg;
import 'package:postgresql/postgresql_pool_async_impl.dart';

abstract class PoolSettings {
  String get poolName;
  int get minConnections;
  int get maxConnections;
  Duration get startTimeout;
  Duration get stopTimeout;
  Duration get establishTimeout; //TODO better name
  Duration get connectionTimeout; //TODO better name
  Duration get maxLifetime;
  Duration get leakDetectionThreshold;
  bool get testConnections;
}

abstract class Pool {
  factory Pool(String databaseUri, [PoolSettings settings])
    => new PoolImpl(databaseUri, settings);
  Future start();
  Future stop();
  Future<pg.Connection> connect({String debugId});
}