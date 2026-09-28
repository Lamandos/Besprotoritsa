import 'package:integration_test/integration_test.dart';

import 'defeat_e2e_scenario.dart' as defeat;
import 'save_resume_e2e_scenario.dart' as save_resume;
import 'victory_e2e_scenario.dart' as victory;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  victory.main();
  defeat.main();
  save_resume.main();
}
