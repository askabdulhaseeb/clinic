// Driver entry for running `integration_test/` on Chrome:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/login_flow_test.dart -d chrome
// Needs a ChromeDriver on port 4444; `tool/integration_test_web.sh` does both.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
