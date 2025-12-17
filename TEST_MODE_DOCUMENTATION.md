# Test Mode Documentation

This document describes the comprehensive test suite for both text and dialog modes in dcutil.

## Overview

The dcutil project now includes comprehensive tests for both text and dialog modes to ensure consistent functionality across different user interface preferences.

## Test Structure

### Directory Structure
```
dcutil/
├── test-text-mode/           # Text mode specific tests
│   ├── test_menu_text.expect
│   └── test_wizard_text.expect
├── test-dialog-mode/         # Dialog mode specific tests
│   ├── test_menu_dialog.expect
│   └── test_wizard_dialog.expect
├── run_mode_tests.sh         # Test runner script
└── test-menu/                # Existing menu tests
    └── test_menu_comprehensive.expect
```

## Test Modes

### Text Mode Tests
- **Location**: `test-text-mode/`
- **Environment**: `DCUTIL_DISABLE_DIALOG=1`
- **Purpose**: Tests functionality when dialog is disabled
- **Tests Included**:
  - `test_menu_text.expect` - Menu navigation and features
  - `test_wizard_text.expect` - Wizard initialization flow

### Dialog Mode Tests
- **Location**: `test-dialog-mode/`
- **Environment**: Dialog enabled (default)
- **Purpose**: Tests functionality with dialog interface
- **Tests Included**:
  - `test_menu_dialog.expect` - Menu navigation and features
  - `test_wizard_dialog.expect` - Wizard initialization flow

## Running Tests

### Run All Tests
```bash
./run_mode_tests.sh
```

### Run Specific Mode
```bash
# Text mode only
./run_mode_tests.sh ./dcutil text

# Dialog mode only
./run_mode_tests.sh ./dcutil dialog
```

### Run with Custom dcutil Path
```bash
./run_mode_tests.sh /usr/local/bin/dcutil both
```

## Test Coverage

### Menu Tests
- Main menu loading
- Help option functionality
- Exit option functionality
- Feature management
  - View features
  - Add/remove features
  - Save/exit options

### Wizard Tests
- Wizard initialization
- Project type detection
- Feature selection
- Advanced configuration
- Template application

## Environment Variables

### Text Mode
- `DCUTIL_DISABLE_DIALOG=1` - Disables dialog interface

### Dialog Mode
- No special environment variables required (default behavior)

### Test Environment
- `CI=1` - Enables CI mode for consistent behavior
- `HOME=/tmp/dcutil_test.XXXXXX` - Isolated test environment

## Expected Behavior

### Text Mode
- All prompts use standard text input
- No dialog boxes or interactive menus
- Suitable for CI/CD environments
- Faster execution

### Dialog Mode
- Uses dialog library for interactive menus
- Visual confirmation dialogs
- Better user experience for interactive use
- May require terminal capabilities

## Troubleshooting

### Common Issues

1. **Dialog not working**
   - Ensure dialog package is installed: `sudo apt-get install dialog`
   - Check terminal capabilities

2. **Expect script timeouts**
   - Increase timeout values in test files
   - Check if dcutil is responding properly

3. **Environment variables not set**
   - Verify `DCUTIL_DISABLE_DIALOG` is properly exported
   - Check test script environment setup

### Debug Mode
Run tests with verbose output:
```bash
DCUTIL_DEBUG=1 ./run_mode_tests.sh ./dcutil text
```

## Integration with Existing Tests

The new mode-specific tests complement the existing comprehensive test suite:
- `test-menu/test_menu_comprehensive.expect` - General menu testing
- `test-wizard-comprehensive/` - Wizard testing
- `run_comprehensive_tests.sh` - Full test suite

## Future Enhancements

1. **Additional Test Scenarios**
   - Error handling tests
   - Edge case testing
   - Performance testing

2. **Test Automation**
   - GitHub Actions integration
   - Automated test reporting
   - Continuous testing pipeline

3. **Test Coverage Expansion**
   - More wizard scenarios
   - Advanced feature combinations
   - Cross-platform testing