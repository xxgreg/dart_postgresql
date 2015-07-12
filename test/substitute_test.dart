import 'dart:io';
import 'package:test/test.dart';
import 'package:postgresql/postgresql.dart';
import 'package:postgresql/src/postgresql_impl/postgresql_impl.dart';
import 'package:postgresql/src/substitute.dart';
import 'package:yaml/yaml.dart';

Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  return new Settings.fromMap(map);
}

main() {

  DefaultTypeConverter tc = new TypeConverter();
  
  group('Substitute by id', () {
    test('Substitute 1', () {
      var result = substitute('@id', {'id': 20}, tc.encodeValue);
      expect(result, equals('20'));
    });

    test('Substitute 2', () {
      var result = substitute('@id ', {'id': 20}, tc.encodeValue);
      expect(result, equals('20 '));
    });

    test('Substitute 3', () {
      var result = substitute(' @id ', {'id': 20}, tc.encodeValue);
      expect(result, equals(' 20 '));
    });

    test('Substitute 4', () {
      var result = substitute('@id@bob', {'id': 20, 'bob': 13}, tc.encodeValue);
      expect(result, equals('2013'));
    });

    test('Substitute 5', () {
      var result = substitute('..@id..', {'id': 20}, tc.encodeValue);
      expect(result, equals('..20..'));
    });

    test('Substitute 6', () {
      var result = substitute('...@id...', {'id': 20}, tc.encodeValue);
      expect(result, equals('...20...'));
    });

    test('Substitute 7', () {
      var result = substitute('...@id.@bob...', {'id': 20, 'bob': 13}, tc.encodeValue);
      expect(result, equals('...20.13...'));
    });

    test('Substitute 8', () {
      var result = substitute('...@id@bob', {'id': 20, 'bob': 13}, tc.encodeValue);
      expect(result, equals('...2013'));
    });

    test('Substitute 9', () {
      var result = substitute('@id@bob...', {'id': 20, 'bob': 13}, tc.encodeValue);
      expect(result, equals('2013...'));
    });

    test('Substitute 10', () {
      var result = substitute('@id:text', {'id': 20, 'bob': 13}, tc.encodeValue);
      expect(result, equals(" E'20' "));
    });

    test('Substitute 11', () {
      var result = substitute('@blah_blah', {'blah_blah': 20}, tc.encodeValue);
      expect(result, equals("20"));
    });

    test('Substitute 12', () {
      var result = substitute('@_blah_blah', {'_blah_blah': 20}, tc.encodeValue);
      expect(result, equals("20"));
    });
    
    test('Substitute 13', () {
      var result = substitute('@0 @1', ['foo', 42], tc.encodeValue);
      expect(result, equals(" E'foo'  42"));
    });

//    test('Substitute 13', () {
//      var result = substitute('@apos', {'apos': "'"});
//      //expect(result, equals("E'''"));
//      //print('oi');
//      print(result);
//    });
  });

}