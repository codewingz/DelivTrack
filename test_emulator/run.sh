#!/bin/sh
# Runs the emulator-backed repository tests on a running Android emulator.
# Usage:  firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
#           "sh test_emulator/run.sh <android-emulator-id>"
# (`flutter drive` is used because device tests with Firebase plugins can only be launched through the
# integration_test driver; the files live here instead of in an integration_test/ folder.)
set -e
device="${1:?usage: run.sh <android-emulator-id>}"
for name in auth parcels customers products; do
  flutter drive --no-pub --driver=test_emulator/driver.dart --target="test_emulator/${name}_repository_test.dart" -d "$device"
done
