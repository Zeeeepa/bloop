#!/usr/bin/env python3
"""
Bloop Preview Script - Python Version
Persistent UI streaming and service management
"""

import os
import sys
import json
import subprocess
import signal
import time
import threading
import socket
import requests
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import webbrowser

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

class ServiceStatus(Enum):
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    ERROR = "error"

@dataclass
class Service:
    name: str
    command: str
    port: int
    health_url: str
    log_file: str
    process: Optional[subprocess.Popen] = None
    status: ServiceStatus = ServiceStatus.STOPPED
    restart_count: int = 0
    max_restarts: int = 3

class BloopPreview:
    def __init__(self):
        self.config_file = Path("bloop_config.json")
        self.env_file = Path(".env")
        self.deployment_info_file = Path("deployment_info.json")
        self.log_file = Path("preview.log")
        self.pid_file = Path("bloop.pid")
        
        self.config = {}
        self.services = []
        self.running = True
        self.monitor_thread = None
        
        # Load configuration
        self.load_configuration()
        self.setup_services()

    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        
        color_map = {
            "INFO": Colors.BLUE,
            "WARN": Colors.YELLOW,
            "ERROR": Colors.RED,
            "SUCCESS": Colors.GREEN
        }
        
        color = color_map.get(level, Colors.WHITE)
        formatted_message = f"{color}[{timestamp}] {level}: {message}{Colors.NC}"
        
        print(formatted_message)
        
        # Also log to file
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] {level}: {message}\n")

    def load_configuration(self):
        """Load configuration from files"""
        try:
            if self.config_file.exists():
                with open(self.config_file, "r") as f:
                    self.config = json.load(f)
                self.log("✅ Configuration loaded", "SUCCESS")
            else:
                self.log("❌ Configuration file not found. Run setup.py first.", "ERROR")
                sys.exit(1)
                
            # Load environment variables
            if self.env_file.exists():
                with open(self.env_file, "r") as f:
                    for line in f:
                        if line.strip() and not line.startswith("#"):
                            key, value = line.strip().split("=", 1)
                            os.environ[key] = value
                            
        except Exception as e:
            self.log(f"❌ Failed to load configuration: {e}", "ERROR")
            sys.exit(1)

    def setup_services(self):
        """Setup service configurations based on deployment mode"""
        try:
            # Load deployment info
            deployment_mode = "quick"  # default
            if self.deployment_info_file.exists():
                with open(self.deployment_info_file, "r") as f:
                    deployment_info = json.load(f)
                    deployment_mode = deployment_info.get("mode", "quick")
            
            host = self.config.get("host", "127.0.0.1")
            backend_port = self.config.get("backend_port", 7878)
            frontend_port = self.config.get("frontend_port", 3000)
            
            if deployment_mode == "quick":
                # Quick mode: Mock backend + Frontend
                self.services = [
                    Service(
                        name="Mock Backend",
                        command=f"node mock-server.js",
                        port=backend_port,
                        health_url=f"http://{host}:{backend_port}/health",
                        log_file="logs/backend.log"
                    ),
                    Service(
                        name="Frontend",
                        command=f"npm run start-web -- --host {host} --port {frontend_port}",
                        port=frontend_port,
                        health_url=f"http://{host}:{frontend_port}",
                        log_file="logs/frontend.log"
                    )
                ]
            else:
                # Full mode: Rust backend + Frontend
                self.services = [
                    Service(
                        name="Rust Backend",
                        command=f"cd server && cargo run --bin bleep -- --config-file=../bloop_config.json",
                        port=backend_port,
                        health_url=f"http://{host}:{backend_port}/health",
                        log_file="logs/backend.log"
                    ),
                    Service(
                        name="Frontend",
                        command=f"npm run start-web -- --host {host} --port {frontend_port}",
                        port=frontend_port,
                        health_url=f"http://{host}:{frontend_port}",
                        log_file="logs/frontend.log"
                    )
                ]
                
            self.log(f"✅ Services configured for {deployment_mode} mode", "SUCCESS")
            
        except Exception as e:
            self.log(f"❌ Failed to setup services: {e}", "ERROR")
            sys.exit(1)

    def is_port_available(self, port: int) -> bool:
        """Check if a port is available"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) != 0

    def wait_for_service(self, service: Service, timeout: int = 60) -> bool:
        """Wait for a service to become healthy"""
        self.log(f"⏳ Waiting for {service.name} to be ready...", "INFO")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = requests.get(service.health_url, timeout=5)
                if response.status_code == 200:
                    self.log(f"✅ {service.name} is ready", "SUCCESS")
                    return True
            except requests.exceptions.RequestException:
                pass
            
            time.sleep(2)
        
        self.log(f"❌ {service.name} failed to become ready within {timeout}s", "ERROR")
        return False

    def start_service(self, service: Service) -> bool:
        """Start a single service"""
        try:
            self.log(f"🚀 Starting {service.name}...", "INFO")
            
            # Check if port is available
            if not self.is_port_available(service.port):
                self.log(f"❌ Port {service.port} is already in use", "ERROR")
                return False
            
            # Create log directory
            Path(service.log_file).parent.mkdir(parents=True, exist_ok=True)
            
            # Start the service
            with open(service.log_file, "w") as log_file:
                service.process = subprocess.Popen(
                    service.command,
                    shell=True,
                    stdout=log_file,
                    stderr=subprocess.STDOUT,
                    preexec_fn=os.setsid  # Create new process group
                )
            
            service.status = ServiceStatus.STARTING
            
            # Wait for service to be ready
            if self.wait_for_service(service):
                service.status = ServiceStatus.RUNNING
                self.log(f"✅ {service.name} started successfully (PID: {service.process.pid})", "SUCCESS")
                return True
            else:
                service.status = ServiceStatus.ERROR
                self.stop_service(service)
                return False
                
        except Exception as e:
            self.log(f"❌ Failed to start {service.name}: {e}", "ERROR")
            service.status = ServiceStatus.ERROR
            return False

    def stop_service(self, service: Service):
        """Stop a single service"""
        if service.process:
            try:
                self.log(f"🛑 Stopping {service.name}...", "INFO")
                
                # Kill the process group
                os.killpg(os.getpgid(service.process.pid), signal.SIGTERM)
                
                # Wait for graceful shutdown
                try:
                    service.process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    # Force kill if not stopped gracefully
                    os.killpg(os.getpgid(service.process.pid), signal.SIGKILL)
                    service.process.wait()
                
                service.process = None
                service.status = ServiceStatus.STOPPED
                self.log(f"✅ {service.name} stopped", "SUCCESS")
                
            except Exception as e:
                self.log(f"❌ Error stopping {service.name}: {e}", "ERROR")

    def restart_service(self, service: Service) -> bool:
        """Restart a service"""
        self.log(f"🔄 Restarting {service.name}...", "INFO")
        
        if service.restart_count >= service.max_restarts:
            self.log(f"❌ {service.name} has reached maximum restart attempts", "ERROR")
            return False
        
        self.stop_service(service)
        time.sleep(2)  # Brief pause before restart
        
        service.restart_count += 1
        return self.start_service(service)

    def check_service_health(self, service: Service) -> bool:
        """Check if a service is healthy"""
        if service.status != ServiceStatus.RUNNING:
            return False
        
        try:
            # Check if process is still running
            if service.process and service.process.poll() is not None:
                return False
            
            # Check health endpoint
            response = requests.get(service.health_url, timeout=5)
            return response.status_code == 200
            
        except Exception:
            return False

    def monitor_services(self):
        """Monitor services and restart if needed"""
        while self.running:
            try:
                for service in self.services:
                    if service.status == ServiceStatus.RUNNING:
                        if not self.check_service_health(service):
                            self.log(f"⚠️ {service.name} is unhealthy, restarting...", "WARN")
                            service.status = ServiceStatus.ERROR
                            
                            if not self.restart_service(service):
                                self.log(f"❌ Failed to restart {service.name}", "ERROR")
                
                time.sleep(10)  # Check every 10 seconds
                
            except Exception as e:
                self.log(f"❌ Error in service monitor: {e}", "ERROR")
                time.sleep(5)

    def start_all_services(self) -> bool:
        """Start all services"""
        self.log("🚀 Starting all services...", "INFO")
        
        success = True
        for service in self.services:
            if not self.start_service(service):
                success = False
        
        return success

    def stop_all_services(self):
        """Stop all services"""
        self.log("🛑 Stopping all services...", "INFO")
        
        for service in self.services:
            self.stop_service(service)

    def show_status(self):
        """Show status of all services"""
        print(f"\n{Colors.CYAN}📊 Service Status:{Colors.NC}")
        print("=" * 50)
        
        for service in self.services:
            status_color = {
                ServiceStatus.STOPPED: Colors.RED,
                ServiceStatus.STARTING: Colors.YELLOW,
                ServiceStatus.RUNNING: Colors.GREEN,
                ServiceStatus.ERROR: Colors.RED
            }.get(service.status, Colors.WHITE)
            
            print(f"{service.name:15} | {status_color}{service.status.value:10}{Colors.NC} | Port: {service.port}")
            
            if service.status == ServiceStatus.RUNNING and service.process:
                print(f"{'':15} | PID: {service.process.pid:10} | Restarts: {service.restart_count}")
        
        print("=" * 50)

    def open_browser(self):
        """Open browser to the frontend URL"""
        frontend_port = self.config.get("frontend_port", 3000)
        host = self.config.get("host", "127.0.0.1")
        url = f"http://{host}:{frontend_port}"
        
        try:
            webbrowser.open(url)
            self.log(f"🌐 Opened browser to {url}", "SUCCESS")
        except Exception as e:
            self.log(f"❌ Failed to open browser: {e}", "ERROR")

    def save_pid(self):
        """Save process ID to file"""
        with open(self.pid_file, "w") as f:
            f.write(str(os.getpid()))

    def cleanup_pid(self):
        """Remove PID file"""
        if self.pid_file.exists():
            self.pid_file.unlink()

    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.log(f"📡 Received signal {signum}, shutting down...", "INFO")
        self.running = False
        self.stop_all_services()
        self.cleanup_pid()
        sys.exit(0)

    def interactive_menu(self):
        """Show interactive menu for service management"""
        while self.running:
            try:
                print(f"\n{Colors.CYAN}🎛️ Bloop Service Manager{Colors.NC}")
                print("1. Show status")
                print("2. Restart all services")
                print("3. Open browser")
                print("4. View logs")
                print("5. Quit")
                
                choice = input(f"\n{Colors.YELLOW}Enter choice (1-5): {Colors.NC}").strip()
                
                if choice == "1":
                    self.show_status()
                elif choice == "2":
                    self.stop_all_services()
                    time.sleep(2)
                    self.start_all_services()
                elif choice == "3":
                    self.open_browser()
                elif choice == "4":
                    self.show_logs_menu()
                elif choice == "5":
                    break
                else:
                    print("Invalid choice. Please enter 1-5.")
                    
            except KeyboardInterrupt:
                break

    def show_logs_menu(self):
        """Show logs menu"""
        print(f"\n{Colors.CYAN}📋 Available logs:{Colors.NC}")
        for i, service in enumerate(self.services, 1):
            print(f"{i}. {service.name} ({service.log_file})")
        print(f"{len(self.services) + 1}. Setup log (setup.log)")
        print(f"{len(self.services) + 2}. Preview log (preview.log)")
        
        try:
            choice = int(input(f"\n{Colors.YELLOW}Enter log number: {Colors.NC}"))
            
            if 1 <= choice <= len(self.services):
                log_file = self.services[choice - 1].log_file
            elif choice == len(self.services) + 1:
                log_file = "setup.log"
            elif choice == len(self.services) + 2:
                log_file = "preview.log"
            else:
                print("Invalid choice.")
                return
            
            if Path(log_file).exists():
                print(f"\n{Colors.CYAN}📄 Last 20 lines of {log_file}:{Colors.NC}")
                subprocess.run(f"tail -20 {log_file}", shell=True)
            else:
                print(f"Log file {log_file} not found.")
                
        except ValueError:
            print("Invalid input. Please enter a number.")

    def run_preview(self):
        """Main preview process"""
        print(f"{Colors.GREEN}")
        print("=" * 60)
        print("🎬 BLOOP PREVIEW - Python Version")
        print("Persistent UI streaming and service management")
        print("=" * 60)
        print(f"{Colors.NC}")
        
        try:
            # Setup signal handlers
            signal.signal(signal.SIGINT, self.signal_handler)
            signal.signal(signal.SIGTERM, self.signal_handler)
            
            # Save PID
            self.save_pid()
            
            # Start all services
            if not self.start_all_services():
                self.log("❌ Failed to start some services", "ERROR")
                return False
            
            # Start monitoring thread
            self.monitor_thread = threading.Thread(target=self.monitor_services, daemon=True)
            self.monitor_thread.start()
            
            # Show initial status
            self.show_status()
            
            # Open browser after a short delay
            threading.Timer(3.0, self.open_browser).start()
            
            # Show URLs
            host = self.config.get("host", "127.0.0.1")
            frontend_port = self.config.get("frontend_port", 3000)
            backend_port = self.config.get("backend_port", 7878)
            
            print(f"\n{Colors.GREEN}🎉 Bloop is running!{Colors.NC}")
            print(f"🌐 Frontend: http://{host}:{frontend_port}")
            print(f"🔧 Backend:  http://{host}:{backend_port}")
            print(f"📊 Health:   http://{host}:{backend_port}/health")
            print(f"\n{Colors.YELLOW}Press Ctrl+C to stop or use the interactive menu{Colors.NC}")
            
            # Run interactive menu
            self.interactive_menu()
            
            return True
            
        except Exception as e:
            self.log(f"❌ Preview failed: {e}", "ERROR")
            return False
        finally:
            self.running = False
            self.stop_all_services()
            self.cleanup_pid()

def main():
    """Main entry point"""
    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        # Just show status and exit
        preview = BloopPreview()
        preview.show_status()
        return
    
    preview = BloopPreview()
    success = preview.run_preview()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
