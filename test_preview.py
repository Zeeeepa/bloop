#!/usr/bin/env python3
"""
Test script for bloop preview system
"""

import os
import sys
import time
import threading
import requests
from pathlib import Path

# Add the current directory to Python path
sys.path.insert(0, '.')

# Import the preview module
from preview import BloopPreview

class TestBloopPreview(BloopPreview):
    def __init__(self):
        super().__init__()
        self.test_mode = True

    def open_browser(self):
        """Override to skip browser opening in test mode"""
        self.log("🧪 Skipping browser opening in test mode", "INFO")

    def interactive_menu(self):
        """Override to run for a limited time in test mode"""
        self.log("🧪 Running in test mode - will run for 30 seconds", "INFO")
        
        # Show status a few times
        for i in range(3):
            time.sleep(10)
            self.show_status()
            
            # Test health endpoints
            self.test_endpoints()
        
        self.log("🧪 Test completed, shutting down", "INFO")

    def test_endpoints(self):
        """Test the running services"""
        host = self.config.get("host", "127.0.0.1")
        backend_port = self.config.get("backend_port", 7878)
        frontend_port = self.config.get("frontend_port", 3000)
        
        # Test backend health
        try:
            response = requests.get(f"http://{host}:{backend_port}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ Backend health: {data.get('status')} (uptime: {data.get('uptime', 0):.1f}s)", "SUCCESS")
            else:
                self.log(f"⚠️ Backend health check failed: {response.status_code}", "WARN")
        except Exception as e:
            self.log(f"❌ Backend health check error: {e}", "ERROR")
        
        # Test backend search
        try:
            search_data = {"q": "test query", "repos": ["bloop"]}
            response = requests.post(f"http://{host}:{backend_port}/q", json=search_data, timeout=5)
            if response.status_code == 200:
                data = response.json()
                results_count = len(data.get('results', []))
                self.log(f"✅ Backend search: {results_count} results for '{data.get('query')}'", "SUCCESS")
            else:
                self.log(f"⚠️ Backend search failed: {response.status_code}", "WARN")
        except Exception as e:
            self.log(f"❌ Backend search error: {e}", "ERROR")
        
        # Test backend repos
        try:
            response = requests.get(f"http://{host}:{backend_port}/repos", timeout=5)
            if response.status_code == 200:
                data = response.json()
                repos_count = len(data.get('repositories', []))
                self.log(f"✅ Backend repos: {repos_count} repositories available", "SUCCESS")
            else:
                self.log(f"⚠️ Backend repos failed: {response.status_code}", "WARN")
        except Exception as e:
            self.log(f"❌ Backend repos error: {e}", "ERROR")

def test_preview():
    """Test the preview system"""
    print("🧪 Testing bloop preview system...")
    
    # Check if configuration exists
    config_file = Path("bloop_config.json")
    if not config_file.exists():
        print("❌ Configuration file not found. Run setup first.")
        return False
    
    # Create test preview instance
    preview = TestBloopPreview()
    
    print("\n🚀 Starting preview system test...")
    success = preview.run_preview()
    
    return success

if __name__ == "__main__":
    success = test_preview()
    sys.exit(0 if success else 1)
