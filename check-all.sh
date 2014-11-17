#!/bin/bash

# Abort if non-zero code returned.
set -e

dartanalyzer lib/postgresql.dart
dartanalyzer test/postgresql_test.dart
# Analyzer is buggy for async code here 
#dartanalyzer test/postgresql_pool_test.dart
dartanalyzer test/substitute_test.dart

# FIXME strange import errors
#dartanalyzer lib/pool.dart

dart --checked test/substitute_test.dart
dart --checked test/settings_test.dart
dart --checked test/postgresql_test.dart

# Segmentation fault core dumped - yikes!
#dart --checked --enable-async test/postgresql_pool_test.dart

# Manually translated with async_await package
dart --checked test/postgresql_pool_test_cps.dart

