part of postgresql.protocol;


class ZeroCopyBytesBuilder {
  
  int _position = 0; // 0 >= _position >= _chunks.first.length 
  int _length = 0;
  final List<Uint8List> _chunks = <Uint8List>[];
  
  int get length => _length;
  
  bool get isEmpty => _length == 0;
  
  bool get isNotEmpty => _length != 0;
  
//  void clear() {
//    _position = 0;
//    _length = 0;
//    _chunks.clear();
//  }

  void add(List<int> bytes, {copy: false}) {
    assert(_chunks.isEmpty || _position <= _chunks.first.length);
    if (bytes.isEmpty) return;
    if (copy || bytes is! Uint8List)
      bytes = new Uint8List.fromList(bytes);
    _chunks.add(bytes);
    _length += bytes.length;
    assert(_chunks.isEmpty || _position <= _chunks.first.length);
  }
    
  /// Warning: very inefficient, only use for short sized lists.
  /// Returns a normal List<int>, not a Uint8List.
  List<int> peekBytes(int count) {
    if (_chunks.isEmpty) return const [];
    int i = 0, c = 0, p = _position;
    Uint8List chunk = _chunks.first;
    var result = new List(count);
    while (i < count) {
      if (p >= chunk.length) {
        p = 0;
        chunk = _chunks[++c];
      }      
      result[i] = chunk[p];
      p++;
      i++;
    }
    return result;
  }
  
  // Return a Uint8ListView into the buffer if possible. If bytes are split
  // accross multiple buffers, then they will be copied.
  List<int> takeBytes(int count, {copy: false}) {
    
    assert(_chunks.isEmpty || _position <= _chunks.first.length);
    
    if (count < 0) throw new ArgumentError();
    
    if (count == 0) return new Uint8List(0);
    
    if (count > length) throw new Exception(); //TODO 
    
    var chunk = _chunks.first;
    
    Uint8List bytes;
    if (!copy && _position + count < chunk.length) {
      bytes = new Uint8List.view(chunk.buffer, _position, count);
      _length -= count;
      _position += count;
    
    } else if (!copy && _position + count == chunk.length) {
      bytes = new Uint8List.view(chunk.buffer, _position);
      _length -= count;
      _position = 0;
      _chunks.removeAt(0);            
      
    } else if (copy && _position + count <= chunk.length) {
      //Copy into a new contiguous buffer.
      bytes = new Uint8List(count)..setRange(0, count, chunk, _position);
      _length -= count;
      _position += count;
      
    } else {
      // Copy into a new contiguous buffer.
      bytes = new Uint8List(count);
      int len = chunk.length - _position;
      bytes.setRange(0, len, chunk, _position);
      _chunks.removeAt(0);
      
      int p = len;
      while (p < count) {
        var c = _chunks.first;
        int remaining = count - p;
        if (c.length > remaining) {
          _position = remaining;
          bytes.setRange(p, p + remaining, c);
          p += remaining;
          assert(p == count);
        } else {
          _chunks.removeAt(0);
          bytes.setRange(p, p + c.length, c);
          p += c.length;
        }
      }
      assert(p == count);
      _length -= count;
    }
    
    assert(_chunks.isEmpty || _position <= _chunks.first.length);
    
    return bytes;
  }
  
  /// Returns the remaining consecutive bytes in the builder.
  List<int> takeChunk() {
    if (isEmpty) return new Uint8List(0);
    var chunk = _chunks.removeAt(0);
    var view = new Uint8List.view(chunk.buffer, _position);
    _length -= view.length;
    _position = 0;
    return view;
  }
    
}


/// See http://www.postgresql.org/docs/9.2/static/protocol-message-types.html
class ByteReader {
  
  factory ByteReader(List<int> bytes, [int offset = 0]) {
    var list = bytes is Uint8List ? bytes : new Uint8List.fromList(bytes);
    var byteData = new ByteData.view(list.buffer, list.offsetInBytes);
    return new ByteReader._private(byteData, list, offset);
  }

  ByteReader._private(this._bytes, this._list, this._position);
  
  final ByteData _bytes;
  final Uint8List _list;
  int _position;
  
  int get bytesAvailable => _bytes.lengthInBytes - _position;
  int get bytesRead => _position;

  /// Warning - inefficient, only use for short lists.
  List<int> peekBytes(int count) => _list.sublist(_position, _position + count);
  
  void skipBytes(int count) {
    _position += count;
    assert(bytesAvailable >= 0);
  }
  
  int readByte() => _bytes.getUint8(_position++);
  
  int readInt16() {
    int i = _bytes.getUint16(_position, Endianness.BIG_ENDIAN);
    _position += 2;
    return i;
  }
  
  int readInt32() {
    int i = _bytes.getUint32(_position, Endianness.BIG_ENDIAN);
    _position += 4;
    return i;
  }
    
  /// If copy is false return a Uint8List view, otherwise copy into a new 
  /// Uint8List.
  List<int> readBytes(int count, {copy: true}) {
    if (count < 0) throw new Exception(); //FIXME
    
    if (count == 0) return new Uint8List(0);
    
    var bytes = copy
      ? (new Uint8List(count)..setRange(0, count, _list, _position))
      : new Uint8List.view(_list.buffer, _position, count);
    
    _position += count;
    
    return bytes;
  }
  
  /// Read a zero terminated UTF8 string.
  String readString() {
    //TODO check using indexOf is fast, maybe just use a while loop.
    int len = _list.indexOf(0, _position) - _position;
    if (len < 0) throw new Exception('Protocol error: unterminated string.'); //FIXME    
    var bytes = readBytes(len, copy: false);
    assert(readByte() == 0);
    //TODO soon can use UTF8.decoder.convert(bytes, start, end);
    return UTF8.decode(bytes);
  }
  
  /// Read a fixed length UTF8 string.
  String readStringN(int lengthInBytes) {
    var bytes = readBytes(lengthInBytes, copy: false);
    _position += lengthInBytes;
    return UTF8.decode(bytes);
  }
  
}

