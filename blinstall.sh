#!/bin/bash

# Bloop Complete Installation and Deployment Script
# Comprehensive dependency installer, checker, and deployer

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        log "Detected Linux system ✓"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        log "Detected macOS system ✓"
    else
        error "Unsupported operating system: $OSTYPE"
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    log "Architecture: $ARCH ✓"
    
    # Check available memory
    if command_exists free; then
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$MEMORY_GB" -lt 4 ]; then
            warn "Low memory detected: ${MEMORY_GB}GB. Recommended: 4GB+"
        else
            log "Memory: ${MEMORY_GB}GB ✓"
        fi
    fi
    
    # Check disk space
    DISK_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_SPACE" -lt 5 ]; then
        warn "Low disk space: ${DISK_SPACE}GB. Recommended: 5GB+"
    else
        log "Disk space: ${DISK_SPACE}GB ✓"
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    if [[ "$OS" == "linux" ]]; then
        # Update package list
        if command_exists apt-get; then
            sudo apt-get update -qq
            sudo apt-get install -y \
                curl \
                wget \
                git \
                build-essential \
                pkg-config \
                libssl-dev \
                cmake \
                clang \
                protobuf-compiler \
                libprotobuf-dev \
                ca-certificates \
                gnupg \
                lsb-release
            log "System dependencies installed ✓"
        elif command_exists yum; then
            sudo yum update -y
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                curl \
                wget \
                git \
                openssl-devel \
                cmake \
                clang \
                protobuf-compiler \
                protobuf-devel
            log "System dependencies installed ✓"
        else
            warn "Package manager not detected. Please install dependencies manually."
        fi
    elif [[ "$OS" == "macos" ]]; then
        if command_exists brew; then
            brew update
            brew install \
                curl \
                wget \
                git \
                cmake \
                protobuf
            log "System dependencies installed ✓"
        else
            warn "Homebrew not found. Please install Homebrew first."
        fi
    fi
}

# Function to install Node.js
install_nodejs() {
    log "Checking Node.js installation..."
    
    if command_exists node; then
        NODE_VERSION=$(node --version | sed 's/v//')
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d. -f1)
        
        if [ "$MAJOR_VERSION" -ge 18 ]; then
            log "Node.js $NODE_VERSION found ✓"
            return
        else
            warn "Node.js version $NODE_VERSION is too old. Installing newer version..."
        fi
    fi
    
    log "Installing Node.js..."
    
    # Install Node.js using NodeSource repository
    if [[ "$OS" == "linux" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [[ "$OS" == "macos" ]]; then
        if command_exists brew; then
            brew install node@20
        else
            # Download and install Node.js directly
            curl -o node.pkg https://nodejs.org/dist/v20.10.0/node-v20.10.0.pkg
            sudo installer -pkg node.pkg -target /
            rm node.pkg
        fi
    fi
    
    # Verify installation
    if command_exists node && command_exists npm; then
        log "Node.js $(node --version) installed ✓"
        log "npm $(npm --version) installed ✓"
    else
        error "Failed to install Node.js"
    fi
}

# Function to install Rust
install_rust() {
    log "Checking Rust installation..."
    
    if command_exists rustc && command_exists cargo; then
        RUST_VERSION=$(rustc --version | awk '{print $2}')
        log "Rust $RUST_VERSION found"
        
        # Check if we have the required toolchain
        if rustup toolchain list | grep -q "1.75.0"; then
            log "Rust 1.75.0 toolchain found ✓"
        else
            log "Installing Rust 1.75.0 toolchain..."
            rustup toolchain install 1.75.0
            rustup component add rustfmt clippy --toolchain 1.75.0
        fi
        
        # Set default toolchain
        rustup default 1.75.0
        log "Rust toolchain set to 1.75.0 ✓"
        return
    fi
    
    log "Installing Rust..."
    
    # Install Rust using rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.75.0
    
    # Source the environment
    source ~/.cargo/env
    
    # Add components
    rustup component add rustfmt clippy
    rustup target add wasm32-unknown-unknown
    
    # Verify installation
    if command_exists rustc && command_exists cargo; then
        log "Rust $(rustc --version | awk '{print $2}') installed ✓"
        log "Cargo $(cargo --version | awk '{print $2}') installed ✓"
    else
        error "Failed to install Rust"
    fi
}

# Function to setup repository
setup_repository() {
    log "Setting up repository..."
    
    REPO_URL="https://github.com/Zeeeepa/bloop.git"
    BRANCH="codegen-bot/upgrade-bloop-local-port-3000-1757524345"
    TARGET_DIR="bloop"
    
    if [ -d "$TARGET_DIR" ]; then
        read -p "Directory '$TARGET_DIR' exists. Remove and re-clone? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$TARGET_DIR"
            log "Removed existing directory ✓"
        else
            log "Using existing directory..."
            cd "$TARGET_DIR"
            git fetch origin
            git checkout "$BRANCH"
            git pull origin "$BRANCH"
            log "Updated existing repository ✓"
            return
        fi
    fi
    
    # Clone repository
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
    
    # Checkout specific branch
    git checkout "$BRANCH"
    
    log "Repository setup completed ✓"
}

# Function to install dependencies
install_dependencies() {
    log "Installing project dependencies..."
    
    # Install Node.js dependencies
    log "Installing Node.js dependencies..."
    npm install
    
    # Install client dependencies if they exist
    if [ -f "client/package.json" ]; then
        log "Installing client dependencies..."
        cd client && npm install && cd ..
    fi
    
    log "Dependencies installed ✓"
}

# Function to create configuration
create_configuration() {
    log "Creating local configuration..."
    
    cat > local_config.json << 'EOF'
{
  "host": "127.0.0.1",
  "port": 7878,
  "model_dir": "./model",
  "index_dir": "./index",
  "max_threads": 4,
  "buffer_size": 10000,
  "answer_api_endpoint": null,
  "disable_log_write": false,
  "log_level": "info",
  "source": {
    "local": {
      "path": "."
    }
  }
}
EOF
    
    log "Local configuration created ✓"
}

# Function to build Rust backend
build_rust_backend() {
    log "Building Rust backend..."
    
    # Clean previous builds
    cd server/bleep
    cargo clean
    
    # Build with retries
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Build attempt $attempt/$max_attempts..."
        
        if cargo build --release; then
            log "Rust backend built successfully ✓"
            cd ../..
            return 0
        else
            warn "Build attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                log "Cleaning and retrying..."
                cargo clean
                # Clean cargo cache for problematic dependencies
                rm -rf ~/.cargo/git/db/llm-*
                rm -rf ~/.cargo/registry/cache
            fi
            ((attempt++))
        fi
    done
    
    cd ../..
    error "Failed to build Rust backend after $max_attempts attempts"
}

# Function to create mock server
create_mock_server() {
    log "Creating mock server..."
    
    cat > mock-server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const app = express();
const port = 7878;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Mock server is running' });
});

// Search endpoint
app.post('/q', (req, res) => {
  res.json({
    data: [
      {
        relative_path: "README.md",
        repo_name: "bloop",
        repo_ref: "main",
        lang: "markdown",
        branches: ["main"],
        indexed: true,
        data: {
          kind: "file_result",
          file_result: {
            path: "README.md",
            repo_name: "bloop",
            repo_ref: "main",
            lang: "markdown",
            branches: ["main"],
            indexed: true,
            hoverables: [],
            symbols: []
          }
        }
      }
    ],
    metadata: {
      total_results: 1
    }
  });
});

// Repository list endpoint
app.get('/repos', (req, res) => {
  res.json([
    {
      name: "bloop",
      ref: "main",
      indexed: true,
      last_index: new Date().toISOString()
    }
  ]);
});

app.listen(port, '127.0.0.1', () => {
  console.log(`Mock server running at http://127.0.0.1:${port}`);
});
EOF
    
    # Install express and cors if not already installed
    if ! npm list express >/dev/null 2>&1; then
        npm install express cors
    fi
    
    log "Mock server created ✓"
}

# Function to start services
start_services() {
    log "Starting services..."
    
    # Ask user for backend preference
    echo
    echo "Choose backend option:"
    echo "1) Rust backend (full functionality)"
    echo "2) Mock server (development/testing)"
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo
    
    if [[ $REPLY == "1" ]]; then
        # Check if Rust backend binary exists
        if [ -f "server/bleep/target/release/bleep" ]; then
            log "Starting Rust backend..."
            cd server/bleep
            ./target/release/bleep --config-file=../../local_config.json &
            BACKEND_PID=$!
            cd ../..
            log "Rust backend started (PID: $BACKEND_PID) ✓"
        else
            error "Rust backend binary not found. Please build first or use mock server."
        fi
    else
        log "Starting mock server..."
        node mock-server.js &
        BACKEND_PID=$!
        log "Mock server started (PID: $BACKEND_PID) ✓"
    fi
    
    # Start frontend
    log "Starting frontend..."
    npm run start-web &
    FRONTEND_PID=$!
    
    # Wait a moment for services to start
    sleep 3
    
    # Display information
    echo
    log "🚀 Bloop is now running!"
    echo
    info "Frontend: http://localhost:3000"
    info "Backend API: http://localhost:7878"
    info "Health Check: http://localhost:7878/health"
    echo
    info "Backend PID: $BACKEND_PID"
    info "Frontend PID: $FRONTEND_PID"
    echo
    info "To stop services:"
    info "  kill $BACKEND_PID $FRONTEND_PID"
    info "  or use: pkill -f 'bleep\\|mock-server\\|vite'"
    echo
    
    # Save PIDs for later cleanup
    echo "$BACKEND_PID" > .backend.pid
    echo "$FRONTEND_PID" > .frontend.pid
    
    log "Services started successfully ✓"
}

# Function to cleanup on exit
cleanup() {
    log "Cleaning up..."
    
    if [ -f ".backend.pid" ]; then
        BACKEND_PID=$(cat .backend.pid)
        kill $BACKEND_PID 2>/dev/null || true
        rm .backend.pid
    fi
    
    if [ -f ".frontend.pid" ]; then
        FRONTEND_PID=$(cat .frontend.pid)
        kill $FRONTEND_PID 2>/dev/null || true
        rm .frontend.pid
    fi
    
    # Kill any remaining processes
    pkill -f 'bleep' 2>/dev/null || true
    pkill -f 'mock-server' 2>/dev/null || true
    pkill -f 'vite' 2>/dev/null || true
    
    log "Cleanup completed"
}

# Trap cleanup on exit
trap cleanup EXIT INT TERM

# Main execution
main() {
    log "🚀 Starting Bloop Complete Installation and Deployment"
    echo
    
    # Check system requirements
    check_system_requirements
    echo
    
    # Install system dependencies
    install_system_dependencies
    echo
    
    # Install Node.js
    install_nodejs
    echo
    
    # Install Rust
    install_rust
    echo
    
    # Setup repository
    setup_repository
    echo
    
    # Install dependencies
    install_dependencies
    echo
    
    # Create configuration
    create_configuration
    echo
    
    # Ask if user wants to build Rust backend
    read -p "Build Rust backend? (y/n, 'n' will create mock server): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if build_rust_backend; then
            log "Rust backend ready ✓"
        else
            warn "Rust backend build failed, creating mock server as fallback"
            create_mock_server
        fi
    else
        create_mock_server
    fi
    echo
    
    # Start services
    start_services
    
    # Keep script running
    log "Press Ctrl+C to stop all services"
    wait
}

# Run main function
main "$@"
