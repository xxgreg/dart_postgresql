library postgresql_test;

import 'dart:io';
import 'package:postgresql/postgresql.dart';
import 'package:unittest/unittest.dart';
import 'package:yaml/yaml.dart';

Settings loadSettings(){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync()); 
  return new Settings.fromMap(map);
}

main() {
	
	test('Test missing user setting', () {
    var map = new Map();
    map[Settings.HOST] = "dummy";
    map[Settings.PASSWORD] = "dummy";
    map[Settings.DATABASE] = "dummy";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is FormatException)));
  });
	
	test('Test missing password setting', () {
    var map = new Map();
    map[Settings.HOST] = "dummy";
    map[Settings.USER] = "dummy";
    map[Settings.DATABASE] = "dummy";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is FormatException)));
  });
	
	test('Test missing database setting', () {
    var map = new Map();
    map[Settings.HOST] = "dummy";
    map[Settings.USER] = "dummy";
    map[Settings.PASSWORD] = "dummy";
    expect(() => new Settings.fromMap(map),
        throwsA(predicate((e) => e is FormatException)));
  });
	
	test('Valid settings', () {
    var map = new Map();
    map[Settings.HOST] = "dummy";
    map[Settings.USER] = "dummy";
    map[Settings.PASSWORD] = "dummy";
    map[Settings.DATABASE] = "dummy";
    expect(new Settings.fromMap(map).toUri(), 'postgres://dummy:dummy@dummy:5432/dummy');
  });
	
	test('Valid settings different port', () {
    var map = new Map();
    map[Settings.HOST] = "dummy";
    map[Settings.PORT] = 5433;
    map[Settings.USER] = "dummy";
    map[Settings.PASSWORD] = "dummy";
    map[Settings.DATABASE] = "dummy";
    expect(new Settings.fromMap(map).toUri(), 'postgres://dummy:dummy@dummy:5433/dummy');
  });
    
	test('Load settings from yaml file', () {
	  Settings s = loadSettings();
	});
}