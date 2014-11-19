part of postgresql;

class _Connection implements Connection {

  _Connection(this._socket, Settings settings, TypeConverter typeConverter)
    : _userName = settings.user,
      _passwordHash = _md5s(settings.password + settings.user),
      _databaseName = settings.database,
      _typeConverter =
        typeConverter == null ? new TypeConverter() : typeConverter;

  static int _sequence = 1;
  final int connectionId = _sequence++;

  ConnectionState get state => _state;
  ConnectionState _state = notConnected;

  TransactionState _transactionState = unknown;
  TransactionState get transactionState => _transactionState;

  final String _databaseName;
  final String _userName;
  final String _passwordHash;
  final TypeConverter _typeConverter;
  final Socket _socket;
  final Buffer _buffer = new Buffer();
  bool _hasConnected = false;
  final Completer _connected = new Completer();
  final Queue<_Query> _sendQueryQueue = new Queue<_Query>();
  _Query _query;
  int _msgType;
  int _msgLength;

  Stream get messages => _messages.stream;
  final StreamController _messages = new StreamController.broadcast();

  static Future<_Connection> _connect(String uri, Duration timeout, TypeConverter typeConverter) {
    return new Future.sync(() {
      var settings = new Settings.fromUri(uri);

      //FIXME Currently this timeout doesn't cancel the socket connection 
      // process.
      // There is a bug open about adding a real socket connect timeout
      // parameter to Socket.connect() if this happens then start using it.
      // http://code.google.com/p/dart/issues/detail?id=19120
      if (timeout == null) timeout = new Duration(seconds: 180);
      
      var onTimeout = 
          () => throw new TimeoutException(
              'Postgresql connection timed out. $timeout', timeout);
      
      var future = settings.requireSsl
        ? _connectSsl(settings, timeout, onTimeout)
        : Socket.connect(settings.host, settings.port)
            .timeout(timeout, onTimeout: onTimeout);

      return future.then((socket) {
        var conn = new _Connection(socket, settings, typeConverter);
        socket.listen(conn._readData, 
            onError: conn._handleSocketError,
            onDone: conn._handleSocketClosed);
        conn._state = socketConnected;
        conn._sendStartupMessage();
        return conn._connected.future;
      });
    });
  }

  static String _md5s(String s) {
    var hash = new MD5();
    hash.add(s.codeUnits.toList());
    return CryptoUtils.bytesToHex(hash.close());
  }

  //TODO yuck - this needs a rewrite.
  static Future<SecureSocket> _connectSsl(
      Settings settings, Duration timeout, onTimeout()) {

    var completer = new Completer<SecureSocket>();

    Socket.connect(settings.host, settings.port).then((socket) {

      socket.listen((data) {
        if (data == null || data[0] != _S) {
          socket.close();
          completer.completeError('This postgresql server is not configured to support SSL connections.');
        } else {
          // TODO validate certs
          new Future.sync(() => SecureSocket.secure(socket, onBadCertificate: (cert) => true))
            .then((s) => completer.complete(s))
            .catchError((e) => completer.completeError(e));
        }
      });

      // Write header, and SSL magic number.
      socket.add([0, 0, 0, 8, 4, 210, 22, 47]);

    })
    .timeout(timeout, onTimeout: onTimeout)
    .catchError((e) {
      completer.completeError(e);
    });

    return completer.future;
  }

  void _sendStartupMessage() {
    if (_state != socketConnected)
      throw new PostgresqlException('Invalid state during startup.');

    var msg = new MessageBuffer();
    msg.addInt32(0); // Length padding.
    msg.addInt32(_PROTOCOL_VERSION);
    msg.addUtf8String('user');
    msg.addUtf8String(_userName);
    msg.addUtf8String('database');
    msg.addUtf8String(_databaseName);
    //TODO write params list.
    msg.addByte(0);
    msg.setLength(startup: true);

    _socket.add(msg.buffer);

    _state = authenticating;
  }

  void _readAuthenticationRequest(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    if (_state != authenticating)
      throw new PostgresqlException('Invalid connection state while authenticating.');

    int authType = _buffer.readInt32();

    if (authType == _AUTH_TYPE_OK) {
      _state = authenticated;
      return;
    }

    // Only MD5 authentication is supported.
    if (authType != _AUTH_TYPE_MD5) {
      throw new PostgresqlException('Unsupported or unknown authentication type: ${_authTypeAsString(authType)}, only MD5 authentication is supported.');
    }

    var bytes = _buffer.readBytes(4);
    var salt = new String.fromCharCodes(bytes);
    var md5 = 'md5' + _md5s('${_passwordHash}$salt');

    // Build message.
    var msg = new MessageBuffer();
    msg.addByte(_MSG_PASSWORD);
    msg.addInt32(0);
    msg.addUtf8String(md5);
    msg.setLength();

    _socket.add(msg.buffer);
  }

  void _readReadyForQuery(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    int c = _buffer.readByte();

    if (c == _I || c == _T || c == _E) {

      if (c == _I)
        _transactionState = none;
      else if (c == _T)
        _transactionState = begun;
      else if (c == _E)
        _transactionState = error;

      var was = _state;

      _state = idle;

      if (_query != null) {
        _query.close();
        _query = null;
      }

      if (was == authenticated) {
        _hasConnected = true;
        _connected.complete(this);
      }

      new Future(() => _processSendQueryQueue());

    } else {
      _destroy();
      throw new PostgresqlException('Unknown ReadyForQuery transaction status: ${_itoa(c)}.');
    }
  }

  void _handleSocketError(error, {bool closed: false}) {

    if (_state == closed) {
      _messages.add(new _ClientMessage(
          severity: 'WARNING',
          message: 'Socket error after socket closed.',
          exception: error));
      _destroy();
      return;
    }

    _destroy();

    var ex = new _ClientMessage(
        severity: 'ERROR',
        message: closed
          ? 'Socket closed unexpectedly.'
          : 'Socket error.',
        exception: error);

    if (!_hasConnected) {
      _connected.completeError(ex);
    } else if (_query != null) {
      _query.addError(ex);
    } else {
      _messages.add(ex);
    }
  }

  void _handleSocketClosed() {
    if (_state != closed) {
      _handleSocketError(null, closed: true);
    }
  }

  void _readData(List<int> data) {

    try {

      if (_state == closed)
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
      while (_state != closed) {

        if (_buffer.bytesAvailable < 5)
          return; // Wait for more data.

        // Message length is the message length excluding the message type code, but
        // including the 4 bytes for the length fields. Only the length of the body
        // is passed to each of the message handlers.
        int msgType = _buffer.readByte();
        int length = _buffer.readInt32() - 4;

        if (!_checkMessageLength(msgType, length + 4)) {
          throw new PostgresqlException('Lost message sync.');
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

    } on Exception catch (e, st) {
      _destroy();
      throw new PostgresqlException('Error reading data.', e, st);
    }
  }

  bool _checkMessageLength(int msgType, int msgLength) {

    if (_state == authenticating) {
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
        throw new PostgresqlException("Unknown, or unimplemented message: ${UTF8.decode([msgType])}.");
    }

    if (pos + length != _buffer.bytesRead)
      throw new PostgresqlException('Lost message sync.');
  }

  void _readErrorOrNoticeResponse(int msgType, int length) {
    assert(_buffer.bytesAvailable >= length);

    var map = new Map<String, String>();
    int errorCode = _buffer.readByte();
    while (errorCode != 0) {
      var msg = _buffer.readUtf8String(length); //TODO check length remaining.
      map[new String.fromCharCode(errorCode)] = msg;
      errorCode = _buffer.readByte();
    }

    var ex = new _ServerMessage(
                         msgType == _MSG_ERROR_RESPONSE,
                         map);

    if (msgType == _MSG_ERROR_RESPONSE) {
      if (!_hasConnected) {
          _state = closed;
          _socket.destroy();
          _connected.completeError(ex);
      } else if (_query != null) {
        _query.addError(ex);
      } else {
        _messages.add(ex);
      }
    } else {
      _messages.add(ex);
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
        new Future.error(err));
  }

  Stream query(String sql, [values]) {
    try {
      if (values != null)
        sql = substitute(sql, values, _typeConverter.encode);
      var query = _enqueueQuery(sql);
      return query.stream;
    } on Exception catch (ex, st) {
      return new Stream.fromFuture(new Future.error(ex, st));
    }
  }

  Future<int> execute(String sql, [values]) {
    try {
      if (values != null)
        sql = substitute(sql, values, _typeConverter.encode);
      var query = _enqueueQuery(sql);
      return query.stream.isEmpty.then((_) => query._rowsAffected);
    } on Exception catch (ex, st) {
      return new Future.error(ex, st);
    }
  }

  Future runInTransaction(Future operation(), [Isolation isolation = readCommitted]) {

    var begin = 'begin';
    if (isolation == repeatableRead)
      begin = 'begin; set transaction isolation level repeatable read;';
    else if (isolation == serializable)
      begin = 'begin; set transaction isolation level serializable;';

    return execute(begin)
      .then((_) => operation())
      .then((_) => execute('commit'))
      .catchError((e, st) {
        return execute('rollback')
          .then((_) => new Future.error(e, st));
      });
  }

  _Query _enqueueQuery(String sql) {

    if (sql == null || sql == '')
      throw new PostgresqlException('SQL query is null or empty.');

    if (sql.contains('\u0000'))
      throw new PostgresqlException('Sql query contains a null character.');

    if (_state == closed)
      throw new PostgresqlException('Connection is closed, cannot execute query.');

    var query = new _Query(sql);
    _sendQueryQueue.addLast(query);

    new Future(() => _processSendQueryQueue());

    return query;
  }

  void _processSendQueryQueue() {

    if (_sendQueryQueue.isEmpty)
      return;

    if (_query != null)
      return;

    if (_state == closed)
      return;

    assert(_state == idle);

    _query = _sendQueryQueue.removeFirst();

    var msg = new MessageBuffer();
    msg.addByte(_MSG_QUERY);
    msg.addInt32(0); // Length padding.
    msg.addUtf8String(_query.sql);
    msg.setLength();

    _socket.add(msg.buffer);

    _state = busy;
    _query._state = _BUSY;
    _transactionState = unknown;
  }

  void _readRowDescription(int msgType, int length) {

    assert(_buffer.bytesAvailable >= length);

    _state = streaming;

    int count = _buffer.readInt16();
    var list = new List<_Column>(count);

    for (int i = 0; i < count; i++) {
      var name = _buffer.readUtf8String(length); //TODO better maxSize.
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
      var col = _query._columns[index];
      if (col.isBinary) throw new UnimplementedError(
          'Binary result set parsing is not implemented.');
      var str = _buffer.readUtf8StringN(colSize);
      var value = _typeConverter.decode(str, col.fieldType);
      _query._rowData[index] = value;
    }

    // If last column, then return the row.
    if (index == _query._columnCount - 1)
      _query.addRow();
  }

  dynamic _decodeBinaryValue(_Column col, List<int> data) {
    throw new UnimplementedError('Binary data parsing not implemented.');
  }

  void _readCommandComplete(int msgType, int length) {

    assert(_buffer.bytesAvailable >= length);

    var commandString = _buffer.readUtf8String(length);
    int rowsAffected =
        int.parse(commandString.split(' ').last, onError: (_) => null);

    _query._commandIndex++;
    _query._rowsAffected = rowsAffected;
  }

  void close() {
    if (_state == closed)
      return;

    var prior = _state;
    _state = closed;

    try {
      var msg = new MessageBuffer();
      msg.addByte(_MSG_TERMINATE);
      msg.addInt32(0);
      msg.setLength();
      _socket.add(msg.buffer);
    } on Exception catch (e, st) {
      _messages.add(new _ClientMessage(
          severity: 'WARNING',
          message: 'Exception while closing connection. Closed without sending terminate message.',
          exception: e,
          stackTrace: st));
    }

    _destroy();
  }

  void _destroy() {
    _state = closed;
    _socket.destroy();
    new Future(() => _messages.close());
  }

}
