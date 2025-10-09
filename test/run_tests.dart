/// Test runner for Flint HTTP Client
library;

import 'flint_client_test.dart' as client_test;
import 'flint_response_test.dart' as response_test;
import 'flint_error_test.dart' as error_test;
import 'cache/memory_cache_test.dart' as cache_test;
import 'retry/retry_test.dart' as retry_test;
import 'integration_test.dart' as integration_test;

void main() {
  client_test.main();
  response_test.main();
  error_test.main();
  cache_test.main();
  retry_test.main();
  integration_test.main();
}
