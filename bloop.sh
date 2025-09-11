#!/bin/bash

# Enhanced Bloop Deployment Script
# Version: 2.0
# Description: Comprehensive deployment script for bloop code search engine

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/Zeeeepa/bloop.git"
BRANCH_NAME="codegen-bot/upgrade-bloop-local-port-3000-1757524345"
PROJECT_DIR="bloop"
FRONTEND_PORT=3000
BACKEND_PORT=7878
LOG_FILE="bloop_deployment.log"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    local exit_code=$?
    log_error "Script failed at line $1 with exit code $exit_code"
    log_error "Command: $2"
    log_error "Check $LOG_FILE for detailed logs"
    exit $exit_code
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# System requirements check
check_system_requirements() {
    log "Checking system requirements..."
    
    local missing_deps=()
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("nodejs")
    else
        local node_version=$(node --version | sed 's/v//')
        local required_version="16.0.0"
        if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
            log_warn "Node.js version $node_version found, but $required_version+ recommended"
        else
            log "Node.js version $node_version ✓"
        fi
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    else
        log "npm $(npm --version) ✓"
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    else
        log "git $(git --version | cut -d' ' -f3) ✓"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # Check build tools
    local build_tools=("clang" "cmake" "pkg-config")
    for tool in "${build_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check for protobuf compiler
    if ! command -v protoc &> /dev/null; then
        missing_deps+=("protobuf-compiler")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies:"
        log_info "Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        log_info "macOS: brew install ${missing_deps[*]}"
        exit 1
    fi
    
    log "All system requirements satisfied ✓"
}

# Install Rust if needed
install_rust() {
    if command -v rustc &> /dev/null; then
        log "Rust $(rustc --version | cut -d' ' -f2) already installed ✓"
        return 0
    fi
    
    log "Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    
    # Source Rust environment
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # Verify installation
    if command -v rustc &> /dev/null; then
        log "Rust $(rustc --version | cut -d' ' -f2) installed successfully ✓"
    else
        log_error "Rust installation failed"
        exit 1
    fi
}

# Setup git configuration for dependency resolution
setup_git_config() {
    log "Configuring git for dependency resolution..."
    
    # Configure git to use CLI for authentication
    git config --global --replace-all url."https://github.com/".insteadOf "git@github.com:" || true
    git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" || true
    
    # Enable git CLI for cargo
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
    
    log "Git configuration completed ✓"
}

# Install git-lfs if available
setup_git_lfs() {
    if command -v git-lfs &> /dev/null; then
        log "Setting up Git LFS..."
        git lfs install
        log "Git LFS configured ✓"
    else
        log_warn "Git LFS not available, skipping LFS setup"
    fi
}

# Clone or update repository
setup_repository() {
    log "Setting up repository..."
    
    if [ -d "$PROJECT_DIR" ]; then
        read -p "The '$PROJECT_DIR' directory already exists. Do you want to remove and re-clone it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Removing existing directory..."
            rm -rf "$PROJECT_DIR"
        else
            log "Using existing directory..."
            cd "$PROJECT_DIR"
            git fetch origin || log_warn "Failed to fetch from origin"
            return 0
        fi
    fi
    
    log "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Try to checkout the specific branch, fallback to default
    if git checkout "$BRANCH_NAME" 2>/dev/null; then
        log "Checked out branch: $BRANCH_NAME ✓"
    else
        log_warn "Branch $BRANCH_NAME not found, using default branch"
        git checkout "$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
    fi
    
    # Pull LFS objects if git-lfs is available
    if command -v git-lfs &> /dev/null; then
        log "Pulling Git LFS objects..."
        git lfs pull || log_warn "Failed to pull LFS objects, continuing..."
    fi
    
    log "Repository setup completed ✓"
}

# Install Node.js dependencies
install_node_dependencies() {
    log "Installing Node.js dependencies..."
    
    # Install root dependencies
    npm install || {
        log_warn "npm install failed, trying with legacy peer deps..."
        npm install --legacy-peer-deps
    }
    
    # Install client dependencies
    if [ -d "client" ]; then
        log "Installing client dependencies..."
        cd client
        npm install || npm install --legacy-peer-deps
        cd ..
    fi
    
    log "Node.js dependencies installed ✓"
}

# Create local configuration
create_local_config() {
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

# Build Rust backend
build_rust_backend() {
    log "Building Rust backend..."
    
    cd server/bleep
    
    # Set environment variables for build
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
    export RUSTFLAGS="-C target-cpu=native"
    
    # Try to build with retries
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if cargo build --release; then
            log "Rust backend built successfully ✓"
            cd ../..
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warn "Build attempt $retry_count failed, retrying..."
            
            if [ $retry_count -lt $max_retries ]; then
                # Clean and retry
                cargo clean
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to build Rust backend after $max_retries attempts"
    cd ../..
    return 1
}

# Create mock server as fallback
create_mock_server() {
    log "Creating mock server as fallback..."
    
    cat > mock-server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const app = express();
const port = 7878;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Mock server running' });
});

// Mock search endpoint
app.post('/q', (req, res) => {
  res.json({
    data: [],
    metadata: { total: 0 },
    message: 'Mock server - no real search results'
  });
});

// Mock repository endpoints
app.get('/repos', (req, res) => {
  res.json([]);
});

app.listen(port, '127.0.0.1', () => {
  console.log(`Mock server running at http://127.0.0.1:${port}`);
});
EOF
    
    # Install express and cors if not already installed
    if ! npm list express &> /dev/null; then
        npm install express cors
    fi
    
    log "Mock server created ✓"
}

# Check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

# Kill processes on port
kill_port_processes() {
    local port=$1
    log "Killing processes on port $port..."
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
    sleep 2
}

# Start services
start_services() {
    log "Starting services..."
    
    # Check and handle port conflicts
    if ! check_port $BACKEND_PORT; then
        log_warn "Port $BACKEND_PORT is busy"
        read -p "Kill existing processes on port $BACKEND_PORT? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill_port_processes $BACKEND_PORT
        fi
    fi
    
    if ! check_port $FRONTEND_PORT; then
        log_warn "Port $FRONTEND_PORT is busy"
        read -p "Kill existing processes on port $FRONTEND_PORT? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill_port_processes $FRONTEND_PORT
        fi
    fi
    
    # Choose backend type
    echo
    echo "Choose backend option:"
    echo "1) Rust backend (full functionality)"
    echo "2) Mock server (development/testing)"
    read -p "Enter choice (1 or 2): " -n 1 -r backend_choice
    echo
    
    case $backend_choice in
        1)
            log "Starting Rust backend..."
            if [ -f "server/bleep/target/release/bleep" ]; then
                cd server/bleep
                nohup ./target/release/bleep --config-file=../../local_config.json > ../../backend.log 2>&1 &
                BACKEND_PID=$!
                cd ../..
                echo $BACKEND_PID > backend.pid
                log "Rust backend started with PID $BACKEND_PID"
            else
                log_error "Rust backend binary not found. Please build first or use mock server."
                return 1
            fi
            ;;
        2)
            log "Starting mock server..."
            nohup node mock-server.js > backend.log 2>&1 &
            BACKEND_PID=$!
            echo $BACKEND_PID > backend.pid
            log "Mock server started with PID $BACKEND_PID"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Wait for backend to start
    sleep 3
    
    # Verify backend is running
    if curl -s "http://127.0.0.1:$BACKEND_PORT/health" > /dev/null; then
        log "Backend health check passed ✓"
    else
        log_warn "Backend health check failed, but continuing..."
    fi
    
    # Start frontend
    log "Starting frontend..."
    nohup npm run start-web > frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > frontend.pid
    log "Frontend started with PID $FRONTEND_PID"
    
    # Wait for frontend to start
    sleep 5
    
    log "Services started successfully ✓"
}

# Health check
perform_health_check() {
    log "Performing health checks..."
    
    # Check backend
    if curl -s "http://127.0.0.1:$BACKEND_PORT/health" > /dev/null; then
        log "Backend health check: ✓"
    else
        log_warn "Backend health check: ✗"
    fi
    
    # Check frontend (just check if port is listening)
    if check_port $FRONTEND_PORT; then
        log_warn "Frontend health check: ✗ (port not listening)"
    else
        log "Frontend health check: ✓"
    fi
}

# Display final information
show_final_info() {
    echo
    log "🎉 Bloop deployment completed!"
    echo
    echo "📊 Service Information:"
    echo "  Frontend: http://localhost:$FRONTEND_PORT"
    echo "  Backend API: http://localhost:$BACKEND_PORT"
    echo "  Health Check: http://localhost:$BACKEND_PORT/health"
    echo
    echo "📁 Log Files:"
    echo "  Deployment: $LOG_FILE"
    echo "  Backend: backend.log"
    echo "  Frontend: frontend.log"
    echo
    echo "🔧 Process Management:"
    echo "  Backend PID: $(cat backend.pid 2>/dev/null || echo 'Not found')"
    echo "  Frontend PID: $(cat frontend.pid 2>/dev/null || echo 'Not found')"
    echo
    echo "🛠️ Troubleshooting:"
    echo "  - Check logs if services don't start properly"
    echo "  - Use 'kill \$(cat backend.pid)' to stop backend"
    echo "  - Use 'kill \$(cat frontend.pid)' to stop frontend"
    echo "  - Re-run script to restart services"
    echo
    echo "🌐 WSL2 Notes:"
    echo "  - Ports are automatically forwarded to Windows"
    echo "  - Allow Node.js through Windows Firewall if prompted"
    echo "  - Keep files in WSL2 filesystem for better performance"
    echo
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    if [ -f backend.pid ]; then
        kill "$(cat backend.pid)" 2>/dev/null || true
        rm -f backend.pid
    fi
    if [ -f frontend.pid ]; then
        kill "$(cat frontend.pid)" 2>/dev/null || true
        rm -f frontend.pid
    fi
}

# Signal handlers
trap cleanup EXIT INT TERM

# Main execution
main() {
    log "Starting Bloop deployment script v2.0"
    log "Deployment started at $(date)"
    
    # Step 1: Check system requirements
    check_system_requirements
    
    # Step 2: Install Rust if needed
    read -p "Install/update Rust toolchain? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_rust
    fi
    
    # Step 3: Setup git configuration
    setup_git_config
    
    # Step 4: Setup git-lfs
    setup_git_lfs
    
    # Step 5: Setup repository
    setup_repository
    
    # Step 6: Install Node.js dependencies
    install_node_dependencies
    
    # Step 7: Create local configuration
    create_local_config
    
    # Step 8: Build Rust backend or create mock server
    read -p "Build Rust backend? (y/n, 'n' will create mock server): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! build_rust_backend; then
            log_warn "Rust backend build failed, creating mock server as fallback"
            create_mock_server
        fi
    else
        create_mock_server
    fi
    
    # Step 9: Start services
    start_services
    
    # Step 10: Perform health checks
    sleep 5
    perform_health_check
    
    # Step 11: Show final information
    show_final_info
    
    log "Deployment completed successfully!"
}

# Run main function
main "$@"

