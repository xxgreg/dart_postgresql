part of postgresql;

// TODO Plenty of oportunity for optimisation here. This is just a quick and simple,
// implementation.
// Switch to use new core classes such as ChunkedConversionSink
// Example here: https://www.dartlang.org/articles/converters-and-codecs/
class _Buffer {

  int _position = 0;
  final Queue<List<int>> _queue = new Queue<List<int>>();

  int _bytesRead = 0;
  int get bytesRead => _bytesRead;

  int get bytesAvailable => _queue.fold(0, (len, buffer) => len + buffer.length) - _position;

  int readByte() {
    if (_queue.isEmpty)
      throw new Exception("Attempted to read from an empty buffer.");

    int byte = _queue.first[_position];

    _position++;
    if (_position >= _queue.first.length) {
      _queue.removeFirst();
      _position = 0;
    }

    _bytesRead++;

    return byte;
  }

  int readInt16() {
    int a = readByte();
    int b = readByte();

    assert(a < 256 && b < 256 && a >= 0 && b >= 0);
    int i = (a << 8) | b;

    if (i >= 0x8000)
      i = -0x10000 + i;

    return i;
  }

  int readInt32() {
    int a = readByte();
    int b = readByte();
    int c = readByte();
    int d = readByte();

    assert(a < 256 && b < 256 && c < 256 && d < 256 && a >= 0 && b >= 0 && c >= 0 && d >= 0);
    int i = (a << 24) | (b << 16) | (c << 8) | d;

    if (i >= 0x80000000)
      i = -0x100000000 + i;

    return i;
  }

  List<int> readBytes(int bytes) {
    var list = new List<int>(bytes);
    for (int i = 0; i < bytes; i++) {
      list[i] = readByte();
    }
    return list;
  }

  /// Read a fixed length utf8 string with a known size in bytes.
  //TODO This is a hot method find a way to optimise this.
  // Switch to use new core classes such as ChunkedConversionSink
  // Example here: https://www.dartlang.org/articles/converters-and-codecs/
  String readUtf8StringN(int size) => UTF8.decode(readBytes(size));


  /// Read a zero terminated utf8 string.
  String readUtf8String(int maxSize) {
    //TODO Optimise this. Though note it isn't really a hot function. The most
    // performance critical place that this is used is in reading column headers
    // which are short, and only once per query.
    var bytes = new List<int>();
    int c, i = 0;
    while ((c = readByte()) != 0) {
      if (i > maxSize) throw new _PgClientException('Max size exceeded while reading string: $maxSize.');
      bytes.add(c);
    }
    return UTF8.decode(bytes);
  }

  void append(List<int> data) {
    if (data == null || data.isEmpty)
      throw new Exception("Attempted to append null or empty list.");

    _queue.addLast(data);
  }
}
