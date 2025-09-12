#!/usr/bin/env python3
"""
Test script for bloop setup with provided API keys
"""

import os
import sys
import json
from pathlib import Path

# Load environment variables from .env file
def load_env():
    env_file = Path('.env')
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key] = value

load_env()

# Add the current directory to Python path
sys.path.insert(0, '.')

# Import the setup module
from setup import BloopSetup, LogLevel

class TestBloopSetup(BloopSetup):
    def __init__(self, test_config):
        super().__init__()
        self.test_config = test_config
        self.test_mode = True

    def choose_deployment_mode(self) -> str:
        """Override to use quick mode for testing"""
        self.log("🧪 Using Quick Start mode for testing", LogLevel.INFO)
        return "quick"

    def collect_variables(self):
        """Override to use provided test configuration"""
        self.log("🧪 Using provided test configuration", LogLevel.INFO)
        
        variables = {}
        
        # Use test config values
        for var in self.required_variables:
            if var.name in self.test_config:
                value = self.test_config[var.name]
                variables[var.name] = value
                
                if value:
                    if var.secure:
                        self.log(f"✅ {var.name}: [PROVIDED]", LogLevel.SUCCESS)
                    else:
                        self.log(f"✅ {var.name}: {value}", LogLevel.SUCCESS)
                else:
                    self.log(f"⚠️ {var.name}: Not set (optional)", LogLevel.WARN)
            elif var.default:
                variables[var.name] = var.default
                self.log(f"✅ {var.name}: {var.default} (default)", LogLevel.SUCCESS)
            elif not var.required:
                variables[var.name] = ""
                self.log(f"⚠️ {var.name}: Not set (optional)", LogLevel.WARN)
            else:
                self.log(f"❌ {var.name}: Required but not provided", LogLevel.ERROR)
                
        return variables

    def install_missing_dependencies(self, missing_deps):
        """Override to skip actual installation for testing"""
        self.log(f"🧪 Would install dependencies: {missing_deps}", LogLevel.INFO)
        return True

def test_api_keys():
    """Test the provided API keys"""
    print("🧪 Testing provided API keys...")
    
    # Test configuration - read from environment variables
    test_config = {
        "OPENAI_API_KEY": os.getenv("OPENAI_API_KEY", ""),
        "GITHUB_TOKEN": os.getenv("GITHUB_TOKEN", ""),
        "BLOOP_HOST": "127.0.0.1",
        "BLOOP_BACKEND_PORT": "7878",
        "BLOOP_FRONTEND_PORT": "3000",
        "BLOOP_LOG_LEVEL": "info",
        "BLOOP_DATA_DIR": "./data",
        "BLOOP_INDEX_DIR": "./index"
    }
    
    # Create test setup instance
    setup = TestBloopSetup(test_config)
    
    # Test API key validation
    print("\n🔑 Testing OpenAI API Key...")
    openai_valid = setup.validate_openai_key(test_config["OPENAI_API_KEY"])
    print(f"OpenAI API Key: {'✅ Valid' if openai_valid else '❌ Invalid'}")
    
    print("\n🔑 Testing GitHub Token...")
    github_valid = setup.validate_github_token(test_config["GITHUB_TOKEN"])
    print(f"GitHub Token: {'✅ Valid' if github_valid else '❌ Invalid'}")
    
    # Run full setup
    print("\n🚀 Running full setup process...")
    success = setup.run_setup()
    
    if success:
        print("\n✅ Setup completed successfully!")
        
        # Check created files
        config_file = Path("bloop_config.json")
        env_file = Path(".env")
        
        if config_file.exists():
            print(f"✅ Configuration file created: {config_file}")
            with open(config_file, "r") as f:
                config = json.load(f)
                print(f"   - Host: {config.get('host')}")
                print(f"   - Backend Port: {config.get('backend_port')}")
                print(f"   - Frontend Port: {config.get('frontend_port')}")
                print(f"   - OpenAI Enabled: {config.get('openai_enabled')}")
                print(f"   - GitHub Enabled: {config.get('github_enabled')}")
        
        if env_file.exists():
            print(f"✅ Environment file created: {env_file}")
            # Don't print contents for security
        
        return True
    else:
        print("\n❌ Setup failed!")
        return False

if __name__ == "__main__":
    success = test_api_keys()
    sys.exit(0 if success else 1)
