#!/bin/bash
# Dynamic Release Script for dcutil
# Automatically detects version from dcutil script

set -e  # Exit on error

# Change to dcutil-files directory
cd "$(dirname "$0")"

# Extract version from dcutil script
VERSION=$(grep '^VERSION=' dcutil | cut -d'"' -f2)

if [ -z "$VERSION" ]; then
    echo "❌ Error: Could not extract version from dcutil script"
    exit 1
fi

echo "🚀 dcutil $VERSION Release Script"
echo "================================"
echo "Detected version: $VERSION"
echo ""
echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Show git status
echo "📋 Step 1: Checking git status..."
git status --short
echo ""

# Step 2: Stage and commit all changes
echo "💾 Step 2: Committing all changes..."
read -p "Commit changes? (y/N): " commit_choice
if [[ "$commit_choice" =~ ^[Yy]$ ]]; then
    git add -A
    git commit -m "Release $VERSION: Resource Monitoring & Beginner-Friendly UX

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
    echo "✅ Changes committed"
else
    echo "⏭️  Skipping commit"
fi
echo ""

# Step 3: Create tag
echo "🏷️  Step 3: Creating git tag $VERSION..."
read -p "Create tag? (y/N): " tag_choice
if [[ "$tag_choice" =~ ^[Yy]$ ]]; then
    git tag -a "$VERSION" -m "dcutil $VERSION - Resource Monitoring & Beginner-Friendly UX"
    echo "✅ Tag created"
else
    echo "⏭️  Skipping tag creation"
fi
echo ""

# Step 4: Push to remote
echo "📤 Step 4: Pushing to remote..."
read -p "Push commits and tags? (y/N): " push_choice
if [[ "$push_choice" =~ ^[Yy]$ ]]; then
    git push origin main
    git push origin "$VERSION"
    echo "✅ Pushed to remote"
else
    echo "⏭️  Skipping push"
fi
echo ""

# Step 5: Create GitHub release
echo "📦 Step 5: Creating GitHub Release..."
read -p "Create GitHub release with gh CLI? (y/N): " release_choice
if [[ "$release_choice" =~ ^[Yy]$ ]]; then
    # Check if gh is available
    if ! command -v gh &> /dev/null; then
        echo "⚠️  gh CLI not found, falling back to manual release"
        echo "   Install with: brew install gh"
        echo ""
        echo "   Manual release at: https://github.com/dtg01100/dcutil/releases/new"
    else
        echo "Creating release with gh CLI..."
        
        # Create release using release_notes.txt
        gh release create "$VERSION" \
            --title "$VERSION - Resource Monitoring & Beginner-Friendly UX" \
            --notes-file release_notes.txt \
            --repo dtg01100/dcutil
        
        if [ $? -eq 0 ]; then
            echo "✅ GitHub release created successfully!"
        else
            echo "⚠️  Release creation failed. Create manually at:"
            echo "   https://github.com/dtg01100/dcutil/releases/new"
        fi
    fi
else
    echo "⏭️  Skipping automatic release creation"
    echo "   Create manually at: https://github.com/dtg01100/dcutil/releases/new"
    echo "   1. Choose tag: $VERSION"
    echo "   2. Title: $VERSION - Resource Monitoring & Beginner-Friendly UX"
    echo "   3. Copy description from release_notes.txt"
    echo "   4. Publish release"
fi
echo ""
read -p "Press Enter after GitHub release is confirmed..."
echo ""

# Step 6: Wait for GitHub Action
echo "⚙️  Step 6: Waiting for GitHub Action to update Homebrew tap..."
echo "   The GitHub Action will automatically:"
echo "   - Calculate the SHA256 checksum"
echo "   - Update the Formula in homebrew-dcutil repository"
echo "   - Create a pull request or commit directly"
echo ""
echo "   Check progress at: https://github.com/dtg01100/dcutil/actions"
echo ""
read -p "Press Enter after GitHub Action completes..."
echo ""

# Step 7: Test installation
echo "🧪 Step 7: Test installation"
echo "   brew uninstall dcutil"
echo "   brew update"
echo "   brew install dtg01100/dcutil/dcutil"
echo "   dcutil version  # Should show $VERSION"
echo "   dcutil menu     # Test new features"
echo ""

echo "✨ Release process complete!"
echo ""
echo "📖 See RELEASE_CHECKLIST for detailed instructions"
