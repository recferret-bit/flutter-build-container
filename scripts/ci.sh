#!/usr/bin/env bash
# =============================================================================
# ci.sh — Flutter CI/CD pipeline entrypoint
# =============================================================================
# Runs inside the flutter-ci container. Can be used standalone or as the
# entrypoint for cloud CI/CD services.
#
# Usage:
#   docker run --rm -v /path/to/project:/app flutter-ci ./scripts/ci.sh
#
# Environment variables:
#   SKIP_CODEGEN   — set to "true" to skip build_runner code generation
#   SKIP_FORMAT    — set to "true" to skip dart format check
#   SKIP_TESTS     — set to "true" to skip unit/widget tests
#   SKIP_ANALYZE   — set to "true" to skip flutter analyze
# =============================================================================
set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▸ $1${NC}\n"; }
pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ---- Environment info -------------------------------------------------------
step "Environment"
flutter --version
dart --version

# ---- Dependencies ------------------------------------------------------------
step "Installing dependencies"
flutter pub get
pass "Dependencies resolved"

# ---- Code generation ---------------------------------------------------------
if [ "${SKIP_CODEGEN:-false}" != "true" ]; then
  step "Running build_runner (code generation)"
  dart run build_runner build --delete-conflicting-outputs
  pass "Code generation complete"
fi

# ---- Static analysis ---------------------------------------------------------
if [ "${SKIP_ANALYZE:-false}" != "true" ]; then
  step "Running static analysis"
  flutter analyze --no-fatal-infos || fail "Static analysis failed"
  pass "Static analysis passed"
fi

# ---- Format check ------------------------------------------------------------
if [ "${SKIP_FORMAT:-false}" != "true" ]; then
  step "Checking code formatting"
  dart format --set-exit-if-changed . || fail "Code formatting check failed"
  pass "Code formatting OK"
fi

# ---- Tests -------------------------------------------------------------------
if [ "${SKIP_TESTS:-false}" != "true" ]; then
  step "Running unit & widget tests"
  flutter test --coverage --reporter=expanded || fail "Tests failed"
  pass "All tests passed"
fi

# ---- Done --------------------------------------------------------------------
echo ""
pass "CI pipeline completed successfully"
