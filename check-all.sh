#!/bin/bash

# Abort if non-zero code returned.
set -e

dart_analyzer --type-checks-for-inferred-types lib/postgresql.dart
dart_analyzer --type-checks-for-inferred-types lib/postgresql_pool.dart
dart_analyzer --type-checks-for-inferred-types test/postgresql_test.dart
dart_analyzer --type-checks-for-inferred-types test/postgresql_pool_test.dart
dart_analyzer --type-checks-for-inferred-types test/substitute_test.dart

dart --checked test/settings_test.dart
dart --checked test/postgresql_test.dart
dart --checked test/postgresql_pool_test.dart
dart --checked test/substitute_test.dart