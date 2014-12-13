part of postgresql.protocol;

//TODO use typed_data.ByteData
class MessageBuilder {
  
  MessageBuilder(this._messageCode) {
    // All messages other than startup have a message code header.
    if (_messageCode != 0)
      _builder.addByte(_messageCode);
    
    // Add a padding for filling in the length during build.
    _builder.add(const [0, 0, 0, 0]);
  }
  
  final int _messageCode;
  
  //TODO experiment with disabling copy for performance.
  //Probably better just to do for large performance sensitive message types.
  final BytesBuilder _builder = new BytesBuilder(copy: true);
  
  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _builder.addByte(byte);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0) i = 0x10000 + i;

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _builder.addByte(a);
    _builder.addByte(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0) i = 0x100000000 + i;

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _builder.addByte(a);
    _builder.addByte(b);
    _builder.addByte(c);
    _builder.addByte(d);
  }

  void addString(String s) => addUtf8(s);
  
  //FIXME rename to addString()
  /// Add a null terminated string.
  void addUtf8(String s) {
    // Postgresql server must be configured to accept UTF8 - this is the default.
    _builder.add(UTF8.encode(s));
    addByte(0);
  }

  void addBytes(List<int> bytes) {
    _builder.add(bytes);
  }
  
  List<int> build() {
    var bytes = _builder.toBytes();

    int offset = 0;
    int i = bytes.length;

    if (_messageCode != 0) {
      offset = 1;
      i -= 1;
    }

    bytes[offset] = (i >> 24) & 0x000000FF;
    bytes[offset + 1] = (i >> 16) & 0x000000FF;
    bytes[offset + 2] = (i >> 8) & 0x000000FF;
    bytes[offset + 3] = i & 0x000000FF;
    
    return bytes;
  }
}
