import 'dart:io';
import 'package:test/test.dart';
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
  //FIXME check that timezone offsets match the current system timezone offset.
  // Example strings that postgres may send.
//  "2001-02-03 04:05:06.123-07"
//  "2001-02-03 04:05:06-07"
//  "2001-02-03 04:05:06-07:42"
//  "2001-02-03 04:05:06-07:30:09"
//  "2001-02-03 04:05:06+07"
//  "0010-02-03 04:05:06.123-07 BC"

//  Also consider that some Dart datetimes will not be able to be represented
// in postgresql timestamps. i.e. pre 4713 BC or post 294276 AD. Perhaps just
// send these dates and rely on the database to return an error.


  test('encode datetime', () {
    // Get users current timezone
    var tz = new DateTime(2001, 2, 3).timeZoneOffset;
    var tzoff = "${tz.isNegative ? '-' : '+'}"
      "${tz.inHours.toString().padLeft(2, '0')}"
      ":${(tz.inSeconds % 60).toString().padLeft(2, '0')}";

    var data = [
      "2001-02-03T00:00:00.000$tzoff",      new DateTime(2001, DateTime.FEBRUARY, 3),
      "2001-02-03T04:05:06.000$tzoff",      new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "2001-02-03T04:05:06.999$tzoff",      new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 999),
      "0010-02-03T04:05:06.123$tzoff BC",   new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 123),
      "0010-02-03T04:05:06.000$tzoff BC",   new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "012345-02-03T04:05:06.000$tzoff BC",  new DateTime(-12345, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "012345-02-03T04:05:06.000$tzoff",     new DateTime(12345, DateTime.FEBRUARY, 3, 4, 5, 6, 0)
    ];
    var tc = new TypeConverter();
    for (int i = 0; i < data.length; i += 2) {
      expect(tc.encode(data[i + 1], null), equals("'${data[i]}'"));
    }
  });

  test('encode date', () {
    var data = [
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3),
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "2001-02-03",     new DateTime(2001, DateTime.FEBRUARY, 3, 4, 5, 6, 999),
      "0010-02-03 BC",  new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 123),
      "0010-02-03 BC",  new DateTime(-10, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "012345-02-03 BC", new DateTime(-12345, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
      "012345-02-03",    new DateTime(12345, DateTime.FEBRUARY, 3, 4, 5, 6, 0),
    ];
    var tc = new TypeConverter();
    for (int i = 0; i < data.length; i += 2) {
      var str = data[i];
      var dt = data[i + 1];
      expect(tc.encode(dt, 'date'), equals("'$str'"));
    }
  });

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

  test('0.2 compatability test.', () {
    var tc = new TypeConverter();
    expect(tc.encode(null, null), equals('null'));
    expect(tc.encode(null, 'string'), equals('null'));
    expect(tc.encode(null, 'number'), equals('null'));
    expect(tc.encode(null, 'foo'), equals('null')); // Should this be an error??

    expect(tc.encode(1, null), equals('1'));
    expect(tc.encode(1, 'number'), equals('1'));
    expect(tc.encode(1, 'string'), equals(" E'1' "));
    expect(tc.encode(1, 'String'), equals(" E'1' "));

    expect(tc.encode(new DateTime.utc(1979,12,20,9), 'date'), equals("'1979-12-20'"));
    expect(tc.encode(new DateTime.utc(1979,12,20,9), 'timestamp'), equals("'1979-12-20T09:00:00.000Z'"));
  });

  
  //TODO test array
  //TODO test bytea
}
