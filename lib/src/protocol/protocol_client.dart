part of postgresql.protocol;

//enum ReadResult { done, needInput }
//int notConnected; not needed as connecting is done externally.
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
  
  final StreamController<ProtocolMessage> _messages =
      new StreamController<ProtocolMessage>();
  
  final ByteBuffer _buffer = new ByteBuffer();
  
  int _state = ok;
  
  int get state => _state;
  
  Stream<ProtocolMessage> get messages => _messages.stream;
  
  Future send(ProtocolMessage msg) {
    var bytes = msg.encode();
    _socket.add(bytes);
    return _socket.flush();
  }
      
  _onReceive(List<int> bytes) {
    
    if (_state == closed) return;
    
    if (bytes.length == 0)
      return;
    
    ByteReader r;
    
    if (_state == ok) {
      var r = new ByteReader(bytes);    
    } else if (_state == needInput) {
      _buffer.addBytes(bytes);
      var br = _buffer.reader;
      var s = _readMessage(br);
      if (s == needInput) return;
      // ByteReader is faster than BufferedByteReader, so use this for the
      // remaining messages.
      // TODO test overhead of Uint8ListView. If slow, consider passing an
      // offset instead.
      r = new ByteReader(br.remainingBytes);
    } else {
      assert(false);
    }
    
    var s = ok;  
    while (r.bytesAvailable > 0 && s == ok) {
      s = _readMessage(r); 
    }
    
    if (s == needInput)
      _buffer.addBytesView(r.remainingBytes);
    else
      _buffer.clear();
    
    _state = s; 
  }
  
  
  /// Common fast case where the messages are not split across a packet.
  int _readMessage(ByteReader r) {
            
    // If not enough bytes remaining to read the header, then copy these bytes
    // into the buffer.
    if (r.bytesAvailable < 5) return needInput;

    // Message length is the message length excluding the message type code, but
    // including the 4 bytes for the length fields. Only the length of the body
    // is passed to each of the message handlers.
    int msgType = r.readByte();
    int length = r.readInt32() - 4;
    
    if (r.bytesAvailable < length) return needInput;
    
    //FIXME consider how ProtocolExceptions are handled.
    _messages.add(ProtocolMessage.decode(msgType, length, r));
    
    return ok;
  }
  
}

