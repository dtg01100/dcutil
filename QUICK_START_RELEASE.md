# v1.5.0 Release Quick Start

## 🚀 Streamlined Release Process

Since your GitHub Action automatically handles the Homebrew tap update, the release process is simplified:

### ⚡ Super Fast One-Liner (with gh CLI)
```bash
cd /path/to/dcutil && \
git add -A && \
git commit -m "Release v1.5.0: Resource Monitoring & Beginner-Friendly UX" && \
git tag -a v1.5.0 -m "dcutil v1.5.0 - Resource Monitoring & Beginner-Friendly UX" && \
git push origin main && \
git push origin v1.5.0 && \
gh release create v1.5.0 \
  --title "v1.5.0 - Resource Monitoring & Beginner-Friendly UX" \
  --notes-file release_notes.txt \
  --repo dtg01100/dcutil
```
**Done!** Then wait for GitHub Action (~5 min) and test installation.

---

### 📋 Step-by-Step Method (if you prefer)

### Step 1: Commit & Tag (2 minutes)
```bash
cd /var/home/dlafreniere/projects/dcutil

# Commit all changes
git add -A
git commit -m "Release v1.5.0: Resource Monitoring & Beginner-Friendly UX"

# Create and push tag
git tag -a v1.5.0 -m "dcutil v1.5.0 - Resource Monitoring & Beginner-Friendly UX"
git push origin main
git push origin v1.5.0
```

### Step 2: Create GitHub Release (1 minute)

**Option A: Using gh CLI (automatic):**
```bash
gh release create v1.5.0 \
  --title "v1.5.0 - Resource Monitoring & Beginner-Friendly UX" \
  --notes-file release_notes.txt \
  --repo dtg01100/dcutil
```

**Option B: Manual (via web):**
1. Go to: https://github.com/dtg01100/dcutil/releases/new
2. Choose tag: **v1.5.0**
3. Release title: **v1.5.0 - Resource Monitoring & Beginner-Friendly UX**
4. Description: Copy from `release_notes.txt`
5. Click **Publish release**

### Step 3: Wait for GitHub Action (5 minutes)
- GitHub Action automatically:
  - Downloads tarball
  - Calculates SHA256
  - Updates `homebrew-dcutil/Formula/dcutil.rb`
  - Commits changes

- Monitor at: https://github.com/dtg01100/dcutil/actions

### Step 4: Test Installation (2 minutes)
```bash
# Update Homebrew
brew update

# Reinstall dcutil
brew uninstall dcutil 2>/dev/null || true
brew install dtg01100/dcutil/dcutil

# Verify version
dcutil version
# Expected: dcutil v1.5.0

# Test new features
dcutil menu
dcutil stats show
```

---

## ⚡ One-Command Release (Optional)

Or just run the interactive script:
```bash
./release.sh
```

It will guide you through each step!

---

## ✅ Pre-Release Checklist

- [x] All code changes committed
- [x] Version updated to v1.5.0 in all files
- [x] CHANGELOG.md updated
- [x] release_notes.txt ready
- [x] README.md updated
- [x] Shell completions updated
- [x] Syntax validated
- [x] Homebrew formula version updated

---

**Total Time**: ~12 minutes
**Automation**: GitHub Action handles Homebrew tap update automatically
**Status**: Ready to release! 🎉
