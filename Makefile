# Festivus Mestivus / bitchat Makefile
# Wraps common development commands for local use and CI

.PHONY: all build test test-parallel lint format check clean help

# Default target
all: check build test

# ============================================================================
# Build Commands
# ============================================================================

## Build the Swift package
build:
	@echo "🔨 Building Swift package..."
	swift build

## Build for release
build-release:
	@echo "🔨 Building release..."
	swift build -c release

## Build iOS app (requires Xcode)
build-ios:
	@echo "📱 Building iOS app..."
	xcodebuild -project bitchat.xcodeproj \
		-scheme "bitchat (iOS)" \
		-destination "generic/platform=iOS" \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		build

## Build macOS app (requires Xcode)
build-macos:
	@echo "🖥️  Building macOS app..."
	xcodebuild -project bitchat.xcodeproj \
		-scheme "bitchat (macOS)" \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_ENTITLEMENTS="" \
		build

# ============================================================================
# Test Commands
# ============================================================================

## Run all tests
test:
	@echo "🧪 Running tests..."
	swift test

## Run tests in parallel
test-parallel:
	@echo "🧪 Running tests in parallel..."
	swift test --parallel

## Run tests with verbose output
test-verbose:
	@echo "🧪 Running tests (verbose)..."
	swift test --verbose

## Run specific test file (usage: make test-file FILE=FestivalGroupTests)
test-file:
	@echo "🧪 Running tests matching: $(FILE)..."
	swift test --filter $(FILE)

## Run festival group tests only
test-groups:
	@echo "🧪 Running festival group tests..."
	swift test --filter FestivalGroup

## Run festival feature tests only
test-festival:
	@echo "🧪 Running festival feature tests..."
	swift test --filter Festival

## Run tests with code coverage (requires Xcode)
test-coverage:
	@echo "🧪 Running tests with coverage..."
	xcodebuild test \
		-project bitchat.xcodeproj \
		-scheme "bitchat (iOS)" \
		-destination "platform=iOS Simulator,name=iPhone 15" \
		-enableCodeCoverage YES \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO

# ============================================================================
# Code Quality Commands
# ============================================================================

## Run SwiftLint (if installed)
lint:
	@echo "🔍 Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet; \
	else \
		echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"; \
		exit 0; \
	fi

## Run SwiftLint and auto-fix issues
lint-fix:
	@echo "🔧 Running SwiftLint with auto-fix..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --fix --quiet; \
	else \
		echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

## Format code with swift-format (if installed)
format:
	@echo "✨ Formatting code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		find bitchat bitchatTests -name "*.swift" -exec swift-format -i {} \;; \
	else \
		echo "⚠️  swift-format not installed. Install with: brew install swift-format"; \
		exit 0; \
	fi

## Check formatting without modifying files
format-check:
	@echo "🔍 Checking code formatting..."
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format lint -r bitchat bitchatTests; \
	else \
		echo "⚠️  swift-format not installed. Install with: brew install swift-format"; \
		exit 0; \
	fi

# ============================================================================
# Pre-commit / CI Checks
# ============================================================================

## Run all checks (build + test + lint)
check: build test lint
	@echo "✅ All checks passed!"

## Quick check (build + fast tests only)
check-quick: build
	@echo "🧪 Running quick tests..."
	swift test --filter "ModelTests|IdTests|SignableDataTests"
	@echo "✅ Quick checks passed!"

## CI check (what runs in GitHub Actions)
ci: 
	@echo "🤖 Running CI checks..."
	@echo "Step 1/3: Building..."
	swift build
	@echo "Step 2/3: Running tests..."
	swift test --parallel
	@echo "Step 3/3: Linting..."
	@$(MAKE) lint || true
	@echo "✅ CI checks complete!"

# ============================================================================
# Utility Commands
# ============================================================================

## Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	swift package clean
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/bitchat-* 2>/dev/null || true

## Deep clean including Xcode derived data
clean-all: clean
	@echo "🧹 Deep cleaning..."
	rm -rf ~/Library/Developer/Xcode/DerivedData/*

## Show package dependencies
deps:
	@echo "📦 Package dependencies:"
	swift package show-dependencies

## Update package dependencies
deps-update:
	@echo "📦 Updating dependencies..."
	swift package update

## Generate Xcode project (if using SPM)
generate-xcodeproj:
	@echo "🔧 Generating Xcode project..."
	swift package generate-xcodeproj

# ============================================================================
# Development Helpers
# ============================================================================

## Run the macOS app (builds first)
run: build-macos
	@echo "🚀 Launching app..."
	@find ~/Library/Developer/Xcode/DerivedData -name "bitchat.app" -path "*/Debug/*" -not -path "*/Index.noindex/*" | head -1 | xargs -I {} open "{}"

## Watch for changes and run tests (requires fswatch)
watch:
	@echo "👀 Watching for changes..."
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o bitchat bitchatTests | xargs -n1 -I{} make test; \
	else \
		echo "⚠️  fswatch not installed. Install with: brew install fswatch"; \
	fi

## Open project in Xcode
xcode:
	@echo "🔵 Opening in Xcode..."
	open bitchat.xcodeproj

# ============================================================================
# Help
# ============================================================================

## Show this help
help:
	@echo "Festivus Mestivus / bitchat Development Commands"
	@echo "================================================"
	@echo ""
	@echo "Build:"
	@echo "  make build          - Build Swift package"
	@echo "  make build-release  - Build for release"
	@echo "  make build-ios      - Build iOS app"
	@echo "  make build-macos    - Build macOS app"
	@echo ""
	@echo "Test:"
	@echo "  make test           - Run all tests"
	@echo "  make test-parallel  - Run tests in parallel"
	@echo "  make test-groups    - Run festival group tests"
	@echo "  make test-festival  - Run all festival tests"
	@echo "  make test-coverage  - Run tests with coverage"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run SwiftLint"
	@echo "  make lint-fix       - Auto-fix lint issues"
	@echo "  make format         - Format code"
	@echo "  make format-check   - Check formatting"
	@echo ""
	@echo "CI/Checks:"
	@echo "  make check          - Run all checks"
	@echo "  make check-quick    - Quick sanity check"
	@echo "  make ci             - Full CI pipeline"
	@echo ""
	@echo "Utility:"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make clean-all      - Deep clean"
	@echo "  make deps           - Show dependencies"
	@echo "  make run            - Build and run macOS app"
	@echo "  make xcode          - Open in Xcode"
	@echo ""
