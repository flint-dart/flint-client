/// Test runner for Flint HTTP Client
library;

import 'flint_client_test.dart' as client_test;
import 'flint_response_test.dart' as response_test;
import 'flint_error_test.dart' as error_test;
import 'cache/memory_cache_test.dart' as cache_test;
import 'retry/retry_test.dart' as retry_test;
import 'integration_test.dart' as integration_test;
import 'request/body_serializer_test.dart' as body_serializer_test;
import 'request/cancel_token_test.dart' as cancel_token_test;
import 'request/request_options_test.dart' as request_options_test;
import 'websocket/flint_web_socket_client_test.dart' as websocket_client_test;

void main() {
  client_test.main();
  response_test.main();
  error_test.main();
  cache_test.main();
  retry_test.main();
  integration_test.main();
  body_serializer_test.main();
  cancel_token_test.main();
  request_options_test.main();
  websocket_client_test.main();
}
