import 'dart:async';
import 'dart:io';
import 'package:postgresql/constants.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';
import 'package:yaml/yaml.dart';

import 'package:matcher/matcher.dart';


Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {

  int slowQueries = 5;
  int testConnects = 10;
  var queryPeriod = new Duration(milliseconds: 500);
  var stopAfter = new Duration(seconds: 30);
  
  var settings = new PoolSettings(connectionTimeout: new Duration(seconds: 10));
  
  var pool = new Pool(loadSettings().toUri(), settings)
    ..messages.listen(print);
  
  int queryError = 0;
  int connectError = 0;
  int connectTimeout = 0;

  new Timer.periodic(queryPeriod, (t) => print('connect timeouts: $connectTimeout  queryError: $queryError   connectError: $connectError '));
  
//  test('Connect', () {
//    var pass = expectAsync(() {});
  var pass = () {};

    testConnect(_) {
      pool.connect().then((conn) {
        conn.query("select 'oi';").toList()
          .then((rows) {
            expect(rows[0].toList(), equals(['oi']));
            conn.close();
          })
          .catchError((err) { print('Query error: $err'); queryError += 1; });
      })
      .catchError((err) { if (err is TimeoutException) { connectTimeout += 1; } else { print('Connect error: $err'); connectError += 1; } });
    }

    slowQuery() {
     pool.connect().then((conn) {
        conn.query("select generate_series (1, 100000);").toList()
          .then((rows) {
            expect(rows.length, 100000);
            conn.close();
          })
          .catchError((err) { print('Query error: $err'); queryError += 1; });
      })
      .catchError((err) { if (err is TimeoutException) { connectTimeout += 1; } else { print('Connect error: $err'); connectError += 1; } });
    }

    // Wait for initial connections to be made before starting
    var timer;
    pool.start().then((_) {
      timer = new Timer.periodic(queryPeriod, (_) {
        debug(pool);
        for (var i = 0; i < slowQueries; i++)
          slowQuery();
        for (var i = 0; i < testConnects; i++)
          testConnect(null);
      });
    }).catchError((err, st) {
      print('Error starting connection pool.');
      print(err);
      print(st);
    });

    new Future.delayed(stopAfter, () {
      print('stop');
      if (timer != null) timer.cancel();
      pool.stop();
      pass();
      new Future.delayed(new Duration(seconds: 1), () => exit(0)); //FIXME - something is keeping the process alive.
    });

//  });
  
}


debug(Pool pool) {

  int total = pool.connections.length;

  int available = pool.connections.where((c) => c.state == PooledConnectionState.available).length;

  int inUse = pool.connections.where((c) => c.state == PooledConnectionState.inUse).length;
  
  int waiting = pool.waitQueueLength;
  
  int leaked = pool.connections.where((c) => c.isLeaked).length;
  
  print('total: $total  available: $available  in-use: $inUse  waiting: $waiting leaked: $leaked');
  pool.connections.forEach(print);
  print('');
}
