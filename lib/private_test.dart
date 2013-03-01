part of postgresql;

void private_test() {
  _Connection c;
  connect('testdb', 'testdb', 'password').then((conn) {
    c = conn;
    return conn.execute("update test set a = 2;");
  }).then((result) {
    print('result: $result');
    c.close();
  });
}

void private_test7() {
  _Connection c;
  var s = new _Settings('testdb', 'testdb', 'password');
  _Connection._connect(s).then((conn) {
    c = conn;
    print(conn);
    var stream = conn.query("select * from test;");
    var stream2 = conn.query("select * from date_test;");
    return Future.wait([stream.toList(), stream2.toList()]);
  }).then((list) {
    print(list);
    c.close();
  });
}

void private_test6() {
  _Connection c;
  var s = new _Settings('testdb', 'testdb', 'password');
  _Connection._connect(s).then((conn) {
    c = conn;
    print(conn);
    var stream = conn.query("fdsfsdfdsf");
    return stream.toList();
  }).then(
      (list) { print('nope.'); },
      onError: (err) {
        print(err.error);
  });
}

void private_test5() {
  var s = new _Settings('testdb', 'testdb', 'password');
  _Connection._connect(s).then((conn) {
    print(conn);
    var stream = conn._sendQuery("select * from date_test;");
    return stream.toList();
  }).then((list) {
    int i = 0;
    for(var row in list) {
      print('Row ${i++}');
      for (var val in row.toList()) {
        var type = _basicType(val);
        print('    $val ($type)');
      }
    }
  });
}

String _basicType(val) {
  var type = '?';
  
  if (val is bool)
    type = 'bool';
  else if (val is int)
    type = 'int';
  else if (val is double)
    type = 'double';
  else if (val is String)
    type = 'String';
  else if (val is List<int>)
    type = 'List<int>';
  else if (val is DateTime)
    type = 'DateTime';
  
  return type;
}

void private_test2() {
  
  var data = combine([
    createDataRowMessage(["a", "b", "c"]),
    createDataRowMessage(["ddsfdsf", "e", "f"]),
    createDataRowMessage(["g", "h", "i"]),
    createDataRowMessage(["j", "k", "l"])]);
  
  // Split in the middle of a row to test async code.
  int spitPoint = 12;
  var mocket = new Mocket([
    data.take(12).toList(),
    data.skip(12).toList()]);
      
  var s = new _Settings('testdb', 'testdb', 'password');
  var c = new _Connection(mocket, s);
    
  for (int i = 0; i < 10; i++)
    c._readData();
}

List<int> combine(List<List<int>> messages) {
  var result = new List<int>();
  for (var msg in messages) {
      result.addAll(msg);
  }
  return result;
}

// All columns are type String - ascii only - no unicode it will probably break.
List<int> createDataRowMessage(List<String> values) {
  var msg = new List<int>();
  
  msg.add(_MSG_DATA_ROW);
  msg.addAll([0, 0, 0, 0]);
  msg.addAll(encodeUint16(values.length));
  
  for (var val in values) {
    msg.addAll(encodeUint32(val.length));
    for (int c in val.codeUnits) {
      if (c > 127 || c < 0)
        c = '?'.codeUnitAt(0);
      msg.add(c);
    }
  }
  
  // Set length.
  var len = msg.length - 1;
  var bytes = encodeUint32(len);
  msg[1] = bytes[0];
  msg[2] = bytes[1];
  msg[3] = bytes[2];
  msg[4] = bytes[3];
  
  return msg;
}

List<int> encodeUint16(int i) {
  var buffer = new List<int>(2);
  buffer[0] = i >> 8;
  buffer[1] = i;
  return buffer;
}

List<int> encodeUint32(int i) {
  var buffer = new List<int>(4);
  buffer[0] = i >> 24;
  buffer[1] = i >> 16;
  buffer[2] = i >> 8;
  buffer[3] = i;
  return buffer;
}

class Mocket implements Socket {
  Mocket(this.data);
  int i = 0;
  List<List<int>> data;
  List<int> read([int len]) {
    if (i >= data.length)
      return null;
    
    var result = data[i];
    i++;
    return result;
  }

  int available() { throw new Exception('Not implemented'); }
  int readList(List<int> buffer, int offset, int count) {}
  int writeList(List<int> buffer, int offset, int count) {}
  void set onConnect(void callback()) {}
  void set onData(void callback()) {}
  void set onWrite(void callback()) {}
  void set onClosed(void callback()) {}
  void set onError(void callback(e)) => null;
  InputStream get inputStream => null;
  OutputStream get outputStream => null;
  int get port => null;
  int get remotePort => null;
  String get remoteHost => null;
  void close([bool halfClose = false]) {}
}

