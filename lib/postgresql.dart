library postgresql;

import 'dart:async';
import 'dart:collection';
import 'dart:crypto';
import 'dart:io';
import 'dart:utf' show encodeUtf8, decodeUtf8;

part 'buffer.dart';
part 'connection.dart';
part 'constants.dart';
part 'message_buffer.dart';
part 'query.dart';
part 'settings.dart';

/// Connect to a PostgreSQL database.
Future<Connection> connect(
    String username,
    String database,
    String password,
    {String host : 'localhost', int port: 5432}) {
  
  var settings = new _Settings(username, database, password, host: host, port: port);
  return _Connection._connect(settings);
}

/// A connection to a PostgreSQL database.
abstract class Connection {
  
  /// Queue a sql query to be run, returning a [Stream] of rows. 
  ///
  /// The data can be fetched from the rows by column name, or by index.
  ///
  /// Generally it is best to call [toList] on the stream and wait for all of
  /// the rows to be received.
  ///
  /// Example:
  ///
  ///     conn.query("select 'pear', 'apple' as a").toList().then((rows) {
  ///        print(row[0]);
  ///        print(row.a);
  ///     });
  ///
  Stream<dynamic> query(String sql);
  
  
  /// Queues a command for execution, and when done, returns the number of rows
  /// affected by the sql command.
  Future<int> execute(String sql);
  
  
  /// Close the current [Connection]. It is safe to call this multiple times.
  /// This will never throw an exception.
  void close();
}
