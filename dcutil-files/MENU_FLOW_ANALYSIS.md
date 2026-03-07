# Menu Flow Analysis and Test Coverage Assessment

## Overview
This document provides a comprehensive analysis of all menu/interactive flows in dcutil and identifies gaps in current test coverage.

---

## 1. Main Interactive Menu (`show_interactive_menu`)

**Location:** [lib/ux.sh](lib/ux.sh#L168-L273)

### Menu Structure
```
🚀 What would you like to do?
  1) Start my development environment         → up command
  2) Open a shell in my environment          → enter command
  3) Stop my environment                     → down command
  4) Check if my environment is running      → status command
  5) Monitor resource usage (CPU, memory)    → stats command
  6) Set up a new project                    → init command
  7) View logs                               → logs command
  8) Manage shared storage                   → volumes list command
  9) Manage devcontainer features            → features submenu
 10) See all commands                        → help/usage
  0) Exit                                    → exit program
```

### Navigation Flows
- Each option (1-8, 10) executes a command and exits the menu loop
- Option 9 opens a submenu and returns to main menu afterward
- Option 0 exits the program
- Invalid input shows warning and re-displays menu

### Current Test Coverage
**File:** [test-menu/test_menu.expect](test-menu/test_menu.expect)

✅ **Tested:**
- Main menu loading
- Option 1 (up) - message and command initiation
- Option 10 (help) - displays usage and returns to menu
- Option 0 (exit) - exits gracefully

❌ **NOT Tested:**
- **Option 2 (enter)** - Only has basic message check, doesn't verify actual shell opening or error handling
- **Option 3 (down)** - Only basic initiation, no verification of actual container stopping
- **Option 4 (status)** - Only basic initiation, doesn't verify status output
- **Option 5 (stats)** - Only basic initiation, doesn't verify stats display
- **Option 6 (init)** - No flow testing (init is tested separately but not from menu context)
- **Option 7 (logs)** - Only basic initiation, doesn't verify logs display
- **Option 8 (volumes)** - Only basic initiation, doesn't verify volumes list display
- **Option 9 (features)** - Only basic loading check, submenu flows not thoroughly tested
- **Invalid input handling** - Not tested
- **Menu re-display after help** - Minimally tested
- **Transition between menu and command execution** - Not thoroughly tested

---

## 2. Features Management Menu (`show_interactive_feature_management`)

**Location:** [lib/ux.sh](lib/ux.sh#L529-L887)

### Menu Structure (Text Mode)
```
📋 Current features in your configuration:
  [List of current features or "(No features configured)"]

What would you like to do?
  1) Add a feature        → add feature submenu
  2) Remove a feature     → remove feature submenu
  3) View available features → view features submenu
  4) Save changes and exit   → save and return
  5) Exit without saving     → discard and return
```

### Menu Structure (Dialog Mode)
```
Dialog-based menu with same 5 options:
  1) Add a feature
  2) Remove a feature
  3) View/Search available features
  4) Save changes and exit
  5) Exit without saving
```

### Sub-flows

#### 2.1 Add Feature Flow (Text Mode)
1. User selects option 1
2. Prompt: "Enter search term (or press Enter for all features)"
3. Display filtered or all features
4. Prompt: "Enter feature ID to add (or 'back' to return)"
5. Validate feature ID
6. Check if already exists → warning if true
7. Add feature to config
8. Return to features menu

#### 2.2 Add Feature Flow (Dialog Mode)
1. User selects option 1
2. Dialog: "Enter search term (or leave blank for all features)"
3. Display filtered features in dialog menu
4. User selects feature from numbered list
5. Validate selection
6. Check if already exists → msgbox if true
7. Add feature to config
8. Show success msgbox
9. Return to features menu

#### 2.3 Remove Feature Flow (Text Mode)
1. User selects option 2
2. Display numbered list of current features
3. Prompt: "Enter the number of the feature to remove"
4. Validate selection
5. Remove feature from config
6. Return to features menu

#### 2.4 Remove Feature Flow (Dialog Mode)
1. User selects option 2
2. Check if features exist → msgbox if none
3. Display features in dialog menu
4. User selects feature to remove
5. Validate selection
6. Remove feature from config
7. Show success msgbox
8. Return to features menu

#### 2.5 View Features Flow (Text Mode)
1. User selects option 3
2. Loop:
   - Prompt: "Enter search term to filter features (or press Enter for all, 'back' to return)"
   - Display filtered or all features
   - Prompt: "Press Enter to continue viewing or type 'back' to return"
   - Continue or break loop
3. Return to features menu

#### 2.6 View Features Flow (Dialog Mode)
1. User selects option 3
2. Loop:
   - Dialog input: "Enter search term (or leave blank for all features)"
   - Display filtered features in dialog msgbox
   - Loop continues until user cancels
3. Return to features menu

### Current Test Coverage
**Files:**
- [test-menu/test_menu.expect](test-menu/test_menu.expect#L53-L216)
- [test_features_dialog.expect](test_features_dialog.expect)
- [test_features_dialog_mode.expect](test_features_dialog_mode.expect)

✅ **Tested:**
- Features menu loading from main menu (option 9)
- Basic navigation to features menu
- Option 3 (View features) - search with "git" term
- Option 5 (Exit without saving)
- Basic search functionality

❌ **NOT Tested:**
- **Option 1 (Add feature) - Complete flow:**
  - Entering search terms
  - Selecting from filtered results
  - Adding valid feature
  - Handling already-existing feature
  - Handling invalid feature ID
  - "back" navigation
- **Option 2 (Remove feature) - Complete flow:**
  - Displaying current features list
  - Selecting feature by number
  - Confirming removal
  - Handling empty features list
  - Handling invalid selection
- **Option 3 (View features) - Comprehensive testing:**
  - Empty search (all features)
  - Multiple search iterations
  - "back" navigation at different points
  - Pagination/scrolling (if implemented)
- **Option 4 (Save changes and exit):**
  - Verifying changes are persisted
  - Success message display
- **Dialog mode flows:**
  - All dialog-based navigation
  - Dialog cancellation (ESC key)
  - Dialog error handling
- **Edge cases:**
  - No devcontainer config found
  - Invalid JSON in config
  - Network failures when fetching features
  - Concurrent modifications
- **State management:**
  - Refreshing feature list after add/remove
  - Multiple add operations in sequence
  - Multiple remove operations in sequence

---

## 3. Template Selection Menu (Init Wizard)

**Location:** [lib/template_integration.sh](lib/template_integration.sh#L400-L520)

### Menu Structure
```
Available features (select multiple using space-separated numbers):
----------------------------------------
Page 1 of N:
----------------------------------------
 1) Feature Name          - Description
 2) Feature Name          - Description
...
10) Feature Name          - Description

Commands: [n]ext page, [p]revious page, [s]elect items, [q]uit
```

### Navigation Flows
- **n/next**: Move to next page
- **p/prev/previous**: Move to previous page
- **s/select**: Enter selection mode
  - User enters space-separated numbers
  - Validates and accumulates selections
  - Returns to pagination
- **q/quit**: Exit selection

### Current Test Coverage
**File:** [test-wizard-comprehensive/test_wizard_comprehensive.expect](test-wizard-comprehensive/test_wizard_comprehensive.expect)

✅ **Tested:**
- Basic wizard startup
- Welcome screen navigation
- Project type detection
- Template selection (option 1 - use detected)

❌ **NOT Tested:**
- **Feature selection pagination:**
  - Next page navigation
  - Previous page navigation
  - Boundary conditions (first page, last page)
  - Page counter accuracy
- **Feature selection:**
  - Selecting single feature
  - Selecting multiple features
  - Invalid selection handling
  - Empty selection
  - Out-of-range selection
- **Commands:**
  - All page navigation commands
  - Select command
  - Quit command
- **Manual template selection** (option 2)
- **Custom configuration** (option 3)
- **Complete wizard flow end-to-end**

---

## 4. Init Wizard Main Flow

**Location:** [lib/init.sh](lib/init.sh)

### Flow Structure
1. Welcome screen
2. Quick start guide
3. Project type detection
   - Option 1: Use detected template
   - Option 2: Manual selection
   - Option 3: Custom configuration
4. Template configuration
5. Feature selection (via template_integration.sh)
6. Configuration creation
7. Optional: Start environment now

### Current Test Coverage
**File:** [test-wizard-comprehensive/test_wizard_comprehensive.expect](test-wizard-comprehensive/test_wizard_comprehensive.expect)

✅ **Tested:**
- Basic wizard startup
- Welcome → Quick start → Detection → Completion
- Option 1 (detected template) path

❌ **NOT Tested:**
- **Option 2 (manual template selection):**
  - Template browsing
  - Template filtering/search
  - Template details display
  - Template selection confirmation
- **Option 3 (custom configuration):**
  - Custom image input
  - Custom feature selection
  - Custom settings
- **Feature selection during wizard:**
  - See Template Selection Menu gaps above
- **Post-configuration prompts:**
  - "Start environment now" prompt
  - Handling yes/no responses
- **Error scenarios:**
  - Already configured project
  - Network failures
  - Invalid user input
  - Cancelled wizard (Ctrl+C)
- **Complete multi-step flows:**
  - Option 1 → Features → Start
  - Option 2 → Template → Features → Start
  - Option 3 → Custom → Start

---

## 5. Additional Interactive Prompts

### 5.1 Start Environment Prompt (after init)
**Location:** [lib/docker.sh](lib/docker.sh#L1084)

```
Start your environment now? (Y/n):
```

✅ Tested: No
❌ Needs: Test both Y and n responses, default behavior

### 5.2 Create and Start Prompt
**Location:** [lib/docker.sh](lib/docker.sh#L1103)

```
Create and start your environment now? (Y/n):
```

✅ Tested: No
❌ Needs: Test both responses

### 5.3 Project Selection Prompt (template wizard)
**Location:** [lib/template_integration.sh](lib/template_integration.sh#L862)

```
Select option [1]:
```

✅ Tested: No
❌ Needs: Test default selection, explicit selection, invalid input

---

## Test Coverage Summary

### Coverage Matrix

| Menu/Flow | Basic Loading | Navigation | Sub-menus | Error Handling | Edge Cases |
|-----------|--------------|------------|-----------|----------------|------------|
| Main Menu | ✅ | ⚠️ | ❌ | ❌ | ❌ |
| Features Menu (Text) | ✅ | ⚠️ | ❌ | ❌ | ❌ |
| Features Menu (Dialog) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Add Feature Flow | ❌ | ❌ | N/A | ❌ | ❌ |
| Remove Feature Flow | ❌ | ❌ | N/A | ❌ | ❌ |
| View Features Flow | ⚠️ | ❌ | N/A | ❌ | ❌ |
| Template Pagination | ❌ | ❌ | N/A | ❌ | ❌ |
| Init Wizard | ⚠️ | ❌ | ❌ | ❌ | ❌ |
| Post-Init Prompts | ❌ | N/A | N/A | ❌ | ❌ |

**Legend:**
- ✅ Fully tested
- ⚠️ Partially tested
- ❌ Not tested

### Overall Coverage Assessment
- **Main Menu**: ~30% - Basic loading works, minimal flow testing
- **Features Menu**: ~20% - Can enter menu, but no add/remove flow testing
- **Template Selection**: ~10% - Basic wizard tested, no pagination/selection testing
- **Init Wizard**: ~25% - Happy path partially tested, no branching or error testing
- **Prompts**: ~0% - No standalone prompt testing

---

## Critical Test Gaps

### Priority 1 (High Risk)
1. **Features Add/Remove Flows**
   - Users frequently add/remove features
   - Complex validation logic
   - State changes that affect config files
   - Currently untested

2. **Main Menu Command Execution**
   - Each menu option should execute its command correctly
   - Should handle command failures gracefully
   - Return codes and error messages not tested

3. **Dialog Mode Navigation**
   - Completely untested
   - Different code paths than text mode
   - Different error handling

### Priority 2 (Medium Risk)
4. **Template Pagination**
   - Complex state management
   - Boundary conditions
   - User can get stuck or confused

5. **Wizard Branching**
   - Option 2 and 3 paths untested
   - Different configuration outcomes
   - User expectations differ by path

6. **Menu Return/Back Navigation**
   - Features menu should return to main menu
   - Sub-menus should return to parent menu
   - "back" command should work consistently

### Priority 3 (Lower Risk but Important)
7. **Invalid Input Handling**
   - All menus should handle invalid input gracefully
   - Should re-display menu, not crash
   - Error messages should be helpful

8. **Edge Cases**
   - Empty states (no features, no templates)
   - Network failures
   - File permission issues
   - Concurrent operations

9. **Complete End-to-End Flows**
   - Menu → Feature add → Save → Apply changes
   - Menu → Init wizard → Feature selection → Start
   - Multiple operations in sequence

---

## Recommendations

### 1. Comprehensive Menu Test Suite
Create a new test file: `test_menu_comprehensive.expect`

**Should test:**
```
Main Menu:
├── Each option (1-10) execution
├── Invalid input handling
├── Exit (0) functionality
├── Return to menu after help (10)
└── Navigation to features submenu (9) and back

Features Menu:
├── Add Feature Flow
│   ├── Search → Select → Add (valid)
│   ├── Search → Select → Add (duplicate)
│   ├── Search → Invalid ID
│   ├── Empty search (all features)
│   └── "back" navigation
├── Remove Feature Flow
│   ├── Select → Remove (valid)
│   ├── Empty features list
│   ├── Invalid selection
│   └── Cancellation
├── View Features Flow
│   ├── Search → View → Continue
│   ├── Empty search → View all
│   ├── Multiple searches
│   └── "back" at various points
├── Save and Exit (4)
│   └── Verify changes persisted
└── Exit without saving (5)
    └── Verify changes discarded
```

### 2. Dialog Mode Test Suite
Create: `test_dialog_menu_comprehensive.expect`

**Should test:**
- Same flows as text mode
- Dialog-specific interactions (ESC, arrow keys)
- Dialog error handling
- Msgbox confirmations

### 3. Template Selection Test Suite
Create: `test_template_pagination.expect`

**Should test:**
```
Pagination:
├── Next page (n)
├── Previous page (p)
├── First page boundary
├── Last page boundary
├── Page counter accuracy
└── Select (s)
    ├── Valid single selection
    ├── Valid multiple selections
    ├── Invalid selections
    ├── Empty selection
    └── Return to pagination
```

### 4. Wizard Flow Test Suite
Create: `test_wizard_flows.expect`

**Should test:**
```
Path 1: Detected Template
├── Welcome → Guide → Detect → Option 1 → Features → Complete
└── Verify configuration created

Path 2: Manual Selection
├── Welcome → Guide → Detect → Option 2
├── Browse templates
├── Select template
├── Features selection
└── Complete

Path 3: Custom Configuration
├── Welcome → Guide → Detect → Option 3
├── Enter custom details
├── Features selection
└── Complete

Path 4: Post-Init
├── Any path above
├── "Start now?" prompt
├── Test Y response
└── Test n response

Error Paths:
├── Ctrl+C cancellation
├── Invalid inputs at each step
├── Network failures
└── Already configured project
```

### 5. Integration Flow Tests
Create: `test_menu_integration.expect`

**Should test complete user journeys:**
```
Journey 1: New Project Setup
├── Menu (6 - init)
├── Wizard (option 1)
├── Features selection
├── Start (Y)
└── Verify running

Journey 2: Modify Existing
├── Menu (9 - features)
├── Add feature
├── Remove feature
├── Save (4)
├── Menu (1 - up/rebuild)
└── Verify changes applied

Journey 3: Explore and Learn
├── Menu (10 - help)
├── Return to menu
├── Menu (9 - features)
├── View features (3)
├── Exit (5)
└── Menu (0 - exit)
```

### 6. Test Utilities/Helpers
Create shared expect procedures:
```tcl
# test-helpers/menu_helpers.exp
proc navigate_to_features_menu {} { ... }
proc add_feature {feature_id} { ... }
proc remove_feature {feature_num} { ... }
proc expect_menu {menu_type} { ... }
proc handle_error_gracefully {} { ... }
```

---

## Implementation Plan

### Phase 1: Critical Flows (Week 1)
1. Main menu option execution (all 1-10)
2. Features add flow (text mode)
3. Features remove flow (text mode)
4. Menu return navigation

### Phase 2: Complete Features Testing (Week 2)
5. Features view flow (comprehensive)
6. Features save/discard
7. Dialog mode equivalents
8. Error handling

### Phase 3: Wizard Flows (Week 3)
9. Template pagination
10. Wizard option 2 and 3 paths
11. Post-init prompts
12. Wizard error scenarios

### Phase 4: Integration & Edge Cases (Week 4)
13. Complete user journeys
14. Edge case testing
15. Concurrent operation handling
16. Performance testing (long feature lists, etc.)

---

## Success Metrics

**Goal:** 90%+ test coverage of menu flows

**Metrics to track:**
- Number of menu paths tested vs. total paths
- Number of error scenarios tested
- Number of edge cases covered
- Test execution time
- Test flakiness (false positives/negatives)

**Current State:**
- Estimated coverage: ~25%
- Tested paths: ~15 out of ~60 total paths
- Error scenarios: ~2 out of ~30 potential scenarios
- Edge cases: ~0 out of ~20 identified cases

**Target State:**
- Coverage: 90%+
- Tested paths: ~55 out of ~60
- Error scenarios: ~25 out of ~30
- Edge cases: ~18 out of ~20

---

## Notes
- All line numbers and file references current as of analysis date
- Some features may have changed since this analysis
- Dialog mode requires `dialog` package installed for testing
- Wizard tests require mock template/feature data
- Integration tests may require actual container runtime
