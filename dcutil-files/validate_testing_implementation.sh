#!/bin/bash

# Quick validation of the testing implementation
# Verifies all components are in place

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔍 Validating Testing Implementation..."
echo ""

ISSUES=0

# Check files exist
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
    else
        echo -e "${RED}✗${NC} $1 MISSING"
        ISSUES=$((ISSUES + 1))
    fi
}

# Check files are executable
check_executable() {
    if [ -x "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 is executable"
    else
        echo -e "${RED}✗${NC} $1 is NOT executable"
        ISSUES=$((ISSUES + 1))
    fi
}

echo "📁 Checking test files..."
check_file "test-menu/test_menu_comprehensive.expect"
check_file "test-wizard-comprehensive/test_wizard_reliable.expect"
check_file "run_comprehensive_tests.sh"
check_file "TESTING_IMPLEMENTATION.md"

echo ""
echo "🔑 Checking permissions..."
check_executable "test-menu/test_menu_comprehensive.expect"
check_executable "test-wizard-comprehensive/test_wizard_reliable.expect"
check_executable "run_comprehensive_tests.sh"

echo ""
echo "📊 Checking test structure..."

# Count test procedures
MENU_TESTS=$(grep -c "^proc test_" test-menu/test_menu_comprehensive.expect || true)
WIZARD_TESTS=$(grep -c "^proc test_" test-wizard-comprehensive/test_wizard_reliable.expect || true)

echo "  Menu test procedures: $MENU_TESTS"
echo "  Wizard test procedures: $WIZARD_TESTS"

if [ "$MENU_TESTS" -ge 4 ]; then
    echo -e "${GREEN}✓${NC} Menu tests comprehensive (${MENU_TESTS} procedures)"
else
    echo -e "${RED}✗${NC} Menu tests may be incomplete (${MENU_TESTS} procedures)"
    ISSUES=$((ISSUES + 1))
fi

if [ "$WIZARD_TESTS" -ge 4 ]; then
    echo -e "${GREEN}✓${NC} Wizard tests comprehensive (${WIZARD_TESTS} procedures)"
else
    echo -e "${RED}✗${NC} Wizard tests may be incomplete (${WIZARD_TESTS} procedures)"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "🔧 Checking for key fixes..."

# Check for fixed wait patterns
FIXED_WAITS=$(grep -c "expect \"Press Enter to continue\"" test-menu/test_menu_comprehensive.expect || true)
if [ "$FIXED_WAITS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Fixed input wait patterns found ($FIXED_WAITS instances)"
else
    echo -e "${RED}✗${NC} Missing input wait patterns"
    ISSUES=$((ISSUES + 1))
fi

# Check for complete flow testing
COMPLETE_FLOWS=$(grep -c "complete.*flow" test-menu/test_menu_comprehensive.expect || true)
if [ "$COMPLETE_FLOWS" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Complete flow testing implemented"
else
    echo -e "${RED}✗${NC} Complete flow testing may be missing"
    ISSUES=$((ISSUES + 1))
fi

# Check for risk prioritization
RISK_COMMENTS=$(grep -h "HIGH RISK\|MEDIUM RISK\|LOW RISK" test-menu/test_menu_comprehensive.expect test-wizard-comprehensive/test_wizard_reliable.expect 2>/dev/null | wc -l || echo "0")
if [ "$RISK_COMMENTS" -gt 5 ]; then
    echo -e "${GREEN}✓${NC} Risk-based prioritization implemented ($RISK_COMMENTS markers)"
else
    echo -e "${RED}✗${NC} Risk prioritization may be incomplete ($RISK_COMMENTS markers)"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "========================================"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All validation checks PASSED${NC}"
    echo "========================================"
    echo ""
    echo "Ready to run: ./run_comprehensive_tests.sh"
    exit 0
else
    echo -e "${RED}⚠️  $ISSUES validation issues found${NC}"
    echo "========================================"
    exit 1
fi
