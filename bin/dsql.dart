import 'dart:async';
import 'dart:io';
import 'package:postgresql/postgresql.dart' as pg;

void main() {
  pg.connect('testdb', 'testdb', 'password').then((conn) {
    run(sql) => conn.query(sql).toList();
    readline(run);
  });
}

void readline(Future run(String sql)) {
  
  print("Type some SQL and press enter twice to run a command.");

  var buffer = new StringBuffer();
  
  stdin
    .transform(new StringDecoder(Encoding.UTF_8, ' '.codeUnitAt(0)))
    .transform(new LineTransformer())
    .listen((line) {
      if (line != '') {
        buffer.writeln(line);
        return;
      }
      
      var sql = buffer.toString();
      buffer = new StringBuffer();
      
      print('Running query...');
      run(sql)
        .then((result) => print('Result: $result\n'))
        .catchError((err) => print('Error: $err\n'));
    });
}

