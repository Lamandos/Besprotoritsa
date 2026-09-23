#!/usr/bin/env bash

set -euo pipefail

dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos .
dart run tool/validate_schemas.dart
dart run tool/validate_content.dart
dart run tool/verify_batch.dart --deck items
dart run tool/verify_batch.dart --deck supplies
dart run tool/verify_batch.dart --deck events
dart run tool/verify_batch.dart --deck special-items
dart run tool/validate_batch.dart --deck monsters --all
dart test packages/besprotoritsa_rules
dart test packages/besprotoritsa_data
dart test packages/besprotoritsa_server
(
  cd packages/besprotoritsa_app
  flutter test
  flutter test \
    test/victory_scenario_test.dart \
    test/defeat_scenario_test.dart \
    test/save_resume_scenario_test.dart
)
