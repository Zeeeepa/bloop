#!/usr/bin/env python3
"""
Bloop Setup Script - Python Version
Comprehensive setup with variable validation and dependency management
"""

import os
import sys
import json
import subprocess
import shutil
import getpass
import time
import requests
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# Color codes for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'  # No Color

class LogLevel(Enum):
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    SUCCESS = "SUCCESS"

@dataclass
class RequiredVariable:
    name: str
    description: str
    required: bool = True
    default: Optional[str] = None
    validator: Optional[callable] = None
    secure: bool = False  # If True, input will be masked

@dataclass
class SystemDependency:
    name: str
    command: str
    install_cmd: Optional[str] = None
    version_cmd: Optional[str] = None
    required: bool = True

class BloopSetup:
    def __init__(self):
        self.config_file = Path("bloop_config.json")
        self.env_file = Path(".env")
        self.log_file = Path("setup.log")
        self.config = {}
        
        # Required variables for bloop
        self.required_variables = [
            RequiredVariable(
                name="OPENAI_API_KEY",
                description="OpenAI API key for AI-powered code analysis",
                required=False,  # Optional for basic functionality
                validator=self.validate_openai_key,
                secure=True
            ),
            RequiredVariable(
                name="GITHUB_TOKEN",
                description="GitHub personal access token for repository access",
                required=False,  # Optional for public repos
                validator=self.validate_github_token,
                secure=True
            ),
            RequiredVariable(
                name="BLOOP_HOST",
                description="Host address for bloop services",
                required=True,
                default="127.0.0.1"
            ),
            RequiredVariable(
                name="BLOOP_BACKEND_PORT",
                description="Port for bloop backend service",
                required=True,
                default="7878",
                validator=self.validate_port
            ),
            RequiredVariable(
                name="BLOOP_FRONTEND_PORT",
                description="Port for bloop frontend service",
                required=True,
                default="3000",
                validator=self.validate_port
            ),
            RequiredVariable(
                name="BLOOP_LOG_LEVEL",
                description="Logging level (debug, info, warn, error)",
                required=True,
                default="info",
                validator=lambda x: x.lower() in ["debug", "info", "warn", "error"]
            ),
            RequiredVariable(
                name="BLOOP_DATA_DIR",
                description="Directory for bloop data storage",
                required=True,
                default="./data"
            ),
            RequiredVariable(
                name="BLOOP_INDEX_DIR",
                description="Directory for search index storage",
                required=True,
                default="./index"
            )
        ]
        
        # System dependencies
        self.system_dependencies = [
            SystemDependency(
                name="Git",
                command="git",
                install_cmd="sudo apt-get install -y git",
                version_cmd="git --version"
            ),
            SystemDependency(
                name="Node.js",
                command="node",
                install_cmd="curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs",
                version_cmd="node --version"
            ),
            SystemDependency(
                name="NPM",
                command="npm",
                install_cmd="sudo apt-get install -y npm",
                version_cmd="npm --version"
            ),
            SystemDependency(
                name="Rust",
                command="rustc",
                install_cmd="curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
                version_cmd="rustc --version",
                required=False  # Optional if using quick start
            ),
            SystemDependency(
                name="Cargo",
                command="cargo",
                install_cmd="curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
                version_cmd="cargo --version",
                required=False  # Optional if using quick start
            )
        ]

    def log(self, message: str, level: LogLevel = LogLevel.INFO):
        """Log message with color coding and timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        
        color_map = {
            LogLevel.INFO: Colors.BLUE,
            LogLevel.WARN: Colors.YELLOW,
            LogLevel.ERROR: Colors.RED,
            LogLevel.SUCCESS: Colors.GREEN
        }
        
        color = color_map.get(level, Colors.WHITE)
        formatted_message = f"{color}[{timestamp}] {level.value}: {message}{Colors.NC}"
        
        print(formatted_message)
        
        # Also log to file
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] {level.value}: {message}\n")

    def validate_port(self, port: str) -> bool:
        """Validate port number"""
        try:
            port_num = int(port)
            return 1024 <= port_num <= 65535
        except ValueError:
            return False

    def validate_openai_key(self, key: str) -> bool:
        """Validate OpenAI API key"""
        if not key or not key.startswith("sk-"):
            return False
        
        try:
            # Test the key with a simple API call
            headers = {
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json"
            }
            response = requests.get(
                "https://api.openai.com/v1/models",
                headers=headers,
                timeout=10
            )
            return response.status_code == 200
        except Exception as e:
            self.log(f"OpenAI API key validation failed: {e}", LogLevel.WARN)
            return False

    def validate_github_token(self, token: str) -> bool:
        """Validate GitHub token"""
        if not token:
            return False
        
        try:
            # Test the token with GitHub API
            headers = {
                "Authorization": f"token {token}",
                "Accept": "application/vnd.github.v3+json"
            }
            response = requests.get(
                "https://api.github.com/user",
                headers=headers,
                timeout=10
            )
            return response.status_code == 200
        except Exception as e:
            self.log(f"GitHub token validation failed: {e}", LogLevel.WARN)
            return False

    def check_command_exists(self, command: str) -> bool:
        """Check if a command exists in the system"""
        return shutil.which(command) is not None

    def run_command(self, command: str, capture_output: bool = True) -> Tuple[bool, str]:
        """Run a system command and return success status and output"""
        try:
            if capture_output:
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                return result.returncode == 0, result.stdout + result.stderr
            else:
                result = subprocess.run(command, shell=True, timeout=300)
                return result.returncode == 0, ""
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)

    def check_system_dependencies(self) -> Dict[str, bool]:
        """Check all system dependencies"""
        self.log("🔍 Checking system dependencies...", LogLevel.INFO)
        
        results = {}
        for dep in self.system_dependencies:
            exists = self.check_command_exists(dep.command)
            results[dep.name] = exists
            
            if exists:
                if dep.version_cmd:
                    success, version = self.run_command(dep.version_cmd)
                    if success:
                        self.log(f"✅ {dep.name}: {version.strip()}", LogLevel.SUCCESS)
                    else:
                        self.log(f"✅ {dep.name}: Found (version check failed)", LogLevel.SUCCESS)
                else:
                    self.log(f"✅ {dep.name}: Found", LogLevel.SUCCESS)
            else:
                if dep.required:
                    self.log(f"❌ {dep.name}: Not found (REQUIRED)", LogLevel.ERROR)
                else:
                    self.log(f"⚠️ {dep.name}: Not found (optional)", LogLevel.WARN)
        
        return results

    def install_missing_dependencies(self, missing_deps: List[str]) -> bool:
        """Install missing system dependencies"""
        if not missing_deps:
            return True
        
        self.log("📦 Installing missing dependencies...", LogLevel.INFO)
        
        for dep_name in missing_deps:
            dep = next((d for d in self.system_dependencies if d.name == dep_name), None)
            if not dep or not dep.install_cmd:
                continue
            
            self.log(f"Installing {dep.name}...", LogLevel.INFO)
            success, output = self.run_command(dep.install_cmd, capture_output=False)
            
            if success:
                self.log(f"✅ {dep.name} installed successfully", LogLevel.SUCCESS)
            else:
                self.log(f"❌ Failed to install {dep.name}: {output}", LogLevel.ERROR)
                return False
        
        return True

    def collect_variables(self) -> Dict[str, str]:
        """Collect all required variables from user"""
        self.log("📝 Collecting configuration variables...", LogLevel.INFO)
        
        variables = {}
        
        for var in self.required_variables:
            while True:
                # Show description
                print(f"\n{Colors.CYAN}{var.description}{Colors.NC}")
                
                # Show default if available
                prompt = f"Enter {var.name}"
                if var.default:
                    prompt += f" (default: {var.default})"
                if not var.required:
                    prompt += " (optional)"
                prompt += ": "
                
                # Get input (masked if secure)
                if var.secure:
                    value = getpass.getpass(prompt)
                else:
                    value = input(prompt).strip()
                
                # Use default if empty and default exists
                if not value and var.default:
                    value = var.default
                
                # Check if required
                if var.required and not value:
                    self.log(f"❌ {var.name} is required", LogLevel.ERROR)
                    continue
                
                # Skip validation if empty and not required
                if not value and not var.required:
                    break
                
                # Validate if validator exists
                if var.validator and value:
                    if not var.validator(value):
                        self.log(f"❌ Invalid value for {var.name}", LogLevel.ERROR)
                        continue
                
                variables[var.name] = value
                if value:
                    if var.secure:
                        self.log(f"✅ {var.name}: [HIDDEN]", LogLevel.SUCCESS)
                    else:
                        self.log(f"✅ {var.name}: {value}", LogLevel.SUCCESS)
                else:
                    self.log(f"⚠️ {var.name}: Not set (optional)", LogLevel.WARN)
                break
        
        return variables

    def save_configuration(self, variables: Dict[str, str]):
        """Save configuration to files"""
        self.log("💾 Saving configuration...", LogLevel.INFO)
        
        # Save to JSON config file
        config = {
            "host": variables.get("BLOOP_HOST", "127.0.0.1"),
            "backend_port": int(variables.get("BLOOP_BACKEND_PORT", "7878")),
            "frontend_port": int(variables.get("BLOOP_FRONTEND_PORT", "3000")),
            "log_level": variables.get("BLOOP_LOG_LEVEL", "info"),
            "data_dir": variables.get("BLOOP_DATA_DIR", "./data"),
            "index_dir": variables.get("BLOOP_INDEX_DIR", "./index"),
            "openai_enabled": bool(variables.get("OPENAI_API_KEY")),
            "github_enabled": bool(variables.get("GITHUB_TOKEN"))
        }
        
        with open(self.config_file, "w") as f:
            json.dump(config, f, indent=2)
        
        # Save to .env file
        env_content = []
        for key, value in variables.items():
            if value:  # Only save non-empty values
                env_content.append(f"{key}={value}")
        
        with open(self.env_file, "w") as f:
            f.write("\n".join(env_content))
        
        # Set appropriate permissions for .env file
        os.chmod(self.env_file, 0o600)
        
        self.log(f"✅ Configuration saved to {self.config_file} and {self.env_file}", LogLevel.SUCCESS)

    def create_directories(self, variables: Dict[str, str]):
        """Create necessary directories"""
        self.log("📁 Creating directories...", LogLevel.INFO)
        
        dirs_to_create = [
            variables.get("BLOOP_DATA_DIR", "./data"),
            variables.get("BLOOP_INDEX_DIR", "./index"),
            "./logs"
        ]
        
        for dir_path in dirs_to_create:
            Path(dir_path).mkdir(parents=True, exist_ok=True)
            self.log(f"✅ Created directory: {dir_path}", LogLevel.SUCCESS)

    def validate_configuration(self) -> bool:
        """Validate the complete configuration"""
        self.log("🔍 Validating configuration...", LogLevel.INFO)
        
        # Check if config files exist
        if not self.config_file.exists():
            self.log("❌ Configuration file not found", LogLevel.ERROR)
            return False
        
        if not self.env_file.exists():
            self.log("❌ Environment file not found", LogLevel.ERROR)
            return False
        
        # Load and validate config
        try:
            with open(self.config_file, "r") as f:
                config = json.load(f)
            
            # Check required fields
            required_fields = ["host", "backend_port", "frontend_port"]
            for field in required_fields:
                if field not in config:
                    self.log(f"❌ Missing required field: {field}", LogLevel.ERROR)
                    return False
            
            # Check port availability
            backend_port = config["backend_port"]
            frontend_port = config["frontend_port"]
            
            if self.is_port_in_use(backend_port):
                self.log(f"⚠️ Backend port {backend_port} is already in use", LogLevel.WARN)
            
            if self.is_port_in_use(frontend_port):
                self.log(f"⚠️ Frontend port {frontend_port} is already in use", LogLevel.WARN)
            
            self.log("✅ Configuration validation passed", LogLevel.SUCCESS)
            return True
            
        except Exception as e:
            self.log(f"❌ Configuration validation failed: {e}", LogLevel.ERROR)
            return False

    def is_port_in_use(self, port: int) -> bool:
        """Check if a port is already in use"""
        import socket
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) == 0

    def setup_node_dependencies(self) -> bool:
        """Install Node.js dependencies"""
        self.log("📦 Installing Node.js dependencies...", LogLevel.INFO)
        
        # Install root dependencies
        success, output = self.run_command("npm install")
        if not success:
            self.log(f"❌ Failed to install root dependencies: {output}", LogLevel.ERROR)
            return False
        
        # Install client dependencies
        if Path("client").exists():
            self.log("Installing client dependencies...", LogLevel.INFO)
            success, output = self.run_command("cd client && npm install")
            if not success:
                self.log(f"❌ Failed to install client dependencies: {output}", LogLevel.ERROR)
                return False
        
        self.log("✅ Node.js dependencies installed", LogLevel.SUCCESS)
        return True

    def choose_deployment_mode(self) -> str:
        """Let user choose deployment mode"""
        print(f"\n{Colors.CYAN}🚀 Choose deployment mode:{Colors.NC}")
        print("1. Quick Start (Mock backend, fast setup)")
        print("2. Full Deployment (Rust backend, production ready)")
        
        while True:
            choice = input("\nEnter your choice (1 or 2): ").strip()
            if choice in ["1", "2"]:
                return "quick" if choice == "1" else "full"
            print("Invalid choice. Please enter 1 or 2.")

    def run_setup(self):
        """Main setup process"""
        print(f"{Colors.GREEN}")
        print("=" * 60)
        print("🚀 BLOOP SETUP - Python Version")
        print("Comprehensive setup with validation")
        print("=" * 60)
        print(f"{Colors.NC}")
        
        try:
            # Step 1: Check system dependencies
            dep_results = self.check_system_dependencies()
            
            # Step 2: Choose deployment mode
            mode = self.choose_deployment_mode()
            
            # Step 3: Install missing required dependencies
            missing_required = []
            for dep in self.system_dependencies:
                if dep.required and not dep_results.get(dep.name, False):
                    missing_required.append(dep.name)
            
            # For quick mode, Rust/Cargo are not required
            if mode == "quick":
                missing_required = [d for d in missing_required if d not in ["Rust", "Cargo"]]
            
            if missing_required:
                install_choice = input(f"\nInstall missing dependencies {missing_required}? (y/n): ")
                if install_choice.lower() == 'y':
                    if not self.install_missing_dependencies(missing_required):
                        self.log("❌ Failed to install required dependencies", LogLevel.ERROR)
                        return False
                else:
                    self.log("❌ Cannot proceed without required dependencies", LogLevel.ERROR)
                    return False
            
            # Step 4: Collect configuration variables
            variables = self.collect_variables()
            
            # Step 5: Save configuration
            self.save_configuration(variables)
            
            # Step 6: Create directories
            self.create_directories(variables)
            
            # Step 7: Install Node.js dependencies
            if not self.setup_node_dependencies():
                return False
            
            # Step 8: Validate configuration
            if not self.validate_configuration():
                return False
            
            # Step 9: Create deployment-specific files
            self.create_deployment_files(mode)
            
            # Success message
            self.log("🎉 Setup completed successfully!", LogLevel.SUCCESS)
            print(f"\n{Colors.GREEN}✅ SETUP COMPLETE!{Colors.NC}")
            print(f"\n{Colors.CYAN}Next steps:{Colors.NC}")
            print(f"1. Run: python3 preview.py")
            print(f"2. Open: http://localhost:{variables.get('BLOOP_FRONTEND_PORT', '3000')}")
            print(f"3. Check logs: tail -f setup.log")
            
            return True
            
        except KeyboardInterrupt:
            self.log("\n❌ Setup interrupted by user", LogLevel.ERROR)
            return False
        except Exception as e:
            self.log(f"❌ Setup failed: {e}", LogLevel.ERROR)
            return False

    def create_deployment_files(self, mode: str):
        """Create deployment-specific files"""
        self.log(f"📄 Creating deployment files for {mode} mode...", LogLevel.INFO)
        
        # Create a deployment info file
        deployment_info = {
            "mode": mode,
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "python_version": sys.version,
            "setup_version": "1.0.0"
        }
        
        with open("deployment_info.json", "w") as f:
            json.dump(deployment_info, f, indent=2)
        
        self.log("✅ Deployment files created", LogLevel.SUCCESS)

def main():
    """Main entry point"""
    setup = BloopSetup()
    success = setup.run_setup()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
