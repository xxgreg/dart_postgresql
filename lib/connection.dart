part of postgresql;

class _Notice implements Exception {
  _Notice(this._map);
  Map<int, String> _map;
  String toString() => _map.containsKey(_M) ? _map[_M] : _map.values.reduce('', (val, item) => '$val, $item'); 
}

class _Connection implements Connection {
  
  _Connection(this._socket, this._settings);
  
  int __state = _NOT_CONNECTED;  
  int get _state => __state;
  set _state(int s) {
    var was = __state;
    __state = s;
    //print('Connection state change: ${_stateToString(was)} => ${_stateToString(s)}.');
  }
  
  final Socket _socket;
  final _Buffer _buffer = new _Buffer();
  final _Settings _settings;
  bool _hasConnected = false;
  final Completer _connected = new Completer();
  final Queue<_Query> _sendQueryQueue = new Queue<_Query>();
  _Query _query;
  int _msgType;
  int _msgLength;

  static Future<_Connection> _connect(_Settings settings) {

    return Socket.connect(settings._host, settings._port).then((socket) {
      var conn = new _Connection(socket, settings);
      socket.listen(conn._readData, onError: conn._handleSocketError, onDone: conn._handleSocketClosed);
      conn._state = _SOCKET_CONNECTED;
      conn._sendStartupMessage();
      return conn._connected.future;
    });
  }
  
  
  void _sendStartupMessage() {
    if (_state != _SOCKET_CONNECTED)
      throw new Error();
    
    var msg = new _MessageBuffer();
    msg.addInt32(0); // Length padding.
    msg.addInt32(_PROTOCOL_VERSION);    
    msg.addString('user');
    msg.addString(_settings._username);
    msg.addString('database');
    msg.addString(_settings._database);
    //TODO write params list.
    msg.addByte(0);
    msg.setLength(startup: true);
    
    _socket.add(msg.buffer);
    
    _state = _AUTHENTICATING;
  }
  
  void _readAuthenticationRequest(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    if (_state != _AUTHENTICATING)
      throw new Exception('Invalid state.');
    
    int authType = _buffer.readInt32();
    
    if (authType == _AUTH_TYPE_OK) {
      _state = _AUTHENTICATED;
      return;
    }
    
    // Only MD5 authentication is supported.
    if (authType != _AUTH_TYPE_MD5) {
      throw new Exception('Unsupported or unknown authentication type: ${_authTypeAsString(authType)}, only MD5 authentication is supported.');
    }
    
    var bytes = _buffer.readBytes(4);
    var salt = new String.fromCharCodes(bytes);
    var md5 = 'md5'.concat(_md5s(_settings._passwordHash.concat(salt)));
    
    // Build message.
    var msg = new _MessageBuffer();
    msg.addByte(_MSG_PASSWORD);
    msg.addInt32(0);
    msg.addString(md5);
    msg.setLength();
    
    _socket.add(msg.buffer);
  }
  
  void _readReadyForQuery(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    int c = _buffer.readByte();
    
    if (c == _I) {
      
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
      
    } else if (c == _T) {
      throw new Exception('Transaction handling not implemented.');
    } else if (c == _E) {
      throw new Exception('Transaction handling not implemented.');
    } else {
      throw new Exception('Unknown ReadyForQuery transaction status: ${_itoa(c)}');
    }
  }
  
  void _handleSocketError(error) {    
    _socket.close();

    if (_state == _CLOSED)
      return;

    _state = _CLOSED;

    //FIXME wrap exception.
    if (!_hasConnected) {
      _connected.completeError(error);
    } else if (_query != null) {
      _query.streamError(error);
    } else {
      //throw error;
      print('Unhandled error: $error');
    }
  }
  
  void _handleSocketClosed() {
    _handleSocketError(new Exception("Socket closed."));
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
          throw new Exception("Lost sync.");
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
      print('Fatal error: $e');
      close();
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
      case _MSG_COMMAND_COMPLETE: _readCommandComplete(msgType, length); break;
        
      default:
        throw new Exception("Unknown, or unimplemented message: ${decodeUtf8([msgType])}.");
    }
    
    if (pos + length != _buffer.bytesRead)
      throw new Exception("Lost message sync.");
  }

  void _readErrorOrNoticeResponse(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);
    
    var map = new Map<int, String>();
    int errorCode = _buffer.readByte();
    while (errorCode != 0) {
      var msg = _buffer.readString(length); //TODO check length remaining.
      map[errorCode] = msg;
      errorCode = _buffer.readByte();      
    }
    
    var notice = new _Notice(map);
    
    if (msgType == _MSG_ERROR_RESPONSE) {
      if (!_hasConnected) {
          _state = _CLOSED;
          _socket.close();
          _connected.completeError(notice);                     
      } else if (_query != null) {
        _query.streamError(notice);
      } else {
        //TODO
        throw new Exception(notice.toString());
      }
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
    } on Exception catch (ex) {
      return new Stream.fromFuture(new Future.immediateError(ex));  
    }
  }
  
  Future<ExecuteResult> execute(String sql) {
    try {
      var query = _enqueueQuery(sql);
      return query.stream.isEmpty.then((_) => _query._executeResult);
    } on Exception catch (ex) {
      return new Future.immediateError(ex);
    }
  }
  
  _Query _enqueueQuery(String sql) {

    if (sql == null || sql == '')
      throw new Exception('SQL query is null or empty.');
    
    if (_state == _CLOSED)
      throw new Exception('Connection is closed, cannot execute query.');
    
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
    
    _socket.add(msg.buffer);
    
    _state = _BUSY;
    _query._state = _BUSY;
  }
  
  void _readRowDescription(int msgType, int length) {
    
    assert(_buffer.bytesAvailable >= length);
    
    _state = _STREAMING;
    
    int count = _buffer.readInt16();
    var list = new List<_Column>.fixedLength(count);
    
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
      _query._rowData = new List<dynamic>.fixedLength(_query._columns.length);
      
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
      _query.streamRow();
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
    
    var list = _buffer.readString(length).split(' ');
    
    int lastInsertId, rowsAffected;
    
    if (list[0] == 'INSERT') {
      if (list.length != 3)
        throw new Exception('Badly formed command complete message.');
      
      lastInsertId = int.parse(list[1]);
      rowsAffected = int.parse(list[2]);
      
    } else if (list[0] == 'SELECT'
          || list[0] == 'DELETE'
          || list[0] == 'UPDATE'
          || list[0] == 'MOVE'
          || list[0] == 'FETCH'
          || list[0] == 'COPY') {        
      
      if (list.length < 2)
        throw new Exception('Badly formed command complete message.');
      
      lastInsertId = 0;
      rowsAffected = int.parse(list[1], onError: (_) => rowsAffected = 0);
      
    } else {
      lastInsertId = 0;
      rowsAffected = 0;
    }
    
    _query._commandIndex++;
    _query._executeResult = new _ExecuteResult(lastInsertId, rowsAffected);
  }
  
  void close() {
    _state = _CLOSED;
    
    var msg = new _MessageBuffer();
    msg.addByte(_MSG_TERMINATE);
    msg.addInt32(0);
    msg.setLength();
    
    _socket.add(msg.buffer);
    _socket.close();
  }
}
