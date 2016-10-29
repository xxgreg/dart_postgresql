part of postgresql.mock;

class MockServerBackendImpl implements Backend {
  MockServerBackendImpl() {
    mocket.onClose = () {
      _isClosed = true;
      log.add(new Packet(clientClosed, []));
    };

    mocket.onDestroy = () {
      _isClosed = true;
      _isDestroyed = true;
      log.add(new Packet(clientDestroyed, []));
    };

    mocket.onAdd = (List<int> data) {
      received.add(data);
      log.add(new Packet(toServer, data));
      if (_waitForClient != null) {
        _waitForClient.complete();
        _waitForClient = null;
      }
    };

    mocket.onError = (err, [st]) {
      throw err;
    };
  }

  final Mocket mocket = new Mocket();

  final List<Packet> log = new List<Packet>();
  final List<List<int>> received = new List<List<int>>();

  bool _isClosed = true;
  bool _isDestroyed = true;
  bool get isClosed => _isClosed;
  bool get isDestroyed => _isDestroyed;

  /// Clear out received data.
  void clear() {
    received.clear();
  }

  /// Server closes the connection to client.
  void close() {
    log.add(new Packet(serverClosed, []));
    _isClosed = true;
    _isDestroyed = true;
    mocket.close();
  }

  Completer _waitForClient;

  /// Wait for the next packet to arrive from the client.
  Future waitForClient() {
    if (_waitForClient == null) _waitForClient = new Completer();
    return _waitForClient.future;
  }

  /// Send data over the socket from the mock server to the client listening
  /// on the socket.
  void sendToClient(List<int> data) {
    log.add(new Packet(toClient, data));
    mocket._controller.add(data);
  }

  void socketException(String msg) {
    log.add(new Packet(socketError, []));
    mocket._controller.addError(new SocketException(msg));
  }
}

class MockServerImpl implements MockServer {
  MockServerImpl();

  Future<pg.Connection> connect() =>
      ConnectionImpl.connect('postgres://testdb:password@localhost:5433/testdb',
          mockSocketConnect: (host, port) => new Future(() => _startBackend()));

  stop() {}

  final List<Backend> backends = <Backend>[];

  Mocket _startBackend() {
    var backend = new MockServerBackendImpl();
    backends.add(backend);

    if (_waitForConnect != null) {
      _waitForConnect.complete(backend);
      _waitForConnect = null;
    }

    return backend.mocket;
  }

  Completer<Backend> _waitForConnect;

  /// Wait for the next client to connect.
  Future<Backend> waitForConnect() {
    if (_waitForConnect == null) _waitForConnect = new Completer();
    return _waitForConnect.future;
  }
}

class Mocket extends StreamView<List<int>> implements Socket {
  factory Mocket() => new Mocket._private(new StreamController<List<int>>());

  Mocket._private(StreamController<List<int>> ctl)
      : _controller = ctl,
        super(ctl.stream);

  final StreamController<List<int>> _controller;

  bool _isDone = false;

  Function onClose;
  Function onDestroy;
  Function onAdd;
  Function onError;

  Future<Socket> close() {
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
  }

  Future<Socket> get done => new Future.value(_isDone);

  InternetAddress get address => throw new UnimplementedError();
  get encoding => throw new UnimplementedError();
  void set encoding(_encoding) => throw new UnimplementedError();
  Future flush() => new Future.value(null);
  int get port => throw new UnimplementedError();
  InternetAddress get remoteAddress => throw new UnimplementedError();
  int get remotePort => throw new UnimplementedError();
  bool setOption(SocketOption option, bool enabled) =>
      throw new UnimplementedError();
  void write(Object obj) => throw new UnimplementedError();

  void writeAll(Iterable objects, [String separator = ""]) =>
      throw new UnimplementedError();
  void writeCharCode(int charCode) => throw new UnimplementedError();
  void writeln([Object obj = ""]) => throw new UnimplementedError();
}
