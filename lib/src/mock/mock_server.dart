part of postgresql.mock;

class MockServerImpl implements MockServer {
  
  MockServerImpl() {
    socket.onClose = () {
      _isClosed = true;
      log.add(new Packet(clientClosed, []));
    };
    
    socket.onDestroy = () {
      _isClosed = true;
      _isDestroyed = true;
      log.add(new Packet(clientDestroyed, []));
    };
    
    socket.onAdd = (data) {
      received.add(data);
      log.add(new Packet(toServer, data));
      if (_waitForClient != null) {
        _waitForClient.complete();
        _waitForClient = null;
      }
    };
    
    socket.onError = (err, [st]) {
      throw err;
      print(st);
    };
  }
  
  Future<pg.Connection> connect() => ConnectionImpl.connect(
      'postgres://testdb:password@localhost:5433/testdb', null, null, 
      mockSocketConnect: (host, port) => new Future.value(socket));
  
  final Mocket socket = new Mocket();
  final List<Packet> log = new List<Packet>();
  final List<List<int>> received = new List<List<int>>();
  
  bool _isClosed = true;
  bool _isDestroyed = true;
  bool get isClosed => _isClosed;
  bool get isDestroyed => _isDestroyed;
  
  /// Send data over the socket from the mock server to the client listening
  /// on the socket.
  void sendToClient(List<int> data) {
    log.add(new Packet(toClient, data));
    socket._controller.add(data);
  }
  
  /// Clear out received data.
  void clear() {
    received.clear();
  }
  
  void close() {
    log.add(new Packet(serverClosed, []));
    _isClosed = true;
    _isDestroyed = true;
    socket._controller.close();
  }
  
  void socketException(String msg) {
    log.add(new Packet(socketError, []));
    socket._controller.addError(new SocketException(msg));
  }
  
  Completer _waitForClient;
  
  /// Wait for the next packet to arrive from the client.
  Future waitForClient() {
    if (_waitForClient == null)
      _waitForClient = new Completer();
    return _waitForClient.future;
  }
  
  stop() {}
}


class Mocket extends StreamView<List<int>> implements Socket {
 
  factory Mocket() => new Mocket._private(new StreamController<List<int>>());
  
  Mocket._private(ctl)
    : super(ctl.stream),
    _controller = ctl;
   
  final StreamController<List<int>> _controller;
  
  bool _isDone = false;
  
  Function onClose;
  Function onDestroy;
  Function onAdd;
  Function onError;
  
  Future close() {
    _isDone = true;
    onClose();
    return new Future.value();
  }
  
  void destroy() {
    _isDone = true;
    onDestroy();
  }
  
  void add(List<int> data) => onAdd(data);
  
  void addError(error, [StackTrace stackTrace]) => onError(error, stackTrace);
  
  
  Future addStream(Stream<List<int>> stream) {
    throw new UnimplementedError();
    stream.listen(null)
      ..onData((data) => add(data))
      ..onDone(() => close())
      ..onError((e) => addError(e));
  }

  Future get done => new Future.value(_isDone);

  InternetAddress get address => throw new UnimplementedError();
  get encoding => throw new UnimplementedError();
  void set encoding(_encoding) => throw new UnimplementedError();
  Future flush() => new Future.value(null);
  int get port => throw new UnimplementedError();
  InternetAddress get remoteAddress => throw new UnimplementedError();
  int get remotePort => throw new UnimplementedError();
  bool setOption(SocketOption option, bool enabled) => throw new UnimplementedError();
  void write(Object obj) => throw new UnimplementedError();

  void writeAll(Iterable objects, [String separator = ""]) => throw new UnimplementedError();
  void writeCharCode(int charCode) => throw new UnimplementedError();
  void writeln([Object obj = ""]) => throw new UnimplementedError();
}

