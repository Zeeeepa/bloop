#!/bin/bash

# Bloop Production Installation and Deployment Script
# Comprehensive dependency installer, checker, and production deployer
# NO MOCK SERVERS - PRODUCTION ONLY

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
    log "Building Rust backend (PRODUCTION MODE)..."
    
    # Clean previous builds thoroughly
    cd server/bleep
    cargo clean
    
    # Clean problematic cached dependencies
    log "Cleaning dependency cache..."
    rm -rf ~/.cargo/git/db/llm-* 2>/dev/null || true
    rm -rf ~/.cargo/git/db/tree-sitter-* 2>/dev/null || true
    rm -rf ~/.cargo/registry/cache 2>/dev/null || true
    
    # Build with enhanced retries and better error handling
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Production build attempt $attempt/$max_attempts..."
        
        # Set environment variables for better compilation
        export CARGO_NET_RETRY=10
        export CARGO_HTTP_TIMEOUT=300
        export RUST_BACKTRACE=1
        
        if timeout 1800 cargo build --release --verbose; then
            log "Rust backend built successfully ✓"
            
            # Verify the binary was created
            if [ -f "target/release/bleep" ]; then
                log "Binary verification successful ✓"
                cd ../..
                return 0
            else
                error "Binary not found after successful build"
            fi
        else
            warn "Build attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                log "Deep cleaning and retrying..."
                cargo clean
                
                # More aggressive cache cleaning
                rm -rf ~/.cargo/git/db/* 2>/dev/null || true
                rm -rf ~/.cargo/registry/cache/* 2>/dev/null || true
                rm -rf ~/.cargo/registry/src/* 2>/dev/null || true
                
                # Wait before retry
                sleep 5
            fi
            ((attempt++))
        fi
    done
    
    cd ../..
    error "CRITICAL: Failed to build Rust backend after $max_attempts attempts. This is a production deployment - no fallbacks available."
}

# Function to validate production readiness
validate_production_readiness() {
    log "Validating production readiness..."
    
    # Check if Rust backend binary exists
    if [ ! -f "server/bleep/target/release/bleep" ]; then
        error "CRITICAL: Rust backend binary not found. Production deployment requires successful Rust build."
    fi
    
    # Test binary execution
    if ! ./server/bleep/target/release/bleep --help >/dev/null 2>&1; then
        error "CRITICAL: Rust backend binary is not executable or corrupted."
    fi
    
    # Check configuration file
    if [ ! -f "local_config.json" ]; then
        error "CRITICAL: Configuration file missing."
    fi
    
    # Validate Node.js dependencies
    if ! npm list >/dev/null 2>&1; then
        error "CRITICAL: Node.js dependencies not properly installed."
    fi
    
    log "Production readiness validation passed ✓"
}

# Function to start production services
start_production_services() {
    log "Starting production services..."
    
    # Validate production readiness first
    validate_production_readiness
    
    # Start Rust backend
    log "Starting Rust backend (PRODUCTION)..."
    cd server/bleep
    
    # Start backend with proper logging and error handling
    nohup ./target/release/bleep --config-file=../../local_config.json > ../../backend.log 2>&1 &
    BACKEND_PID=$!
    cd ../..
    
    # Verify backend started successfully
    sleep 5
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        error "CRITICAL: Rust backend failed to start. Check backend.log for details."
    fi
    
    # Test backend health
    local health_check_attempts=0
    while [ $health_check_attempts -lt 30 ]; do
        if curl -s http://127.0.0.1:7878/health >/dev/null 2>&1; then
            log "Backend health check passed ✓"
            break
        fi
        sleep 2
        ((health_check_attempts++))
    done
    
    if [ $health_check_attempts -eq 30 ]; then
        error "CRITICAL: Backend health check failed after 60 seconds"
    fi
    
    log "Rust backend started successfully (PID: $BACKEND_PID) ✓"
    
    # Start frontend
    log "Starting frontend (PRODUCTION)..."
    nohup npm run start-web > frontend.log 2>&1 &
    FRONTEND_PID=$!
    
    # Wait for frontend to start
    sleep 10
    
    # Verify frontend started
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        error "CRITICAL: Frontend failed to start. Check frontend.log for details."
    fi
    
    # Display production information
    echo
    log "🚀 BLOOP PRODUCTION DEPLOYMENT SUCCESSFUL!"
    echo
    info "🌐 Frontend: http://localhost:3000"
    info "🔧 Backend API: http://localhost:7878"
    info "❤️  Health Check: http://localhost:7878/health"
    echo
    info "📊 Process Information:"
    info "   Backend PID: $BACKEND_PID"
    info "   Frontend PID: $FRONTEND_PID"
    echo
    info "📝 Log Files:"
    info "   Backend: $(pwd)/backend.log"
    info "   Frontend: $(pwd)/frontend.log"
    echo
    info "🛑 To stop services:"
    info "   kill $BACKEND_PID $FRONTEND_PID"
    info "   or use: pkill -f 'bleep|vite'"
    echo
    
    # Save PIDs for later cleanup
    echo "$BACKEND_PID" > .backend.pid
    echo "$FRONTEND_PID" > .frontend.pid
    
    log "Production services started successfully ✓"
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
    pkill -f 'vite' 2>/dev/null || true
    
    log "Cleanup completed"
}

# Trap cleanup on exit
trap cleanup EXIT INT TERM

# Main execution
main() {
    log "🚀 Starting Bloop PRODUCTION Installation and Deployment"
    log "⚠️  NO MOCK SERVERS - PRODUCTION ONLY DEPLOYMENT"
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
    
    # Build Rust backend (MANDATORY for production)
    log "Building Rust backend (PRODUCTION REQUIREMENT)..."
    build_rust_backend
    log "Rust backend ready for production ✓"
    echo
    
    # Start production services
    start_production_services
    
    # Keep script running
    log "Press Ctrl+C to stop all services"
    wait
}

# Run main function
main "$@"
