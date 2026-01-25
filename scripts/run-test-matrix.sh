#!/bin/bash
#
# run-test-matrix.sh
# Runs iOS simulator tests across all enabled simulators in Config/project.json
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/Config/project.json"

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 is required to parse config"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ xcodebuild is required (install Xcode)"
    exit 1
fi

# Read config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

PROJECT=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['project']['xcode_project'])")
SCHEME=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['project']['schemes']['ios'])")

echo "🧪 FestMest iOS Test Matrix"
echo "==========================="
echo "Project: $PROJECT"
echo "Scheme: $SCHEME"
echo ""

# Get enabled simulators
SIMULATORS=$(python3 -c "
import json
c = json.load(open('$CONFIG_FILE'))
for sim in c['test_matrix']['ios_simulators']:
    if sim.get('enabled', False):
        print(f\"{sim['name']}|{sim.get('os_version', '')}\")
")

if [ -z "$SIMULATORS" ]; then
    echo "❌ No simulators enabled in config"
    exit 1
fi

# Track results
PASSED=0
FAILED=0
FAILED_SIMS=""

# Run tests on each simulator
while IFS='|' read -r SIM_NAME OS_VERSION; do
    echo ""
    echo "📱 Testing on: $SIM_NAME (iOS $OS_VERSION)"
    echo "----------------------------------------"
    
    # Build destination string
    if [ -n "$OS_VERSION" ]; then
        DESTINATION="platform=iOS Simulator,name=$SIM_NAME,OS=$OS_VERSION"
    else
        DESTINATION="platform=iOS Simulator,name=$SIM_NAME"
    fi
    
    # Run tests
    if xcodebuild test \
        -project "$PROJECT_ROOT/$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:bitchatTests \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        -quiet 2>&1; then
        echo "✅ $SIM_NAME: PASSED"
        ((PASSED++))
    else
        echo "❌ $SIM_NAME: FAILED"
        ((FAILED++))
        FAILED_SIMS="$FAILED_SIMS\n  - $SIM_NAME"
    fi
done <<< "$SIMULATORS"

# Summary
echo ""
echo "==========================="
echo "📊 Test Matrix Summary"
echo "==========================="
echo "✅ Passed: $PASSED"
echo "❌ Failed: $FAILED"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Failed simulators:$FAILED_SIMS"
    exit 1
fi

echo ""
echo "🎉 All tests passed!"
