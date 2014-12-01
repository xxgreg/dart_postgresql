import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart';
import 'package:yaml/yaml.dart';

Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {

  DefaultTypeConverter tc = new TypeConverter();

  test('String escaping', () {
    expect(tc.encodeValue('bob', null), equals(" E'bob' "));
    expect(tc.encodeValue('bo\nb', null), equals(r" E'bo\nb' "));
    expect(tc.encodeValue('bo\rb', null), equals(r" E'bo\rb' "));
    expect(tc.encodeValue(r'bo\b', null), equals(r" E'bo\\b' "));

    expect(tc.encodeValue(r"'", null), equals(r" E'\'' "));
    expect(tc.encodeValue(r" '' ", null), equals(r" E' \'\' ' "));
    expect(tc.encodeValue(r"\''", null), equals(r" E'\\\'\'' "));
  });



// Timezone offsets
// Do these need to be parsed?
//  "2001-02-03 04:05:06.123-07"
//  "2001-02-03 04:05:06-07"
//  "2001-02-03 04:05:06-07:42"
//  "2001-02-03 04:05:06-07:30:09"
//  "2001-02-03 04:05:06+07"
//  "0010-02-03 04:05:06.123-07 BC"

//FIXME
//  How to handle Date/Timestamp Infinity/-Infinity?
//  Throw exception or return null?
//  Or crazy idea - return something that implements core.Datetime, including the correct comparison functions?
// Something that wraps it. PgDateTime implements DateTime { _datetime; isInfinity; isNegativeInfinity; }
// Perhaps just throw an exception. Solution is for client code to cast to a string if they want to handle infinity values.

//  Also consider that some Dart datetimes will not be able to be represented
// in postgresql timestamps. i.e. pre 4713 BC or post 294276 AD. Perhaps just
// send these dates and rely on the database to return an error.


  test('encode datetime', () {
    var data = [
      "22001-02-03 00:00:00.000",    new DateTime(22001, DateTime.FEBRUARY, 3),
      "2001-02-03 00:00:00.000",     new DateTime(2001, DateTime.FEBRUARY, 3),
      "2001-02-03 04:05:06.000",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "2001-02-03 04:05:06.999",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 999),
      "0010-02-03 04:05:06.123 BC",  new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 123),
      "0010-02-03 04:05:06.000 BC",      new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 0)
      //TODO test minimum allowable postgresql date
    ];
    var tc = new TypeConverter();
    var d = new DateTime.now().timeZoneOffset; // Get users current timezone
    pad(int i) => i.toString().padLeft(2, '0');
    var tzoff = '${d.isNegative ? '-' : '+'}'
      '${d.inHours}:${pad(d.inMinutes % 60)}:${pad(d.inSeconds % 60)}';
    for (int i = 0; i < data.length; i += 2) {
      var str = data[i];
      var dt = data[i + 1];
      expect(tc.encode(dt, null), equals("'$str $tzoff'"));
    }
  });

  test('encode date', () {
    var data = [
      "22001-02-03",    new DateTime(22001, DateTime.FEBRUARY, 3),
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3),
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 999),
      "0010-02-03 BC",  new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 123),
      "0010-02-03 BC",  new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 0)
    ];
    var tc = new TypeConverter();
    for (int i = 0; i < data.length; i += 2) {
      var str = data[i];
      var dt = data[i + 1];
      expect(tc.encode(dt, 'date'), equals("'$str'"));
    }
  });

  //TODO test more encoding fails too.

  test('encode double', () {
    var data = [
      "'nan'", double.NAN,
      "'infinity'", double.INFINITY,
      "'-infinity'", double.NEGATIVE_INFINITY,
      "1.7976931348623157e+308", double.MAX_FINITE,
      "5e-324", double.MIN_POSITIVE,
      "-0.0", -0.0,
      "0.0", 0.0
    ];
    var tc = new TypeConverter();
    for (int i = 0; i < data.length; i += 2) {
      var str = data[i];
      var dt = data[i + 1];
      expect(tc.encode(dt, null), equals(str));
      expect(tc.encode(dt, 'real'), equals(str));
      expect(tc.encode(dt, 'double'), equals(str));
    }

    expect(tc.encode(null, 'real'), equals('null'));
  });

  test('encode int', () {
    var tc = new TypeConverter();
    expect(() => tc.encode(double.NAN, 'integer'), throws);
    expect(() => tc.encode(double.INFINITY, 'integer'), throws);
    expect(() => tc.encode(1.0, 'integer'), throws);

    expect(tc.encode(1, 'integer'), equals('1'));
    expect(tc.encode(1, null), equals('1'));

    expect(tc.encode(null, 'integer'), equals('null'));
  });

  test('encode bool', () {
    var tc = new TypeConverter();
    expect(tc.encode(null, 'bool'), equals('null'));
    expect(tc.encode(true, null), equals('true'));
    expect(tc.encode(false, null), equals('false'));
    expect(tc.encode(true, 'bool'), equals('true'));
    expect(tc.encode(false, 'bool'), equals('false'));
  });

  test('encode json', () {
    var tc = new TypeConverter();
    expect(tc.encode({"foo": "bar"}, 'json'), equals(' E\'{"foo":"bar"}\' '));
    expect(tc.encode({"foo": "bar"}, null), equals(' E\'{"foo":"bar"}\' '));
    expect(tc.encode({"fo'o": "ba'r"}, 'json'), equals(' E\'{"fo\\\'o":"ba\\\'r"}\' '));
  });

  //TODO test array
  //TODO test bytea
}