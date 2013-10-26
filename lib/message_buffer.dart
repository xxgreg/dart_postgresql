part of postgresql;

class _MessageBuffer {
  List<int> _buffer = new List<int>();
  List<int> get buffer => _buffer;

  void addByte(int byte) {
    assert(byte >= 0 && byte < 256);
    _buffer.add(byte);
  }

  void addInt16(int i) {
    assert(i >= -32768 && i <= 32767);

    if (i < 0)
      i = 0x10000 + i;

    int a = (i >> 8) & 0x00FF;
    int b = i & 0x00FF;

    _buffer.add(a);
    _buffer.add(b);
  }

  void addInt32(int i) {
    assert(i >= -2147483648 && i <= 2147483647);

    if (i < 0)
      i = 0x100000000 + i;

    int a = (i >> 24) & 0x000000FF;
    int b = (i >> 16) & 0x000000FF;
    int c = (i >> 8) & 0x000000FF;
    int d = i & 0x000000FF;

    _buffer.add(a);
    _buffer.add(b);
    _buffer.add(c);
    _buffer.add(d);
  }

  void addString(String s) {
    //Postgresql server must be configured to accept UTF8 - this is the default.
    _buffer.addAll(UTF8.encode(s));
    addByte(0);
  }

  void setLength({bool startup: false}) {
    int offset = 0;
    int i = _buffer.length;

    if (!startup) {
      offset = 1;
      i -= 1;
    }

    _buffer[offset] = (i >> 24) & 0x000000FF;
    _buffer[offset + 1] = (i >> 16) & 0x000000FF;
    _buffer[offset + 2] = (i >> 8) & 0x000000FF;
    _buffer[offset + 3] = i & 0x000000FF;
  }
}

