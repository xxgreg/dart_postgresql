part of postgresql.protocol;

// http://www.postgresql.org/docs/9.2/static/protocol-message-formats.html

//TODO Swap the connection class over to using these.
// currently just used for testing.

//Map frontendMessages = {                      
//};
//
//Map backedMessages = {                      
//};


abstract class ProtocolMessage {
  int get messageCode;
  List<int> encode();
  
  //TODO
//  static ProtocolMessage decodeFrontend(List<int> buffer, int offset)
//    => throw new UnimplementedError();
//
  //TODO
//  static ProtocolMessage decodeBackend(List<int> buffer, int offset)
//    => throw new UnimplementedError();
  
  // Note msgBodyLength excludes the 5 byte header. Is 0 for some message types.
  static ProtocolMessage decode(int msgType, int msgBodyLength, ByteReader byteReader) {
    assert(msgBodyLength <= byteReader.bytesAvailable);
    var decoder = _messageDecoders[msgType];
    if (decoder == null) throw new Exception('Unknown message type: $msgType'); //TODO exception type, and atoi on messageType.
    var msg = decoder(msgType, msgBodyLength, byteReader);
    //TODO check bytesRead == msgBodyLength, or throw lost message sync exception.
    return msg;
  }
}

const int _C = 67;
const int _D = 68;
//const int _E = 69;
//const int _I = 73;
const int _K = 75;
const int _N = 78;
const int _Q = 81;
const int _R = 82;
//const int _S = 83;
//const int _T = 84;
const int _X = 88;
const int _Z = 90;

const Map<int,Function> _messageDecoders = const {
  _C : CommandComplete.decode,
  _D : DataRow.decode,
  _E : ErrorResponse.decode,
  _I : EmptyQueryResponse.decode,
  _K : BackendKeyData.decode,
  _Q : Query.decode,
  _N : NoticeResponse.decode,  
  _R : AuthenticationRequest.decode,
  _S : ParameterStatus.decode,
  _T : RowDescription.decode,
  _X : Terminate.decode,
  _Z : ReadyForQuery.decode,
};

class Startup implements ProtocolMessage {
  
  Startup(this.user, this.database, [this.parameters = const {}]) {
    if (user == null || database == null) throw new ArgumentError();
  }
  
  // Startup and ssl request are the only messages without a messageCode.
  final int messageCode = 0; 
  final int protocolVersion = 196608;
  final String user;
  final String database;
  final Map<String,String> parameters;
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
      ..addInt32(protocolVersion)
      ..addUtf8('user')
      ..addUtf8(user)
      ..addUtf8('database')
      ..addUtf8(database)
      ..addUtf8('client_encoding')
      ..addUtf8('UTF8');    
    parameters.forEach((k, v) {
      mb.addUtf8(k);
      mb.addUtf8(v);
    });
    mb.addByte(0);
    
    return mb.build();
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'protocolVersion': protocolVersion,
    'user': user,
    'database': database
  });
}

class SslRequest implements ProtocolMessage {
  // Startup and ssl request are the only messages without a messageCode.
  final int messageCode = 0;
  
  List<int> encode() => <int> [0, 0, 0, 8, 4, 210, 22, 47];
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
  });
}

class Terminate implements ProtocolMessage {
  
  final int messageCode = _X;
  
  List<int> encode() => new MessageBuilder(messageCode).build();
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _X);
    if (bodyLength != 0) throw new Exception(); //FIXME
    return new Terminate();
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
  });
}

//const int authTypeOk = 0;
//const int authTypeMd5 = 5;

//const int authOk = 0;
//const int authKerebosV5 = 2;
//const int authScm = 6;
//const int authGss = 7;
//const int authClearText = 3;


class AuthenticationRequest implements ProtocolMessage {
  
  AuthenticationRequest.ok() : authType = 0, salt = null;
  
  AuthenticationRequest.md5(this.salt)
      : authType = 5 {
    if (salt == null || salt.length != 4) throw new Exception(); //FIXME
  }
  
  final int messageCode = _R;
  final int authType;
  final List<int> salt;
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addInt32(authType);
    if (authType == 5) mb.addBytes(salt);
    return mb.build();
  }
  
  static AuthenticationRequest decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _R);
    int authType = r.readInt32();
    if (authType == 0) {
      return new AuthenticationRequest.ok();
    
    } else if (authType == 5) {
      var salt = r.readBytes(4);
      return new AuthenticationRequest.md5(salt);
    } else {
      throw new Exception('Invalid authType: $authType');
    }
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'authType': {0: "ok", 5: "md5"}[authType],
    'salt': salt
  });
}

class BackendKeyData implements ProtocolMessage {
  
  BackendKeyData(this.backendPid, this.secretKey) {
    if (backendPid == null || secretKey == null) throw new ArgumentError();
  }
  
  final int messageCode = _K;
  final int backendPid;
  final int secretKey;
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
      ..addInt32(backendPid)
      ..addInt32(secretKey);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _K);
    if (bodyLength != 8) throw new Exception(); //FIXME
    int pid = r.readInt32();
    int key = r.readInt32();
    return new BackendKeyData(pid, key);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'backendPid': backendPid,
    'secretKey': secretKey
  });
}

class ParameterStatus implements ProtocolMessage {
  
  ParameterStatus(this.name, this.value);
  
  final int messageCode = _S;
  final String name;
  final String value;
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
      ..addUtf8(name)
      ..addUtf8(value);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _S);
    int maxlen = bodyLength;
    var name = r.readString(maxlen);
    var value = r.readString(maxlen);
    return new ParameterStatus(name, value);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'name': name,
    'value': value});
}


class Query implements ProtocolMessage {
  
  Query(this.query) {
    if (query == null) throw new ArgumentError();
  }
  
  final int messageCode = _Q;
  final String query;
  
  List<int> encode()
    => (new MessageBuilder(messageCode)..addUtf8(query)).build(); //FIXME why do I need extra parens here. Analyzer bug?
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _Q);
    var query = r.readString(bodyLength);
    return new Query(query);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'query': query});
}


class Field {
  
  Field({
    this.name,
    this.fieldId: 0,
    this.tableColNo: 0,
    this.fieldType,
    this.dataSize: -1,
    this.typeModifier: 0,
    this.formatCode: 0}) {
    if (name == null || fieldType == null) throw new ArgumentError();
  }
  
  final String name;
  final int fieldId;
  final int tableColNo;
  final int fieldType;
  final int dataSize;
  final int typeModifier;
  final int formatCode;
  
  bool get isBinary => formatCode == 1;
  
  String toString() => JSON.encode({
    'name': name,
    'fieldId': fieldId,
    'tableColNo': tableColNo,
    'fieldType': fieldType,
    'dataSize': dataSize,
    'typeModifier': typeModifier,
    'formatCode': formatCode
  });
}

class RowDescription implements ProtocolMessage {
  
  RowDescription(this._fields) {
    if (_fields == null) throw new ArgumentError();
  }
  
  final int messageCode = _T;
  
  final List<Field> _fields;
  List<Field> get fields => new UnmodifiableListView(_fields);
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode) 
      ..addInt16(fields.length);

    for (var f in fields) {
      mb..addUtf8(f.name)
        ..addInt32(f.fieldId)
        ..addInt16(f.tableColNo)
        ..addInt32(f.fieldType)
        ..addInt16(f.dataSize)
        ..addInt32(f.typeModifier)
        ..addInt16(f.formatCode);
    }
    
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _T);
    int maxlen = bodyLength;
    int count = r.readInt16();
    var fields = new List(count);
    for (int i = 0; i < count; i++) {
      var field = new Field(
          name: r.readString(maxlen),
          fieldId: r.readInt32(),
          tableColNo: r.readInt16(),
          fieldType: r.readInt32(),
          dataSize: r.readInt16(),
          typeModifier: r.readInt32(),
          formatCode: r.readInt16());
      fields[i] = field;
    }
    return new RowDescription(fields);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'fields': fields});
}


class DataRow implements ProtocolMessage {
  
  DataRow.fromBytes(this._values) {
    if (_values == null) throw new ArgumentError();
  }

  DataRow.fromStrings(List<String> strings)
    : _values = strings.map(UTF8.encode).toList(growable: false);
  
  final int messageCode = _D;
  
  final List<List<int>> _values;
  List<List<int>> get values => _values;
  
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
      ..addInt16(_values.length);
    
    for (var bytes in _values) {
      mb..addInt32(bytes.length)
        ..addBytes(bytes);
    }
    
    return mb.build();
  }
  
  //FIXME this currently copies data. Make a zero-copy version.
  // ... caller will need to use zero copy version carefully.
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _D);
    int count = r.readInt16();
    var values = new List(count);
    for (int i = 0; i < count; i++) {
      int len = r.readInt32();
      var bytes = r.readBytes(len);
      values[i] = bytes;
    }
    return new DataRow.fromBytes(values);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'values': _values.map(UTF8.decode) //TODO not all DataRows are text, some are binary.
  });
}


// TODO expose rows and oid getter
class CommandComplete implements ProtocolMessage {
  
  CommandComplete(this.tag);
  
  CommandComplete.insert(int oid, int rows) : this('INSERT $oid $rows');
  CommandComplete.delete(int rows) : this('DELETE $rows');
  CommandComplete.update(int rows) : this('UPDATE $rows');
  CommandComplete.select(int rows) : this('SELECT $rows');
  CommandComplete.move(int rows) : this('MOVE $rows');
  CommandComplete.fetch(int rows) : this('FETCH $rows');
  CommandComplete.copy(int rows) : this('COPY $rows');
  
  final int messageCode = _C;
  final String tag;
  
  List<int> encode() => (new MessageBuilder(messageCode)..addUtf8(tag)).build(); //FIXME why extra parens needed?
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _C);
    var tag = r.readString(bodyLength);
    return new CommandComplete(tag);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'tag': tag
  });
}


//FIXME use an enum when implemented
class TransactionStatus {
  const TransactionStatus(this._name);
  final String _name;
  static const TransactionStatus none = const TransactionStatus('TransactionStatus.none'); // idle
  static const TransactionStatus transaction = const TransactionStatus('TransactionStatus.transaction'); // in transaction
  static const TransactionStatus failed = const TransactionStatus('TransactionStatus.failed'); // failed transaction
}

class ReadyForQuery implements ProtocolMessage {
  
  ReadyForQuery.fromStatus(this.transactionStatus);
  
  ReadyForQuery(int statusCode)
      : transactionStatus = _txStatusR[statusCode] {
    if (transactionStatus == null) throw new Exception(); //FIXME
  }
  
  final int messageCode = _Z;
  final TransactionStatus transactionStatus;
  
  static const Map _txStatus = const {
    TransactionStatus.none: _I,
    TransactionStatus.transaction: _T,
    TransactionStatus.failed: _E
  };

  static const Map _txStatusR = const {
    _I: TransactionStatus.none,
    _T: TransactionStatus.transaction,
    _E: TransactionStatus.failed,
  };
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
      ..addByte(_txStatus[transactionStatus]);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _Z);
    if (bodyLength != 1) throw new Exception(); //FIXME
    int statusCode = r.readByte();
    return new ReadyForQuery(statusCode);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'transactionStatus': _txStatus[transactionStatus]
  });
}

abstract class BaseResponse implements ProtocolMessage {
  
  BaseResponse(Map<String,String> fields)
      : fields = new UnmodifiableMapView<String,String>(fields) {
    if (fields == null) throw new ArgumentError();
    assert(fields.keys.every((k) => k.length == 1));
  }
  
  String get severity => fields['S'];
  String get code => fields['C'];
  String get message => fields['M'];
  String get detail => fields['D'];
  String get hint => fields['H'];
  String get position => fields['P'];
  String get internalPosition => fields['p'];
  String get internalQuery => fields['q'];
  String get where => fields['W'];
  String get schema => fields['s'];
  String get table => fields['t'];
  String get column => fields['c'];
  String get dataType => fields['d'];
  String get constraint => fields['n'];
  String get file => fields['F'];
  String get line => fields['L'];
  String get routine => fields['R'];
  
  final Map<String, String> fields;
  
  List<int> encode() {
    final mb = new MessageBuilder(messageCode);
    fields.forEach((k, v) => mb..addUtf8(k)..addUtf8(v));
    mb.addByte(0); // Terminator
    return mb.build();
  }
  
  static BaseResponse decode(int msgType, int bodyLength, ByteReader r) {
    int maxlen = bodyLength;
    
    final fields = <String,String>{};
    String key, value;
    while ((key = r.readString(maxlen)) != '') {
      value = r.readString(maxlen);
      fields[key] = value;
    }
    
    return msgType == _E
        ? new ErrorResponse(fields)
        : new NoticeResponse(fields);
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode),
    'fields': fields
  });
}

class ErrorResponse extends BaseResponse implements ProtocolMessage {
  ErrorResponse(Map<String,String> fields) : super(fields);
  final int messageCode = _E;
  
  static ErrorResponse decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _E);
    return BaseResponse.decode(msgType, bodyLength, r);
  }
}

class NoticeResponse extends BaseResponse implements ProtocolMessage {
  NoticeResponse(Map<String,String> fields) : super(fields);
  final int messageCode = _N;
  
  static NoticeResponse decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _N);
    return BaseResponse.decode(msgType, bodyLength, r);
  }
}

class EmptyQueryResponse implements ProtocolMessage {  
  
  final int messageCode = _I;
  
  List<int> encode() => new MessageBuilder(messageCode).build();
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _I);
    if (bodyLength != 0) throw new Exception(); //TODO
    return new EmptyQueryResponse();
  }
  
  String toString() => JSON.encode({
    'msg': runtimeType.toString(),
    'code': new String.fromCharCode(messageCode)
  });
}


