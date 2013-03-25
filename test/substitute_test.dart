library postgresql;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:postgresql/postgresql.dart';

main() {
  var uri = 'postgres://testdb:password@localhost:5432/testdb';  
  
  group('Substitute by id', () {
    test('Substitute 1', () {
      var result = substitute('@id', {'id': 20});
      expect(result, equals('20'));
    });
    
    test('Substitute 2', () {  
      var result = substitute('@id ', {'id': 20});
      expect(result, equals('20 '));
    });
    
    test('Substitute 3', () {    
      var result = substitute(' @id ', {'id': 20});
      expect(result, equals(' 20 '));
    });
    
    test('Substitute 4', () {    
      var result = substitute('@id@bob', {'id': 20, 'bob': 13});
      expect(result, equals('2013'));
    });
    
    test('Substitute 5', () {    
      var result = substitute('..@id..', {'id': 20});
      expect(result, equals('..20..'));
    });
    
    test('Substitute 6', () {    
      var result = substitute('...@id...', {'id': 20});
      expect(result, equals('...20...'));
    });
    
    test('Substitute 7', () {    
      var result = substitute('...@id.@bob...', {'id': 20, 'bob': 13});
      expect(result, equals('...20.13...'));
    });
    
    test('Substitute 8', () {    
      var result = substitute('...@id@bob', {'id': 20, 'bob': 13});
      expect(result, equals('...2013'));
    });
    
    test('Substitute 9', () { 
      var result = substitute('@id@bob...', {'id': 20, 'bob': 13});
      expect(result, equals('2013...'));
    });
    
    test('Substitute 10', () { 
      var result = substitute('@id:string', {'id': 20, 'bob': 13});
      expect(result, equals("'20'"));
    });
    
  });
  
  
  test('Format value', () {
    expect(formatValue('bob', null), equals(" E'bob' "));
    expect(formatValue('bo\nb', null), equals(r" E'bo\nb' "));
    expect(formatValue('bo\rb', null), equals(r" E'bo\rb' "));
    expect(formatValue(r'bo\b', null), equals(r" E'bo\\b' "));
  });
  
  
  group('Query', () {
    
    Connection conn;
    
    setUp(() {
      return connect(uri).then((c) => conn = c);
    });
    
    tearDown(() {
      if (conn != null) conn.close();
    });
  
    solo_test('Substitution', () {
      conn.query(
          'select @num, @num:string, @num:number, '
          '@int, @int:string, @int:number, '
          '@string, '
          '@datetime, @datetime:date, @datetime:timestamp ',
          { 'num': 1.2, 
            'int': 3,
            'string': 'bob\njim',
            'datetime': new DateTime(2013, 1, 1)
          }).toList()
            .then(expectAsync1((rows) {}));
    });
    
  });
  
}



