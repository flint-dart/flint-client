// Import and run each example
import './basic_usage.dart' as basic_usage;
import './error_handling.dart' as error_handling;
import './file_operations.dart' as file_operations;
import './caching_examples.dart' as caching_examples;
import './retry_configuration.dart' as retry_configuration;
import './interceptor_usage.dart' as interceptor_usage;
import './advanced_usage.dart' as advanced_usage;

void main() async {
  basic_usage.main();
  error_handling.main();
  file_operations.main();
  caching_examples.main();
  retry_configuration.main();
  interceptor_usage.main();
  advanced_usage.main();
}
