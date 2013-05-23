library postgresql_test;

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
  
  setUp(() => pool = new Pool(loadSettings().toUri(), timeout: tout, min: 2, max: 5));
  
  test('Connect', () {
  	var pass = expectAsync0(() {});

    testConnect(_) {
    	pool.connect().then((conn) {
        print(pool);
    		conn.query("select 'oi';").toList()
    			.then(print)
    			.then((_) => conn.close())
          .catchError((err) => print('Query error: $err'));
    	})
      .catchError((err) => print('Connect error: $err'));
    }

    // Wait for initial connections to be made before starting
    var timer;
    pool.start().then((_) {
      timer = new Timer.periodic(new Duration(milliseconds: 1), testConnect);
    });

    new Future.delayed(new Duration(seconds: 2), () {
      timer.cancel();
      pool.destroy();
      print('Pool destroyed.');
      pass();
      exit(0); //FIXME - something is keeping the process alive.
    });

  });
}