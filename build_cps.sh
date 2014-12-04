# Clone async_await package from https://github.com/dart-lang/async_await
# Copy into a directory at the same level as the postgresql checkout.
# (Or change the export below to point to where you downloaded it to)

export ASYNC_AWAIT=../async_await

dart $ASYNC_AWAIT/bin/async_await.dart lib/src/pool_impl.dart > lib/src/pool_impl_cps.dart
dart $ASYNC_AWAIT/bin/async_await.dart test/postgresql_mock_test.dart > test/postgresql_mock_test_cps.dart
dart $ASYNC_AWAIT/bin/async_await.dart test/postgresql_pool_test.dart > test/postgresql_pool_test_cps.dart

