part of postgresql.protocol;

abstract class ByteReader {
  
  factory ByteReader(List<int> bytes) => new ByteReaderImpl(bytes);
  
  int readByte();
  int readInt16();
  int readInt32();
  String readString([int maxLength = 64000]);
  String readStringN(int length);
  
  //FIXME Currently always copies.
  List<int> readBytes(int count); 
  
  int get bytesAvailable;
  
  // The remaining bytes in the buffer. Throws an error if this
  // is called and there is more than one byte array left to be consumed.
  // Is usually a Uint8ListView.
  List<int> get remainingBytes;
}

class ByteReaderImpl implements ByteReader {
  
  ByteReaderImpl(this._bytes);
  
  final List<int> _bytes;
  int _offset = 0;
  
  int readByte() {
    int b = _bytes[_offset];
    _offset++;
    assert(b < 256 && b >= 0);
    return b;
  }
  
  int readInt16() {
    int a = _bytes[_offset];
    int b = _bytes[_offset + 1];

    _offset += 2;
    
    assert(a < 256 && b < 256 && a >= 0 && b >= 0);
    int i = (a << 8) | b;

    if (i >= 0x8000)
      i = -0x10000 + i;
    
    return i;  
  }
  
  int readInt32() {
      int a = _bytes[_offset];
      int b = _bytes[_offset + 1];
      int c = _bytes[_offset + 2];
      int d = _bytes[_offset + 3];

      _offset += 4;
      
      assert(a < 256 && b < 256 && c < 256 && d < 256 && a >= 0 && b >= 0 && c >= 0 && d >= 0);
      int i = (a << 24) | (b << 16) | (c << 8) | d;

      if (i >= 0x80000000)
        i = -0x100000000 + i;      
      
      return i;
  }

  String readStringN(int size) => UTF8.decode(readBytes(size));

  /// Read a zero terminated utf8 string.
  String readString([int maxSize = 64000]) {

    int i = _offset;
    while(_bytes[i] != 0 && i <= _offset + maxSize) {
      i++;
    }
    
    if (_bytes[i] != 0)
      throw new Exception('Max size exceeded while reading string: $maxSize.');
    
    var bytes = _bytes.sublist(_offset, i);
    return UTF8.decode(bytes);
    
    //FIXME soon it will be possible to do this to remove the copy.
    //return UTF8.decoder.convert(_bytes, offset, i);
  }
  
  //FIXME provide a non copying implementation.
  List<int> readBytes(int bytes) => _bytes.sublist(_offset, _offset + bytes);
  
  int get bytesAvailable => _bytes.length - _offset;
  

  List<int> get remainingBytes {
    if (_bytes is Uint8List) {
      Uint8List b = _bytes; //FIXME Why do I have to cast here?
      return new Uint8List.view(b.buffer, _offset);
    } else {
      return _bytes.sublist(_offset);
    }
  }
}


class ByteBuffer {

  ByteBuffer();
    
  int _position = 0;
  final List<List<int>> _queue = new List<List<int>>();

  int get bytesAvailable => _queue.fold(0, (len, buffer) => len + buffer.length) - _position;

  void clear() {
    _queue.clear();
    _position = 0;
  }

  void addBytes(List<int> bytes) {
    assert(bytes != null && bytes.isNotEmpty);
    _queue.add(bytes);
  }
  
  void addBytesView(List<int> bytes) => addBytes(bytes);
  
  ByteReader get reader => new ByteBufferReader(this);
}

// TODO Plenty of oportunity for optimisation here. This is just a quick and simple,
// implementation. But this code probably isn't in a hot path, since it is only
// used for passing messages that span multiple packets. (Well maybe getBytes() needs to be fancy??).
class ByteBufferReader implements ByteReader {
  
  ByteBufferReader(this._buffer);
  
  final ByteBuffer _buffer;
    
  int get bytesAvailable => _buffer.bytesAvailable;
  
  List<int> get remainingBytes {
    if (_buffer._queue.length != 1)
      throw new Exception('remainingBytes called on invalid buffer.');
    
    var bytes = _buffer._queue[0];
    
    if (bytes is Uint8List) {
      return new Uint16List.view(bytes.buffer, _buffer._position);
    } else {
      return bytes.sublist(_buffer._position);
    }
  }
  
  int readByte() {
    if (_buffer._queue.isEmpty)
      throw new Exception("Attempted to read from an empty buffer.");

    int byte = _buffer._queue.first[_buffer._position];

    _buffer._position++;
    if (_buffer._position >= _buffer._queue.first.length) {
      _buffer._queue.removeAt(0);
      _buffer._position = 0;
    }

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

  String readStringN(int size) => UTF8.decode(readBytes(size));

  /// Read a zero terminated utf8 string.
  String readString([int maxSize = 64000]) {
    var bytes = new List<int>();
    int c, i = 0;
    while ((c = readByte()) != 0) {
      if (i > maxSize) throw new Exception('Max size exceeded while reading string: $maxSize.');
      bytes.add(c);
    }
    return UTF8.decode(bytes);
  }

}

