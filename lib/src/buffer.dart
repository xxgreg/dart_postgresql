library postgresql.buffer;

import 'dart:collection';
import 'dart:convert';
import 'package:postgresql/postgresql.dart';

// TODO Plenty of oportunity for optimisation here. This is just a quick and simple,
// implementation.
// Switch to use new core classes such as ChunkedConversionSink
// Example here: https://www.dartlang.org/articles/converters-and-codecs/
class Buffer {

  int _position = 0;
  final Queue<List<int>> _queue = new Queue<List<int>>();

  int _bytesRead = 0;
  int get bytesRead => _bytesRead;

  int get bytesAvailable => _queue.fold(0, (len, buffer) => len + buffer.length) - _position;

  int readByte() {
    if (_queue.isEmpty)
      throw new PostgresqlException("Attempted to read from an empty buffer.");

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
      if (i > maxSize) throw new PostgresqlException('Max size exceeded while reading string: $maxSize.');
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

//TODO switch to using the new ByteBuilder class.
class MessageBuffer {
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

  void addUtf8String(String s) {
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

