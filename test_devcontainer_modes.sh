#!/usr/bin/env bash

# Test script for devcontainer CLI removal functionality
# Verifies both devcontainer CLI and Docker-native modes work correctly

test_devcontainer_modes() {
    echo "=== Testing Devcontainer CLI Modes ==="
    
    # Test 1: Check which mode is being used
    echo "Testing mode detection..."
    if command -v devcontainer &> /dev/null; then
        echo "✅ devcontainer CLI available"
        
        # Test with devcontainer CLI
        echo "Testing with devcontainer CLI..."
        if ./dcutil status >/dev/null 2>&1; then
            echo "✅ devcontainer CLI mode working"
        else
            echo "❌ devcontainer CLI mode failed"
        fi
    else
        echo "ℹ️  devcontainer CLI not available, using Docker-native"
    fi
    
    # Test 2: Test Docker-native fallback
    echo "Testing Docker-native fallback..."
    if PATH="/usr/bin:/bin:/usr/local/bin" ./dcutil status >/dev/null 2>&1; then
        echo "✅ Docker-native fallback working"
    else
        echo "❌ Docker-native fallback failed"
    fi
    
    # Test 3: Verify configuration parsing
    echo "Testing configuration parsing..."
    if [ -f ".devcontainer/devcontainer.json" ]; then
        echo "✅ Devcontainer configuration found"
        
        # Test JSON validation
        if command -v jq &> /dev/null; then
            if jq . .devcontainer/devcontainer.json >/dev/null 2>&1; then
                echo "✅ JSON configuration is valid"
            else
                echo "❌ JSON configuration is invalid"
            fi
        fi
    else
        echo "❌ No devcontainer configuration found"
    fi
    
    # Test 4: Test basic operations
    echo "Testing basic operations..."
    
    # Test status (should work in both modes)
    if ./dcutil status >/dev/null 2>&1; then
        echo "✅ Status command working"
    else
        echo "❌ Status command failed"
    fi
    
    # Test list (should work in both modes)
    if ./dcutil list >/dev/null 2>&1; then
        echo "✅ List command working"
    else
        echo "❌ List command failed"
    fi
    
    echo "=== Test Complete ==="
}

# Run the test
test_devcontainer_modes