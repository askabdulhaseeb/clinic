#!/usr/bin/env sh
# Runs integration_test/ on Chrome (via ChromeDriver + the web-server device)
# against the local Emulator Suite.
#
#   tool/integration_test_web.sh              # headless Chrome
#   tool/integration_test_web.sh --no-headless
#
# Downloads a ChromeDriver matching stable Chrome into .dart_tool (ignored by
# git) on first use, starts it on port 4444, seeds the emulators and runs the
# tests. Never touches the live Firebase project.
set -eu
cd "$(dirname "$0")/.."

DRIVER_DIR=.dart_tool/chromedriver
CHROMEDRIVER=$(find "$DRIVER_DIR" -type f -name chromedriver 2>/dev/null | head -n 1 || true)
if [ -z "$CHROMEDRIVER" ]; then
  echo "Downloading ChromeDriver (stable) into $DRIVER_DIR ..."
  npx -y @puppeteer/browsers install chromedriver@stable --path "$DRIVER_DIR" >/dev/null
  CHROMEDRIVER=$(find "$DRIVER_DIR" -type f -name chromedriver | head -n 1)
fi

# The emulator serves the compiled JS, so build the functions first.
npm --prefix functions run build >/dev/null

"$CHROMEDRIVER" --port=4444 >/dev/null 2>&1 &
DRIVER_PID=$!
trap 'kill $DRIVER_PID 2>/dev/null || true' EXIT INT TERM
sleep 1

# Every *_test.dart in name order inside one emulator session, so the Phase 2
# setup flow (admin_setup_flow_test.dart) runs before the login flow and
# the seed's missing settings/general is only created once.
TARGETS=$(ls integration_test/*_test.dart | sort | tr '\n' ' ')
RUN=""
for t in $TARGETS; do
  RUN="$RUN flutter drive --driver=test_driver/integration_test.dart --target=$t -d web-server --browser-dimension=1280x800 --dart-define=USE_EMULATORS=true $* &&"
done
RUN="${RUN% &&}"

firebase emulators:exec --only auth,firestore,functions,storage \
  "node functions/scripts/seed-emulator.js && $RUN"
