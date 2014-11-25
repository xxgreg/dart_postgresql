import 'dart:async';

import 'package:matcher/matcher.dart';
import 'package:postgresql/constants.dart';
import 'package:postgresql/pool.dart';
import 'package:postgresql/postgresql.dart';


//_log(msg) => print(msg);

_log(msg) {}

debug(Pool pool) {

  int total = pool.connections.length;

  int available = pool.connections.where((c) => c.state == PooledConnectionState.available).length;

  int inUse = pool.connections.where((c) => c.state == PooledConnectionState.inUse).length;
  
  int waiting = pool.waitQueueLength;
  
  int leaked = pool.connections.where((c) => c.isLeaked).length;
  
  print('pool: ${pool.state} total: $total  available: $available  in-use: $inUse  waiting: $waiting leaked: $leaked');
  pool.connections.forEach(print);
  print('');
}

Duration secs(int s) => new Duration(seconds: s);
Duration millis(int ms) => new Duration(milliseconds: ms);

main() {

  int slowQueries = 5;
  int testConnects = 10;
  var queryPeriod = secs(1);
  var stopAfter = secs(30);
  
  var settings = new PoolSettings(
    connectionTimeout: secs(5),
    stopTimeout: millis(1));
  
  var uri = 'postgresql://testdb:password@localhost:5433/testdb';
  var pool = new Pool(uri, settings)
    ..messages.listen(print);
  
  int queryError = 0;
  int connectError = 0;
  int connectTimeout = 0;
  int queriesSent = 0;
  int queriesCompleted = 0;
  int slowQueriesSent = 0;
  int slowQueriesCompleted = 0;

  
  var logger = new Timer.periodic(queryPeriod, (t) {
    print('queriesSent: $queriesSent  queriesCompleted: $queriesCompleted  slowSent: $slowQueriesSent  slowCompleted: $slowQueriesCompleted  connect timeouts: $connectTimeout  queryError: $queryError   connectError: $connectError ');
    debug(pool);
  });
  
//  test('Connect', () {
//    var pass = expectAsync(() {});
  var pass = () {};

    testConnect(_) {
      pool.connect().then((conn) {
        _log('connected ${conn.backendPid}');
        queriesSent++;
        conn.query("select 'oi';").toList()
          .then((rows) {
            queriesCompleted++;
            expect(rows[0].toList(), equals(['oi']));            
          })
          .catchError((err) { _log('Query error: $err'); queryError++; })
          .whenComplete(() {
            _log('close ${conn.backendPid}');
            conn.close();
          });
      })
      .catchError((err) {
          if (err is TimeoutException) {
            //print(err);
            connectTimeout++;
          } else {
            _log('Connect error: $err'); connectError++;
          }
      });
    }

    slowQuery() {
     pool.connect().then((conn) {
       _log('slow connected ${conn.backendPid}');
       slowQueriesSent++;
        conn.query("select generate_series (1, 100000);").toList()
          .then((rows) {
            slowQueriesCompleted++;
            expect(rows.length, 100000);
          })
          .catchError((err) { _log('Query error: $err'); queryError++; })
          .whenComplete(() {
            _log('slow close ${conn.backendPid}');
            conn.close();
          });
      })
      .catchError((err) {
          if (err is TimeoutException) {
            //print(err);
            connectTimeout++;
          } else {
            _log('Connect error: $err'); connectError++;
          }
      });
    }

    // Wait for initial connections to be made before starting
    var timer;
    pool.start().then((_) {
      timer = new Timer.periodic(queryPeriod, (_) {
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
      pool.stop().then((_) => logger.cancel());
      pass();
    });

//  });
  
}
