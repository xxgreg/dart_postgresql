part of postgresql.protocol;


class Bind implements ProtocolMessage {
  
  final int messageCode = _B;
  
  Bind(this.portal, this.statement, this.parameterFormats, this.parameters, this.resultFormats);
  
  /// The name of the destination portal (an empty string selects the unnamed portal).
  final String portal; 

  /// The name of the source prepared statement (an empty string selects the unnamed prepared statement).
  final String statement; 

  /// The number of parameter format codes that follow (denoted C below). This can be zero to indicate that there are no parameters or that the parameters all use the default format (text); or one, in which case the specified format code is applied to all parameters; or it can equal the actual number of parameters.
  /// The parameter format codes. Each must presently be zero (text) or one (binary).
  final List<int> parameterFormats; 

  /// The number of parameter values that follow (possibly zero). This must match the number of parameters needed by the query. 
  /// The length of the parameter value, in bytes (this count does not include itself). Can be zero. As a special case, -1 indicates a NULL parameter value. No value bytes follow in the NULL case.
  /// The value of the parameter, in the format indicated by the associated format code. n is the above length.
  final List<List<int>> parameters; 

  /// The number of result-column format codes that follow (denoted R below). This can be zero to indicate that there are no result columns or that the result columns should all use the default format (text); or one, in which case the specified format code is applied to all result columns (if any); or it can equal the actual number of result columns of the query.
  /// The result-column format codes. Each must presently be zero (text) or one (binary).
  final List<int> resultFormats; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode)
        ..addString(portal)
        ..addString(statement);
        
    mb.addInt16(parameterFormats.length);
    parameterFormats.forEach((i) => mb.addInt16(i));
    
    mb.addInt16(parameters.length);
    for (var bytes in parameters) {
      if (bytes == null) {
        mb.addInt32(-1);
      } else {
        mb.addInt32(bytes.length);
        mb.addBytes(bytes);
      }
    }
    
    mb.addInt16(resultFormats.length);
    resultFormats.forEach((i) => mb.addInt16(i));
        
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _B);
    var portal = r.readString();
    var statement = r.readString();
    
    var parameterFormats = new List<int>(r.readInt16());
    for (int i = 0; i < parameterFormats.length; i++) {
      parameterFormats[i] = r.readInt16();
    }
    
    var values = new List<List<int>>(r.readInt16());
    for (int i = 0; i < values.length; i++) {
        int len = r.readInt32();
        values[i] = r.readBytes(len);
    }

    var resultFormats = new List<int>(r.readInt16());
    for (int i = 0; i < resultFormats.length; i++) {
      resultFormats[i] = r.readInt16();
    }

    return new Bind(portal, statement, parameterFormats, values, resultFormats);
  }
}



class BindComplete implements ProtocolMessage {
  
  final int messageCode = _2;
  
  BindComplete();
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);  
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _2);
    return new BindComplete();
  }
}



class CancelRequest implements ProtocolMessage {
  
  final int messageCode = 0;
  
  CancelRequest(this.requestCode, this.backedPid, this.secretKey);
  
  /// 80877102 The cancel request code. The value is chosen to contain 1234 in the most significant 16 bits, and 5678 in the least 16 significant bits. (To avoid confusion, this code must not be the same as any protocol version number.)
  final int requestCode; 

  /// The process ID of the target backend.
  final int backedPid; 

  /// The secret key for the target backend.
  final int secretKey; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addInt32(requestCode);
    mb.addInt32(backedPid);
    mb.addInt32(secretKey);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    var requestCode = r.readInt32();
    var backedPid = r.readInt32();
    var secretKey = r.readInt32();
    return new CancelRequest(requestCode, backedPid, secretKey);
  }
}



class Close implements ProtocolMessage {
  
  final int messageCode = _C;
  
  Close(this.type, this.name);
  
  /// 'S' to close a prepared statement; or 'P' to close a portal.
  final int type; 

  /// The name of the prepared statement or portal to close (an empty string selects the unnamed prepared statement or portal).
  final String name; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addByte(type);
    mb.addString(name);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _C);
    var type = r.readByte();
    var name = r.readString();
    return new Close(type, name);
  }
}



class CloseComplete implements ProtocolMessage {
  
  final int messageCode = _3;
  
  CloseComplete();
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);  
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _3);
    return new CloseComplete();
  }
}


class Describe implements ProtocolMessage {
  
  final int messageCode = _D;
  
  Describe(this.type, this.name);
  
  /// 'S' to describe a prepared statement; or 'P' to describe a portal.
  final int type; 

  /// The name of the prepared statement or portal to describe (an empty string selects the unnamed prepared statement or portal).
  final String name; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addByte(type);
    mb.addString(name);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _D);
    var type = r.readByte();
    var name = r.readString();
    return new Describe(type, name);
  }
}



class Execute implements ProtocolMessage {
  
  final int messageCode = _E;
  
  Execute(this.portal, this.maxRows);
  
  /// The name of the portal to execute (an empty string selects the unnamed portal).
  final String portal; 

  /// Maximum number of rows to return, if portal contains a query that returns rows (ignored otherwise). Zero denotes no limit.
  final int maxRows; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addString(portal);
    mb.addInt32(maxRows);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _E);
    var name = r.readString();
    var maxRows = r.readInt32();
    return new Execute(name, maxRows);
  }
}



class Flush implements ProtocolMessage {
  
  final int messageCode = _H;
  
  Flush();
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);  
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _H);
    return new Flush();
  }
}



class NoData implements ProtocolMessage {
  
  final int messageCode = _n;
  
  NoData();
 
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);   
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _n);
    return new NoData();
  }
}



class NotificationResponse implements ProtocolMessage {
  
  final int messageCode = _A;
  
  NotificationResponse(this.backendPid, this.channel, this.data);
  
  /// The process ID of the notifying backend process.
  final int backendPid; 

  /// The name of the channel that the notify has been raised on.
  final String channel; 

  /// The payload string passed from the notifying process.
  final String data; 
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addInt32(backendPid);
    mb.addString(channel);
    mb.addString(data);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _A);
    var backendPid = r.readInt32();
    var channel = r.readString();
    var data = r.readString();
    return new NotificationResponse(backendPid, channel, data);
  }
}



class ParameterDescription implements ProtocolMessage {
  
  final int messageCode = _t;
  
  ParameterDescription(this.oids);
  
  /// The number of parameters used by the statement (can be zero).
  /// Specifies the object ID of the parameter data type.
  final List<int> oids;
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    mb.addInt16(oids.length);
    oids.forEach((oid) => mb.addInt32(oid));
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _t);
    var oids = new List<int>(r.readInt16());
    for (int i = 0; i < oids.length; i++) {
      oids[i] = r.readInt32();
    }
    return new ParameterDescription(oids);
  }
}



class Parse implements ProtocolMessage {
  
  final int messageCode = _P;
  
  Parse(this.statement, this.query, this.oids);
  
  /// The name of the destination prepared statement (an empty string selects the unnamed prepared statement).
  final String statement; 

  /// The query string to be parsed.
  final String query; 

  /// The number of parameter data types specified (can be zero). Note that this is not an indication of the number of parameters that might appear in the query string, only the number that the frontend wants to prespecify types for.
  /// Specifies the object ID of the parameter data type. Placing a zero here is equivalent to leaving the type unspecified.
  final List<int> oids; 
  
  List<int> encode() {
    print('encode');
    var mb = new MessageBuilder(messageCode);
    mb.addString(statement);
    mb.addString(query);
    mb.addInt16(oids.length);
    oids.forEach((i) => mb.addInt32(i));
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _P);
    var statement = r.readString();
    var query = r.readString();
    var oids = new List<int>(r.readInt16());
    for (int i = 0; i < oids.length; i++) {
      oids[i] = r.readInt32();
    }
    return new Parse(statement, query, oids);
  }
}



class ParseComplete implements ProtocolMessage {
  
  final int messageCode = _1;
  
  ParseComplete();
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _1);
    return new ParseComplete();
  }
}



class PortalSuspended implements ProtocolMessage {
  
  final int messageCode = _s;
  
  PortalSuspended();
    
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);  
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _s);  
    return new PortalSuspended();
  }
}



class Sync implements ProtocolMessage {
  
  final int messageCode = _S;
  
  Sync();
  
  List<int> encode() {
    var mb = new MessageBuilder(messageCode);
    return mb.build();
  }
  
  static ProtocolMessage decode(int msgType, int bodyLength, ByteReader r) {
    assert(msgType == _S);  
    return new Sync();
  }
}




