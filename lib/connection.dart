part of postgresql;

class _Connection implements Connection {
  
  _Connection(this._socket, this._databaseName, this._userName, this._passwordHash);
  
  int __state = _NOT_CONNECTED;  
  int get _state => __state;
  set _state(int s) {
    var was = __state;
    __state = s;
    //print('Connection state change: ${_stateToString(was)} => ${_stateToString(s)}.');
  }
  
  final String _databaseName;
  final String _userName;
  final String _passwordHash;
  final Socket _socket;
  final _Buffer _buffer = new _Buffer();
  bool _hasConnected = false;
  final Completer _connected = new Completer();
  final Queue<_Query> _sendQueryQueue = new Queue<_Query>();
  _Query _query;
  int _msgType;
  int _msgLength;

  Stream get unhandled => _unhandled.stream;
  final StreamController _unhandled = new StreamController();
  
  static final _uriRe = new RegExp(r'^postgres://([a-zA-Z0-9\-\_]+)\:([a-zA-Z0-9\-\_]+)\@([a-zA-Z0-9\-\_\.]+)\:([0-9]+)\/([a-zA-Z0-9\-\_]+)');

  static Future<_Connection> _connect(String uri) {

    // FIXME allow optional hostname and port.
    // Perhaps default database name to be username.
    // FIXME testing.

    String userName, database, passwordHash, host;
    int port = 5432;

    var match = _uriRe.firstMatch(uri);
    if (match != null && match.groupCount == 5) {    
      userName = match[1];
      passwordHash = _md5s(match[2] + match[1]);
      host = match[3];
      port = int.parse(match[4], onError: (_) => port);
      database = match[5];
    } else {
      //TODO fail - return completeError. Or throw, and use future of.
      throw new UnimplementedError();
    }

    return Socket.connect(host, port).then((socket) {
      var conn = new _Connection(socket, database, userName, passwordHash);
      socket.listen(conn._readData, onError: conn._handleSocketError, onDone: conn._handleSocketClosed);
      conn._state = _SOCKET_CONNECTED;
      conn._sendStartupMessage();
      return conn._connected.future;
    });
  }

  static String _md5s(String s) {
    var hash = new MD5();
    hash.add(s.codeUnits.toList());
    return CryptoUtils.bytesToHex(hash.close());
  }

  
  void _sendStartupMessage() {
    if (_state != _SOCKET_CONNECTED)
      throw new StateError('Invalid state during startup.');
    
    var msg = new _MessageBuffer();
    msg.addInt32(0); // Length padding.
    msg.addInt32(_PROTOCOL_VERSION);    
    msg.addString('user');
    msg.addString(_userName);
    msg.addString('database');
    msg.addString(_databaseName);
    //TODO write params list.
    msg.addByte(0);
    msg.setLength(startup: true);
    
    _socket.writeBytes(msg.buffer);
    
    _state = _AUTHENTICATING;
  }
  
  void _readAuthenticationRequest(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    if (_state != _AUTHENTICATING)
      throw new StateError('Invalid connection state while authenticating.');
    
    int authType = _buffer.readInt32();
    
    if (authType == _AUTH_TYPE_OK) {
      _state = _AUTHENTICATED;
      return;
    }
    
    // Only MD5 authentication is supported.
    if (authType != _AUTH_TYPE_MD5) {
      throw new _PgClientException('Unsupported or unknown authentication type: ${_authTypeAsString(authType)}, only MD5 authentication is supported.');
    }
    
    var bytes = _buffer.readBytes(4);
    var salt = new String.fromCharCodes(bytes);
    var md5 = 'md5' + _md5s('${_passwordHash}$salt');
    
    // Build message.
    var msg = new _MessageBuffer();
    msg.addByte(_MSG_PASSWORD);
    msg.addInt32(0);
    msg.addString(md5);
    msg.setLength();
    
    _socket.writeBytes(msg.buffer);
  }
  
  void _readReadyForQuery(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    int c = _buffer.readByte();
    
    // print('Ready for query. Transaction state: ${_itoa(c)}');

    // TODO store transaction state somewhere. Perhaps this needs to be able
    // to be read via the api. Perhaps Connection.transactionState, or just Connection.state?
    // which is one of: {BUSY, IDLE, IN_TRANSACTION, ERROR};

    if (c == _I || c == _T || c == _E) {
      
      var was = _state;
      
      _state = _IDLE;
      
      if (_query != null) {
        _query.close();
        _query = null;      
      }
      
      if (was == _AUTHENTICATED) {
        _hasConnected = true;
        _connected.complete(this);
      }
      
      //FIXME Dear deep thought, what is the idiomatic way to do this?
      new Future.immediate(42).then((_) => _processSendQueryQueue());
      
    } else {
      _destroy();
      throw new _PgClientException('Unknown ReadyForQuery transaction status: ${_itoa(c)}.');
    }
  }
  
  void _handleSocketError(error) {

    if (_state == _CLOSED) {
      //FIXME logging
      print('Error after socket closed: $error');
      _destroy();
      return;
    }

    _destroy();

    var ex = new _PgClientException('Socket error.', error);
    
    if (!_hasConnected) {
      _connected.completeError(ex);
    } else if (_query != null) {
      _query.addError(ex);
    } else {
      _unhandled.add(ex);
    }
  }
  
  void _handleSocketClosed() {
    if (_state != _CLOSED) {
      _handleSocketError(new _PgClientException('Socket closed.'));
    }
  }
  
  void _readData(List<int> data) {
    
    try {
      
      if (_state == _CLOSED)
        return;
  
      _buffer.append(data);
  
      // Handle resuming after storing message type and length.
      if (_msgType != null) {
        if (_msgLength > _buffer.bytesAvailable)
            return; // Wait for entire message to be in buffer.
        
        _readMessage(_msgType, _msgLength);
        
        _msgType = null;
        _msgLength = null;
      }
      
      // Main message loop.
      while (_state != _CLOSED) {
      
        if (_buffer.bytesAvailable < 5)
          return; // Wait for more data.

        // Message length is the message length excluding the message type code, but
        // including the 4 bytes for the length fields. Only the length of the body
        // is passed to each of the message handlers.
        int msgType = _buffer.readByte();
        int length = _buffer.readInt32() - 4;
        
        if (!_checkMessageLength(msgType, length + 4)) {
          throw new _PgClientException('Lost message sync.');
        }
        
        if (length > _buffer.bytesAvailable) {
          // Wait for entire message to be in buffer.
          // Store type, and length for when more data becomes available.
          _msgType =  msgType;
          _msgLength = length;
          return;
        }
        
        _readMessage(msgType, length);
      }
      
    } on Exception catch (e) {
      _destroy();
      throw new _PgClientException('Error reading data.', e); //TODO test that this will be caught by unhandled stream.
    }
  }

  bool _checkMessageLength(int msgType, int msgLength) {
    
    if (_state == _AUTHENTICATING) {
      if (msgLength < 8) return false;
      if (msgType == _MSG_AUTH_REQUEST && msgLength > 2000) return false;
      if (msgType == _MSG_ERROR_RESPONSE && msgLength > 30000) return false;
    } else {
      if (msgLength < 4) return false;
      
      // These are the only messages from the server which may exceed 30,000
      // bytes.
      if (msgLength > 30000 && (msgType != _MSG_NOTICE_RESPONSE
          && msgType != _MSG_ERROR_RESPONSE
          && msgType != _MSG_COPY_DATA
          && msgType != _MSG_ROW_DESCRIPTION
          && msgType != _MSG_DATA_ROW
          && msgType != _MSG_FUNCTION_CALL_RESPONSE
          && msgType != _MSG_NOTIFICATION_RESPONSE)) {
        return false;
      }
    }
    return true;
  }
  
  void _readMessage(int msgType, int length) {
    
    int pos = _buffer.bytesRead;
    
    // print('Handle message: ${_itoa(msgType)} ${_messageName(msgType)}.');
    
    switch (msgType) {
      
      case _MSG_AUTH_REQUEST:     _readAuthenticationRequest(msgType, length); break;
      case _MSG_READY_FOR_QUERY:  _readReadyForQuery(msgType, length); break;
      
      case _MSG_ERROR_RESPONSE:
      case _MSG_NOTICE_RESPONSE:
                                  _readErrorOrNoticeResponse(msgType, length); break;
        
      case _MSG_BACKEND_KEY_DATA: _readBackendKeyData(msgType, length); break;
      case _MSG_PARAMETER_STATUS: _readParameterStatus(msgType, length); break;
      
      case _MSG_ROW_DESCRIPTION:  _readRowDescription(msgType, length); break;
      case _MSG_DATA_ROW:         _readDataRow(msgType, length); break;
      case _MSG_EMPTY_QUERY_REPONSE: assert(length == 0); break;
      case _MSG_COMMAND_COMPLETE: _readCommandComplete(msgType, length); break;
        
      default:
        throw new _PgClientException("Unknown, or unimplemented message: ${decodeUtf8([msgType])}.");
    }
    
    if (pos + length != _buffer.bytesRead)
      throw new _PgClientException('Lost message sync.');
  }

  void _readErrorOrNoticeResponse(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    var map = new Map<String, String>();
    int errorCode = _buffer.readByte();
    while (errorCode != 0) {
      var msg = _buffer.readString(length); //TODO check length remaining.
      map[new String.fromCharCode(errorCode)] = msg;
      errorCode = _buffer.readByte();
    }
    
    var info = new _PgServerInformation(
                         msgType == _MSG_ERROR_RESPONSE,
                         map);
    
    if (msgType == _MSG_ERROR_RESPONSE) {
      var ex = new _PgServerException(info);
      if (!_hasConnected) {
          _state = _CLOSED;
          _socket.destroy();
          _connected.completeError(ex);                     
      } else if (_query != null) {
        _query.addError(ex);
      } else {
        _unhandled.add(ex);
      }
    } else {
      _unhandled.add(info);
    }
  }
  
  void _readBackendKeyData(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    _buffer.readBytes(length);
  }
  
  void _readParameterStatus(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    _buffer.readBytes(length);
  }
  
  Stream _errorStream(err) {
    return new Stream.fromFuture(
        new Future.immediateError(err));
  }
  
  Stream query(String sql) {
    try {
      var query = _enqueueQuery(sql);
      return query.stream;
    } on Exception catch (ex) { //TODO Should this be on PgException? 
      return new Stream.fromFuture(new Future.immediateError(ex));  
    }
  }
  
  Future<int> execute(String sql) {
    try {
      var query = _enqueueQuery(sql);
      return query.stream.isEmpty.then((_) => _query._rowsAffected);
    } on Exception catch (ex) { //TODO Should this be on PgException?
      return new Future.immediateError(ex);
    }
  }
  
  _Query _enqueueQuery(String sql) {

    if (sql == null || sql == '')
      throw new _PgClientException('SQL query is null or empty.');
    
    if (_state == _CLOSED)
      throw new _PgClientException('Connection is closed, cannot execute query.');
    
    var query = new _Query(sql);
    _sendQueryQueue.addLast(query);
    
    //FIXME What is the idiomatic way to do this?
    new Future.immediate(42).then((_) => _processSendQueryQueue());
    
    return query;
  }
  
  void _processSendQueryQueue() {
    
    if (_sendQueryQueue.isEmpty)
      return;
    
    if (_query != null)
      return;
    
    if (_state == _CLOSED)
      return;

    assert(_state == _IDLE);
    
    _query = _sendQueryQueue.removeFirst();
    
    var msg = new _MessageBuffer();
    msg.addByte(_MSG_QUERY);
    msg.addInt32(0); // Length padding.
    msg.addString(_query.sql);
    msg.setLength();
    
    _socket.writeBytes(msg.buffer);
    
    _state = _BUSY;
    _query._state = _BUSY;
  }
  
  void _readRowDescription(int msgType, int length) {
    
    assert(_buffer.bytesAvailable >= length);
    
    _state = _STREAMING;
    
    int count = _buffer.readInt16();
    var list = new List<_Column>(count);
    
    for (int i = 0; i < count; i++) {      
      var name = _buffer.readString(length); //FIXME better maxSize.
      int fieldId = _buffer.readInt32();
      int tableColNo = _buffer.readInt16();
      int fieldType = _buffer.readInt32();
      int dataSize = _buffer.readInt16();
      int typeModifier = _buffer.readInt32();
      int formatCode = _buffer.readInt16();
      
      list[i] = new _Column(i, name, fieldId, tableColNo, fieldType, dataSize, typeModifier, formatCode);
    }
    
    _query._columnCount = count;
    _query._columns = list;
    _query._commandIndex++;
    
    _query.addRowDescription();
  }
  
  void _readDataRow(int msgType, int length) {
    
    assert(_buffer.bytesAvailable >= length);
    
    int columns = _buffer.readInt16();
    for (var i = 0; i < columns; i++) {
      int size = _buffer.readInt32();
      _readColumnData(i, size);
    }
  }
  
  void _readColumnData(int index, int colSize) {
    
    assert(_buffer.bytesAvailable >= colSize);
    
    if (index == 0)
      _query._rowData = new List<dynamic>(_query._columns.length);
      
    if (colSize == -1) {
      _query._rowData[index] = null;
    } else {
      //TODO Optimisation. Don't always need to copy this data. Can read directly
      // out of the buffer.
      var col = _query._columns[index];
      var data = _buffer.readBytes(colSize); 
      var value = (col.isBinary) ? _decodeBinaryValue(col, data)
                                  : _decodeStringValue(col, data);
      _query._rowData[index] = value;
    }
    
    // If last column, then return the row.
    if (index == _query._columnCount - 1)
      _query.addRow();
  }
  
  dynamic _decodeStringValue(_Column col, List<int> data) {
    
    switch (col.fieldType) {
      case t_bool:
        return data[0] == 116;
      
      case t_int2:
      case t_int4:
      case t_int8:
        return int.parse(decodeUtf8(data));
        
      case t_float4:
      case t_float8:
        return double.parse(decodeUtf8(data));
      
      case t_timestamp:
      case t_date:
        return DateTime.parse(decodeUtf8(data));      
        
      // Not implemented
      case t_timestamptz:
      case t_timetz:        
      case t_time: 
      case t_interval:
      case t_numeric:
        
      default:
        return decodeUtf8(data);
    }    
  }
  
  dynamic _decodeBinaryValue(_Column col, List<int> data) {
    // Not implemented
    return data;
  }
  
  void _readCommandComplete(int msgType, int length) {
    
    assert(_buffer.bytesAvailable >= length);
    
    var commandString = _buffer.readString(length);
    int rowsAffected = 
        int.parse(commandString.split(' ').last, onError: (_) => null);
    
    _query._commandIndex++;
    _query._rowsAffected = rowsAffected;
  }
  
  void close() {
    _state = _CLOSED;
    
    try {
      var msg = new _MessageBuffer();
      msg.addByte(_MSG_TERMINATE);
      msg.addInt32(0);
      msg.setLength();
      
      _socket.writeBytes(msg.buffer);
    } catch (e) {
      _unhandled.add(new _PgClientException('Postgresql connection closed without sending terminate message.', e));
    }

    _destroy();
  }
  
  void _destroy() {
    _state = _CLOSED;
    _socket.destroy();
  }
}
