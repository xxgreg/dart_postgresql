import 'dart:convert';
import 'package:unittest/unittest.dart';
import 'package:postgresql/src/buffer.dart';

smiles(int i) {
  var sb = new StringBuffer();
  for (int j = 0; j < i; j++) {
    sb.write('smiles ☺');
  }
  return sb.toString();
}

main() {
  test('Buffer', () {
    var buf = new Buffer();

    var msg = new MessageBuffer();
    for (int i = 1; i < 100; i++) {
      msg.addInt16(42);
      msg.addInt32(43);
      msg.addUtf8String(smiles(20));

      var s = smiles(i);
      msg.addInt32(UTF8.encode(s).length);
      msg.addUtf8String(s);
    }

    // Slice up into lots of little lists and add them to the buffer.
    var b = msg.buffer;
    int i = 0;
    while (b.isNotEmpty) {
      i += 7;
      var bytes = (i % 30) + 1;
      if (b.length < bytes) {
        buf.append(b.toList());
        break;
      }
      buf.append(b.take(bytes).toList());
      b = b.skip(bytes);
    }
    expect(buf.bytesAvailable, equals(msg.buffer.length));

    // Read back from the buffer and check that all is ok.
    for (int i = 1; i < 100; i++) {
      expect(buf.readInt16(), equals(42));
      expect(buf.readInt32(), equals(43));
      expect(buf.readUtf8String(100000), smiles(20));

      var s = smiles(i);
      int len = UTF8.encode(s).length;
      expect(buf.readInt32(), equals(len));
      expect(buf.readUtf8StringN(len), equals(s));
      expect(buf.readByte(), equals(0)); // Zero padding byte for string.
    }
  });
}

void addUtf8String(List<int> buffer, String s) {
  buffer.addAll(UTF8.encode(s));
}

void addInt16(List<int> buffer, int i) {
  assert(i >= -32768 && i <= 32767);

  if (i < 0)
    i = 0x10000 + i;

  int a = (i >> 8) & 0x00FF;
  int b = i & 0x00FF;

  buffer.add(a);
  buffer.add(b);
}

void addInt32(List<int> buffer, int i) {
  assert(i >= -2147483648 && i <= 2147483647);

  if (i < 0)
    i = 0x100000000 + i;

  int a = (i >> 24) & 0x000000FF;
  int b = (i >> 16) & 0x000000FF;
  int c = (i >> 8) & 0x000000FF;
  int d = i & 0x000000FF;

  buffer.add(a);
  buffer.add(b);
  buffer.add(c);
  buffer.add(d);
}
