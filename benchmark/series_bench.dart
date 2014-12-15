import 'dart:async';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/postgresql_impl_3/postgresql_impl_3_cps.dart' as pg3;

main([List<String> args]) {
  var uri = 'postgresql://testdb:password@localhost:5433/testdb';
  var b = args.contains('bench3') ? bench3 : bench;
  var f = args.contains('bench3')
            ? pg3.ConnectionImpl.connect(new Settings.fromUri(uri), new Duration(seconds: 10))
            : connect(uri);
  
    f.then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then(b)
    .then((c) => c.close());
}

Future<Connection> bench(Connection conn) {
  int i = 0;
  var compl = new Completer<Connection>();
  conn.query('select * from generate_series(0, 1000000);')
    .listen((r) { i += r[0]; })
    .onDone(() {
      print(i);
      compl.complete(conn);
    });
  return compl.future;
}


Future<pg3.ConnectionImpl> bench3(pg3.ConnectionImpl conn) {
  int i = 0;
  var compl = new Completer<pg3.ConnectionImpl>();
  conn.query('select * from generate_series(0, 1000000);')
    .listen((r) { i += r[0]; })
    .onDone(() {
      print(i);
      compl.complete(conn);
    });
  return compl.future;
}

