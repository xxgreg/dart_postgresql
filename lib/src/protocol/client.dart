part of postgresql.protocol;

//TODO enum
int ok = 42;
int needInput = 43;
int closed = 44;

class ProtocolClient {

  ProtocolClient(this._socket) {
    _socket.listen(_onReceive)
      ..onDone(_messages.close)
      ..onError(_messages.addError);
  }
  
  final Socket _socket;
  
  //FIXME Currently this timeout doesn't cancel the socket connection 
  // process.
  // There is a bug open about adding a real socket connect timeout
  // parameter to Socket.connect() if this happens then start using it.
  // http://code.google.com/p/dart/issues/detail?id=19120
  // Throws timeout exception if timeout reached.
  // Socket exception if something se failed.
  static Future<ProtocolClient> connect(
      String host, int port,
      {bool requireSsl: false, Duration timeout: const Duration(minutes: 2)}) {
    
    if (requireSsl) return _connectSsl(host, port, timeout);
    
    return Socket.connect(host, port)
        .timeout(timeout)
        .then((s) => new ProtocolClient(s));
  }

  static Future<ProtocolClient> _connectSsl(
      String host, int port, Duration timeout) {
       
    return Socket.connect(host, port)
        .then((socket) {
          // Write header, and SSL magic number.
          socket.add([0, 0, 0, 8, 4, 210, 22, 47]);
          
          return socket.first.then((packet) {
            if (packet[0] != _S) {
              socket.destroy();
              throw new Exception('Postgresql server is not configured to '
                  'support SSL connections.');
            }
            return SecureSocket.secure(socket, 
                onBadCertificate: (cert) => true);
          });
        })
        .timeout(timeout)
        .then((s) => new ProtocolClient(s));
  }

  final StreamController<ProtocolMessage> _messages =
      new StreamController<ProtocolMessage>();
  
  final ZeroCopyBytesBuilder _buffer = new ZeroCopyBytesBuilder();
  
  int _state = ok;
  
  int get state => _state;
  
  Stream<ProtocolMessage> get messages => _messages.stream;
  
  void close() {
    _state = closed;
    _messages.close();
    _socket.destroy();
  }
  
  Future send(ProtocolMessage msg) {
    if (_state == closed) return new Future.error(
      'Protocol client state is closed, cannot send msg: $msg');
    
    var bytes = msg.encode();
    _socket.add(bytes);
    return _socket.flush();
  }
      
  _onReceive(List<int> bytes) {
    if (_state == closed || bytes.length == 0) return;
    
    ByteReader r;
    
    if (_state == ok) {
      r = new ByteReader(bytes);
    } else if (_state == needInput) {
      _buffer.add(bytes);    
      var s = _readBufferedMessage(_buffer);
      if (s == needInput) return;
      if (_buffer.isEmpty) {
        _state = ok;
        return;
      }
      assert(s == ok);
      var r = new ByteReader(_buffer.takeChunk());
      assert(_buffer.isEmpty);
    } else {
      assert(false);
    }
    
    var s = ok;
    while (r.bytesAvailable > 0 && s == ok) {
      s = _readMessage(r);
    }
    
    if (s == needInput) {
      // Usually remaining bytes will be short so make a copy, so the rest of
      // the buffer can be freed.
      // TODO consider testing the size, and if significant then keeping a view
      // instead.
      _buffer.add(r.readBytes(r.bytesAvailable, copy: true));
    }
    
    _state = s; 
  }
  
  
  int _readMessage(ByteReader r) {
        
    // If not enough bytes remaining to read the header, then copy these bytes
    // into the buffer.
    if (r.bytesAvailable < 5) return needInput;

    // Read the message header.
    // Header format is a one byte message type code, and a four byte integer
    // message length (length excludes the one byte for the message type code,
    // but includes the four bytes for the message length).
    var b = r.peekBytes(5);
    
    int msgType = b[0];
    
    // 32 bit big endian signed integer. But negative values are not valid,
    // and size is checked anyway so negative numbers will be caught as 
    // they will return large positive numbers.
    int length = (b[1] << 24) | (b[2] << 16) | (b[3] << 8) | b[4];
    
    // Throws if message length is too large.
    _checkMessageLength(msgType, length);
    
    // Check to see if the entire message is already in the buffer.
    if (r.bytesAvailable < length) return needInput;
    
    int bytesRead = r.bytesRead;
    
    // Skip the header which is already parsed
    r.skipBytes(5);
    
    // Only pass the length of the message body to decode.
    //FIXME consider how ProtocolExceptions are handled.
    _messages.add(ProtocolMessage.decode(msgType, length - 4, r));
    
    if (r.bytesRead - bytesRead != length + 1)
      throw new Exception('Protocol error: lost message sync'); //TODO exception type.
    
    return ok;
  }

  // Basically a copy of readMessage(), kept separate for performance
  // reasons, as readMessage is on a hot code path. Could refactor to
  // share code better, but will need to test to make sure that it does not
  // regress performance.
  int _readBufferedMessage(ZeroCopyBytesBuilder bytes) {
        
    // If not enough bytes remaining to read the header, then copy these bytes
    // into the buffer.
    if (bytes.length < 5) return needInput;

    // Read the message header.
    // Header format is a one byte message type code, and a four byte integer
    // message length (length excludes the one byte for the message type code,
    // but includes the four bytes for the message length).
    var b = bytes.peekBytes(5);
    
    int msgType = b[0];
    
    // 32 bit big endian signed integer. But negative values are not valid,
    // and size is checked anyway so negative numbers will be caught as 
    // they will return large positive numbers.
    int length = (b[1] << 24) | (b[2] << 16) | (b[3] << 8) | b[4];
    
    // Throws if message length is too large.
    _checkMessageLength(msgType, length);
    
    // Check to see if the entire message is already in the buffer.
    if (bytes.length < length) return needInput;
    
    // Get a view of the message data.
    var list = bytes.takeBytes(length + 5, copy: false);
    
    // Skip the header which is already parsed
    var reader = new ByteReader(list)..skipBytes(5);
    
    // Only pass the length of the message body to decode.
    //FIXME consider how ProtocolExceptions are handled.
    _messages.add(ProtocolMessage.decode(msgType, length - 4, reader));
    
    if (reader.bytesRead != length + 1)
      throw new Exception('Protocol error: lost message sync'); //TODO exception type.
    
    return ok;
  }

  //TODO define these constants within protocol library.
  // These are the only messages from the server which may exceed 30,000 bytes.
  static const _longMessagesTypes = const [_MSG_NOTICE_RESPONSE, 
                                           _MSG_ERROR_RESPONSE, 
                                           _MSG_COPY_DATA, 
                                           _MSG_ROW_DESCRIPTION, 
                                           _MSG_DATA_ROW, 
                                           _MSG_FUNCTION_CALL_RESPONSE,
                                           _MSG_NOTIFICATION_RESPONSE];
  
  void _checkMessageLength(int msgType, int msgLength) {

    //TODO exception type and atoi.
    error() => new Exception(
        'Protocol error invalid message length: $msgType $msgLength');

//FIXME figure out how to check these. Probably not neccesary but best to
// match libpq's behaviour where possible.
//    if (_state == authenticating) {
//      if (msgLength < 8) return false;
//      if (msgType == _MSG_ERROR_RESPONSE && msgLength > 30000) return false;
//    } else {
    
      if (msgType == _MSG_AUTH_REQUEST && msgLength > 2000) throw error();
    
      if (msgLength < 4 ||
          (msgLength > 30000 && !_longMessagesTypes.contains(msgType)))
        throw error();
  }

}

