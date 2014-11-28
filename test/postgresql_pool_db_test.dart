import 'dart:async';

import 'package:matcher/matcher.dart';
import 'package:postgresql/pool.dart';


//_log(msg) => print(msg);

_log(msg) {}

int secsSince(DateTime time) => time == null
  ? null
  : new DateTime.now().difference(time).inSeconds;

debug(Pool pool) {

  int total = pool.connections.length;

  int available = pool.connections.where((c) => c.state == PooledConnectionState.available).length;

  int inUse = pool.connections.where((c) => c.state == PooledConnectionState.inUse).length;
  
  int waiting = pool.waitQueueLength;
  
  int leaked = pool.connections.where((c) => c.isLeaked).length;
  
  int testing = pool.connections.where((c) => c.state == PooledConnectionState.testing).length;
  
  int connecting = pool.connections.where((c) => c.state == PooledConnectionState.connecting).length;
  
  print('pool: ${pool.state} total: $total  available: $available  in-use: $inUse  testing: $testing connecting: $connecting  waiting: $waiting leaked: $leaked');
  pool.connections.forEach((c) => print('${c.name} ${c.state} ${c.connectionState}  est: ${secsSince(c.established)}  obt: ${secsSince(c.obtained)}  rls: ${secsSince(c.released)}  leaked: ${c.isLeaked}'));
  print('');
}

Duration secs(int s) => new Duration(seconds: s);
Duration millis(int ms) => new Duration(milliseconds: ms);

main() {

  int slowQueries = 3;
  int testConnects = 1;
  var queryPeriod = secs(2);
  var stopAfter = secs(120);
  
  var pool = new Pool('postgresql://testdb:password@localhost:5433/testdb',
       connectionTimeout: secs(15),
       leakDetectionThreshold: secs(3),
       restartIfAllConnectionsLeaked: true)
    ..messages.listen((msg) => print('###$msg###'));
  
  int queryError = 0;
  int connectError = 0;
  int connectTimeout = 0;
  int queriesSent = 0;
  int queriesCompleted = 0;
  int slowQueriesSent = 0;
  int slowQueriesCompleted = 0;

  
  var loggerFunc = (t) {
    print('queriesSent: $queriesSent  queriesCompleted: $queriesCompleted  slowSent: $slowQueriesSent  slowCompleted: $slowQueriesCompleted  connect timeouts: $connectTimeout  queryError: $queryError   connectError: $connectError ');
    debug(pool);
  };
  
  var logger = new Timer.periodic(queryPeriod, loggerFunc);
  
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
            print('Connect error: $err'); connectError++;
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
            print('Connect error: $err'); connectError++;
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

    // Burst of connections
//     new Future.delayed(secs(15), () {
//       print('####################### BURST! #########################');
//       for (int i = 0; i < 30; i++) {
//         testConnect(null);
//       }
//     });
//    
//     new Future.delayed(secs(30), () {
//           print('####################### BURST! #########################');
//           for (int i = 0; i < 30; i++) {
//             testConnect(null);
//           }
//         });
//    
    new Timer.periodic(secs(10), (t) {
      pool.connect(debugName: 'leak!');
    });
        
     
    new Future.delayed(stopAfter, () {
      print('stop');
      if (timer != null) timer.cancel();
      pool.stop().then((_) { logger.cancel(); loggerFunc(null); });
      pass();
    });

//  });
  
}
