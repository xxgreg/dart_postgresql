part of postgresql.mock;


class MockSocketServerImpl implements MockServer {

  static Future<MockSocketServerImpl> start([int port]) {
    port = port == null ? 5435 : port;
    return ServerSocket.bind('127.0.0.1', port)
        .then((s) => new MockSocketServerImpl._private(s));
  }
  
  MockSocketServerImpl._private(this.server) {
    server
      .listen(_handleConnect)
      ..onError((e) => _log(e))
      ..onDone(() => _log('MockSocketServer client disconnected.'));
  }
  
  Future<pg.Connection> connect(
      {String uri, 
       Duration connectionTimeout,
       pg.TypeConverter typeConverter}) => pg.connect(
          uri == null ? 'postgres://testdb:password@localhost:${server.port}/testdb' : uri,
          connectionTimeout: connectionTimeout,
          typeConverter: typeConverter);
  
  Socket socket = null;
  
  final ServerSocket server;
  
  final List<Packet> log = new List<Packet>();
  final List<List<int>> received = new List<List<int>>();
  
  bool _isClosed = true;
  bool _isDestroyed = true;
  bool get isClosed => _isClosed;
  bool get isDestroyed => _isDestroyed;
  
  _handleConnect(Socket s) {    
    socket = s;
    
    socket.listen((data) {
      received.add(data);
      log.add(new Packet(toServer, data));
      if (_waitForClient != null) {
        _waitForClient.complete();
        _waitForClient = null;
      }
    })
    ..onDone(() {
      _isClosed = true;
      log.add(new Packet(clientClosed, []));
    })
    ..onError((err, [st]) {
      _log(err);
      _log(st);
    });
  }
  
  /// Clear out received data.
  void clear() {
    received.clear();
  }

  /// Server closes the connection.
  void close() {
    log.add(new Packet(serverClosed, []));
    _isClosed = true;
    _isDestroyed = true;
    server.close();
  }
  
  
  Completer _waitForClient;
  
  /// Wait for the next packet to arrive from the client.
  Future waitForClient() {
    if (_waitForClient == null)
      _waitForClient = new Completer();
    return _waitForClient.future;
  }

  /// Send data over the socket from the mock server to the client listening
  /// on the socket.
  void sendToClient(List<int> data) {
    log.add(new Packet(toClient, data));
    socket.add(data);
  }

  void socketException(String msg) {
    throw new UnsupportedError('Only valid on MockServer, not MockSocketServer');
  }
  
  void stop() {
    server.close();
  }
}

