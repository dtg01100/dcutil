# Release Checklist for dcutil v1.5.0

## 📋 Pre-Release Verification

### ✅ Code Changes Complete
- [x] Resource monitoring (`lib/monitoring.sh` - NEW)
- [x] UX enhancements (`lib/ux.sh` - NEW)
- [x] Beginner-friendly language (9 core files updated)
- [x] Interactive menu mode
- [x] Smart command suggestions
- [x] Contextual tips (10 integration points)
- [x] Time expectation messages
- [x] Shell completions updated (bash, zsh, fish)
- [x] Bash completion function names standardized
- [x] Documentation updated (README, CHANGELOG, release_notes)

### ✅ Files Modified (18 total)
**Modified:**
1. CHANGELOG.md
2. README.md
3. completion.bash
4. completion.fish
5. completion.zsh
6. dcutil (main script)
7. dcutil.rb (Homebrew formula)
8. lib/api_official_cli.sh
9. lib/core.sh
10. lib/docker.sh
11. lib/features.sh
12. lib/init.sh
13. lib/shutdown.sh
14. lib/template_integration.sh
15. lib/volumes.sh
16. release_notes.txt

**New Files:**
17. lib/monitoring.sh (720 lines)
18. lib/ux.sh (386 lines)

### ✅ Testing Complete
- [x] Bash syntax validation (all files pass)
- [x] Bash completion sources correctly
- [x] Function names consistent across completion files
- [x] Main script syntax validated

## 🚀 Release Steps

### 1. Commit All Changes
```bash
cd /path/to/dcutil

# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "Release v1.5.0: Resource Monitoring & Beginner-Friendly UX

Major Features:
- Resource monitoring with 'dcutil stats' command (4 subcommands)
- Complete beginner-friendly language redesign
- Interactive menu mode and smart command suggestions
- Contextual tips integrated throughout (10 locations)
- First-run welcome experience
- Enhanced shell completions for bash/zsh/fish

New Files:
- lib/monitoring.sh (720 lines) - Resource monitoring system
- lib/ux.sh (386 lines) - UX enhancement framework

Updated 16 files with beginner-friendly improvements
See CHANGELOG.md and release_notes.txt for full details"
```

### 2. Create Git Tag
```bash
# Create annotated tag
git tag -a v1.5.0 -m "dcutil v1.5.0 - Resource Monitoring & Beginner-Friendly UX"

# Push commits and tags
git push origin main
git push origin v1.5.0
```

### 3. Create GitHub Release
1. Go to https://github.com/dtg01100/dcutil/releases/new
2. Choose tag: `v1.5.0`
3. Release title: `v1.5.0 - Resource Monitoring & Beginner-Friendly UX`
4. Description: Copy from `release_notes.txt`
5. Attach files (optional):
   - dcutil (main script)
   - completion files
6. Publish release

### 4. Wait for GitHub Action to Update Homebrew Tap
```bash
# After publishing the GitHub release, a GitHub Action will automatically:
# 1. Download the v1.5.0 tarball
# 2. Calculate the SHA256 checksum
# 3. Update Formula/dcutil.rb in the homebrew-dcutil repository
# 4. Commit and push the changes

# Monitor the action at:
# https://github.com/dtg01100/dcutil/actions

# The action will replace "PLACEHOLDER_SHA256_UPDATE_AFTER_RELEASE" with the actual hash
```

### 5. Test Installation
```bash
# Uninstall old version
brew uninstall dcutil

# Update tap
brew update

# Install new version
brew install dtg01100/dcutil/dcutil

# Verify version
dcutil version
# Should show: dcutil v1.5.0

# Test new features
dcutil menu
dcutil stats show
dcutil stauts  # Should suggest "Did you mean: dcutil status"
```

### 6. Test Bash Completion
```bash
# Ensure bash-completion is installed
brew list bash-completion || brew install bash-completion

# Add to ~/.bashrc if not already present:
[[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"

# Restart shell or source bashrc
source ~/.bashrc

# Test completion
dcutil <TAB><TAB>
# Should show: up down restart enter build clean status stats logs list run init...

dcutil stats <TAB><TAB>
# Should show: show watch detailed top help
```

## 📝 Post-Release Tasks

### Update Documentation
- [ ] Update main README if needed
- [ ] Add v1.5.0 to release history
- [ ] Update any screenshots or demos

### Announce Release
- [ ] GitHub Discussions (if enabled)
- [ ] Social media/blog (if applicable)
- [ ] Update project status badges

### Monitor Feedback
- [ ] Watch for GitHub issues
- [ ] Monitor installation problems
- [ ] Collect user feedback on new UX features

## 🎯 Version Numbers to Update (if needed elsewhere)

Current version: **v1.5.0**
- [x] `dcutil` line 6: `VERSION="v1.5.0"`
- [x] `dcutil.rb` line 7: `url "...v1.5.0.tar.gz"`
- [x] `CHANGELOG.md` line 3: `## [1.5.0] - 2025-11-25`

## 📊 Release Statistics

- **Lines of Code Added**: ~1,106+ (monitoring.sh + ux.sh)
- **Files Modified**: 16
- **New Files**: 2
- **Integration Points**: 10 contextual tips
- **Shell Completions Updated**: 3 (bash, zsh, fish)
- **Documentation Files Updated**: 3 (README, CHANGELOG, release_notes)

## ✨ Key Features Summary

1. **Resource Monitoring**: `dcutil stats` with 4 modes (show, watch, detailed, top)
2. **Interactive Menu**: `dcutil` (no args) shows 9 common tasks
3. **Smart Suggestions**: Typo detection with Levenshtein distance
4. **First-Run Welcome**: One-time quick start guide
5. **Contextual Tips**: State-based guidance after commands
6. **Time Expectations**: Clear messages for long operations
7. **Beginner-Friendly**: Zero Docker knowledge required

---

**Release Date**: November 25, 2025
**Release Manager**: GitHub Copilot + dtg01100
**Status**: Ready for Release ✅
