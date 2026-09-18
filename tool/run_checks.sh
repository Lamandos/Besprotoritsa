#!/usr/bin/env bash

set -euo pipefail

dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos .
dart test packages/besprotoritsa_rules
dart test packages/besprotoritsa_data
