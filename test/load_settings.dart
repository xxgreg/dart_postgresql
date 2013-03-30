library postgresql_test;

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:postgresql/settings.dart';

/**
 * Loads configuration from yaml file into [Settings].
 */
Settings loadSettings({String user, String password, String host, int port, String db}){
  var map = loadYaml(new File('test/test_config.yaml').readAsStringSync());
  map[Settings.HOST] = ?host ? host : map[Settings.HOST];
  map[Settings.PORT] = ?port ? port : map[Settings.PORT];
  map[Settings.USER] = ?user ? user : map[Settings.USER];
  map[Settings.PASSWORD] = ?password ? password : map[Settings.PASSWORD];
  map[Settings.DATABASE] = ?db ? db : map[Settings.DATABASE];
  
  return new Settings.fromMap(map);
}