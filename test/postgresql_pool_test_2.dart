import 'dart:async';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/postgresql_pool.dart';
import 'package:yaml/yaml.dart';

Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {

  Pool pool;
  int tout = 2 * 60 * 1000; // Should be longer than usage

  setUp(() {
    pool = new Pool(loadSettings().toUri(), timeout: tout, min: 2, max: 2);
    pool.messages.listen(print);
  });

  test('Connect', () {
  	var pass = expectAsync(() {});

    testConnect(_) {
      print(pool.diagnostics);
    	pool.connect(null, 'testConnect').then((conn) {
    		conn.query("select 'passed';").toList()
    			.then(print)
    			.then((_) => conn.close())
          .catchError((err) => print('Query error: $err'));
    	})
      .catchError((err) => print('Connect error: $err'));
    }

    slowQuery() {
     print(pool);
     pool.connect(null, 'testConnect').then((conn) {
        conn.query("select generate_series (1, 1000);").toList()
          .then((_) => print('slow query done.'))
          .then((_) => new Future.delayed(new Duration(seconds: 1)))
          .then((_) => conn.close())
          .catchError((err) => print('Query error: $err'));
      })
      .catchError((err) => print('Connect error: $err'));
    }

    // Wait for initial connections to be made before starting
    var timer;
    pool.start().then((_) {
      slowQuery();
      slowQuery();
      testConnect(null);

    }).catchError((err, st) {
      print('Error starting connection pool.');
      print(err);
      print(st);
    });

    new Future.delayed(new Duration(seconds: 3), () {
      if (timer != null) timer.cancel();
      print(pool.diagnostics);
      pool.destroy();
      print('Pool destroyed.');
      pass();
      exit(0); //FIXME - something is keeping the process alive.
    });

  });
}