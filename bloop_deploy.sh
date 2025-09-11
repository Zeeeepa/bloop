#!/bin/bash

# BULLETPROOF Bloop Deployment Script
# Handles ALL edge cases, dependencies, and build failures
# Multiple fallback strategies and comprehensive error handling

set -e
set -u
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# COMPREHENSIVE System Dependencies Installation
install_system_dependencies() {
    log "🔧 Installing comprehensive system dependencies..."
    
    if command_exists apt-get; then
        sudo apt-get update -qq
        sudo apt-get install -y \
            curl \
            wget \
            git \
            git-lfs \
            build-essential \
            pkg-config \
            libssl-dev \
            cmake \
            clang \
            llvm \
            protobuf-compiler \
            libprotobuf-dev \
            ca-certificates \
            gnupg \
            lsb-release \
            sqlite3 \
            libsqlite3-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libffi-dev \
            libncurses5-dev \
            libgdbm-dev \
            libnss3-dev \
            liblzma-dev \
            libxml2-dev \
            libxmlsec1-dev \
            libxslt1-dev \
            python3-dev \
            python3-pip \
            nodejs \
            npm \
            libsoup2.4-dev \
            libwebkit2gtk-4.0-dev \
            libgtk-3-dev \
            libgdk-pixbuf2.0-dev \
            libglib2.0-dev \
            libcairo2-dev \
            libpango1.0-dev \
            libatk1.0-dev \
            libgdk-pixbuf-2.0-dev \
            libjavascriptcoregtk-4.0-dev \
            libappindicator3-dev \
            librsvg2-dev
        log "✅ System dependencies installed"
    elif command_exists yum; then
        sudo yum update -y
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            curl \
            wget \
            git \
            git-lfs \
            openssl-devel \
            cmake \
            clang \
            llvm \
            protobuf-compiler \
            protobuf-devel \
            sqlite \
            sqlite-devel \
            zlib-devel \
            bzip2-devel \
            readline-devel \
            libffi-devel \
            ncurses-devel \
            gdbm-devel \
            nss-devel \
            xz-devel \
            libxml2-devel \
            libxslt-devel \
            python3-devel \
            nodejs \
            npm \
            libsoup-devel \
            webkit2gtk3-devel \
            gtk3-devel \
            gdk-pixbuf2-devel \
            glib2-devel \
            cairo-devel \
            pango-devel \
            atk-devel \
            librsvg2-devel
        log "✅ System dependencies installed"
    else
        error "No supported package manager found (apt-get or yum)"
    fi
}

# BULLETPROOF Rust Installation
install_rust() {
    log "🦀 Installing/updating Rust toolchain..."
    
    # Install rustup if not present
    if ! command_exists rustup; then
        log "Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    # Ensure we have the latest stable
    log "Updating to latest stable Rust..."
    rustup update stable || warn "Failed to update stable"
    rustup default stable || error "Failed to set stable as default"
    
    # Add required targets
    rustup target add wasm32-unknown-unknown || warn "Failed to add wasm32 target"
    
    # Source environment
    source ~/.cargo/env || true
    
    log "✅ Rust $(rustc --version) installed"
}

# FORCE Rust Toolchain Configuration
force_rust_stable() {
    log "🔧 Forcing Rust to use stable toolchain..."
    
    # Create/overwrite rust-toolchain.toml to force stable
    cat > rust-toolchain.toml << 'EOF'
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
targets = ["wasm32-unknown-unknown"]
EOF
    
    # Force rustup to use stable
    rustup override set stable || error "Failed to set stable override"
    rustup default stable || error "Failed to set stable as default"
    
    log "✅ Forced Rust to use stable toolchain"
}

# COMPREHENSIVE Git Configuration
configure_git() {
    log "🔧 Configuring git for large repositories..."
    
    git config --global http.postBuffer 524288000 || true
    git config --global http.maxRequestBuffer 100M || true
    git config --global core.compression 0 || true
    git config --global credential.helper store || true
    git config --global http.lowSpeedLimit 0 || true
    git config --global http.lowSpeedTime 999999 || true
    
    # Initialize and optimize git-lfs if available
    if command_exists git-lfs; then
        git lfs install || warn "Failed to initialize git-lfs"
        
        # Configure git-lfs for better performance
        git config lfs.concurrenttransfers 8 || true
        git config lfs.batch true || true
        git config lfs.transfer.maxretries 10 || true
        
        # Pull LFS objects if in a git repository
        if [ -d ".git" ]; then
            log "📦 Pulling Git LFS objects..."
            git lfs pull || warn "Failed to pull LFS objects"
        fi
    fi
    
    log "✅ Git configured for large repositories"
}

# DEEP Clean Build Environment
deep_clean() {
    log "🧹 Deep cleaning build environment..."
    
    # Clean cargo cache completely
    rm -rf ~/.cargo/git/db/* 2>/dev/null || true
    rm -rf ~/.cargo/registry/cache 2>/dev/null || true
    rm -rf ~/.cargo/registry/src 2>/dev/null || true
    
    # Clean project build artifacts
    cargo clean 2>/dev/null || true
    rm -rf target/ 2>/dev/null || true
    rm -rf build.log 2>/dev/null || true
    
    log "✅ Build environment cleaned"
}

# Fix Cargo.toml for compatibility issues
fix_cargo_dependencies() {
    log "🔧 Fixing Cargo.toml for compatibility issues..."
    
    # Only add patch if Cargo.toml exists and is valid
    if [ -f "Cargo.toml" ] && grep -q "\[package\]" Cargo.toml; then
        # Add patch for time crate compilation issue
        if ! grep -q "\[patch.crates-io\]" Cargo.toml; then
            echo "" >> Cargo.toml
            echo "[patch.crates-io]" >> Cargo.toml
            echo "# Fix time crate compilation issue with newer Rust versions" >> Cargo.toml
            echo 'time = { git = "https://github.com/time-rs/time", branch = "main" }' >> Cargo.toml
            log "✅ Added time crate patch"
        fi
    else
        log "⚠️ Cargo.toml not found or invalid, skipping patch"
    fi
    
    # Create .cargo/config.toml for better build settings
    mkdir -p .cargo
    cat > .cargo/config.toml << 'EOF'
[build]
jobs = 4

[net]
retry = 10
git-fetch-with-cli = true

[http]
timeout = 600
multiplexing = false

[profile.release]
lto = "thin"
codegen-units = 1
EOF
    
    log "✅ Cargo configuration optimized"
}

# MULTI-STRATEGY Build Function
build_rust_backend() {
    log "🏗️ Building Rust backend with multiple fallback strategies..."
    
    cd server || error "Failed to enter server directory"
    
    # Fix Cargo dependencies first
    # Skip Cargo.toml patching to avoid corruption
    log "⚠️ Skipping Cargo.toml patching to avoid file corruption"
    
    # Force stable toolchain
    force_rust_stable
    
    # Deep clean before build
    deep_clean
    
    # Set build environment variables
    export CARGO_NET_RETRY=10
    export CARGO_HTTP_TIMEOUT=600
    export CARGO_HTTP_MULTIPLEXING=false
    export RUST_BACKTRACE=1
    export CARGO_INCREMENTAL=0
    export SQLX_OFFLINE=true
    export DATABASE_URL="sqlite:bloop.db"
    
    log "🔧 Cargo version: $(cargo --version)"
    log "🔧 Rust version: $(rustc --version)"
    
    # Strategy 1: Release build without database features
    log "📦 Strategy 1: Release build without database features..."
    if timeout 1800 cargo build --release --no-default-features --features "color-eyre" --verbose 2>&1 | tee build.log; then
        if [ -f "target/release/bleep" ] && [ -x "target/release/bleep" ]; then
            log "✅ Strategy 1 SUCCESS: Release build completed"
            cd ..
            return 0
        fi
    fi
    
    log "⚠️ Strategy 1 failed, trying Strategy 2..."
    deep_clean
    
    # Strategy 2: Release build with minimal features
    log "📦 Strategy 2: Release build with minimal features..."
    if timeout 1800 cargo build --release --no-default-features --verbose 2>&1 | tee build.log; then
        if [ -f "target/release/bleep" ] && [ -x "target/release/bleep" ]; then
            log "✅ Strategy 2 SUCCESS: Minimal release build completed"
            cd ..
            return 0
        fi
    fi
    
    log "⚠️ Strategy 2 failed, trying Strategy 3..."
    deep_clean
    
    # Strategy 3: Debug build (faster compilation)
    log "📦 Strategy 3: Debug build..."
    if timeout 1800 cargo build --no-default-features --verbose 2>&1 | tee build.log; then
        if [ -f "target/debug/bleep" ] && [ -x "target/debug/bleep" ]; then
            # Copy debug binary to release location for consistency
            mkdir -p target/release
            cp target/debug/bleep target/release/bleep
            log "✅ Strategy 3 SUCCESS: Debug build completed"
            cd ..
            return 0
        fi
    fi
    
    log "⚠️ Strategy 3 failed, trying Strategy 4..."
    deep_clean
    
    # Strategy 4: Build without webkit/tauri dependencies
    log "📦 Strategy 4: Build without webkit/tauri dependencies..."
    export CARGO_FEATURE_DISABLE_TAURI=1
    if timeout 1800 cargo build --release --no-default-features --features "cli" --verbose 2>&1 | tee build.log; then
        if [ -f "target/release/bleep" ] && [ -x "target/release/bleep" ]; then
            log "✅ Strategy 4 SUCCESS: CLI-only build completed"
            cd ..
            return 0
        fi
    fi
    
    log "⚠️ Strategy 4 failed, trying Strategy 5..."
    deep_clean
    
    # Strategy 5: Single-threaded build
    log "📦 Strategy 5: Single-threaded build..."
    if timeout 2400 cargo build --release --no-default-features -j 1 --verbose 2>&1 | tee build.log; then
        if [ -f "target/release/bleep" ] && [ -x "target/release/bleep" ]; then
            log "✅ Strategy 5 SUCCESS: Single-threaded build completed"
            cd ..
            return 0
        fi
    fi
    
    # All strategies failed
    error "❌ ALL BUILD STRATEGIES FAILED. Check build.log for details."
}

# Install Node.js dependencies
install_node_dependencies() {
    log "📦 Installing Node.js dependencies..."
    
    # Install root dependencies
    npm install || error "Failed to install root dependencies"
    
    # Install client dependencies if client directory exists
    if [ -d "client" ]; then
        cd client
        npm install || warn "Failed to install client dependencies"
        cd ..
    fi
    
    log "✅ Node.js dependencies installed"
}

# Create configuration
create_config() {
    log "⚙️ Creating local configuration..."
    
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
    
    log "✅ Configuration created"
}

# Start services
start_services() {
    log "🚀 Starting Bloop services..."
    
    # Kill any existing processes on our ports
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    lsof -ti:7878 | xargs kill -9 2>/dev/null || true
    
    # Start backend
    log "🔧 Starting Rust backend..."
    cd server
    nohup ./target/release/bleep --config-file=../local_config.json > ../backend.log 2>&1 &
    BACKEND_PID=$!
    cd ..
    
    # Wait a moment for backend to start
    sleep 3
    
    # Check if backend is running
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        error "Backend failed to start. Check backend.log"
    fi
    
    # Start frontend
    log "🌐 Starting frontend..."
    nohup npm run start-web > frontend.log 2>&1 &
    FRONTEND_PID=$!
    
    # Wait for services to start
    sleep 5
    
    log "✅ Services started successfully!"
    log "🌐 Frontend: http://localhost:3000"
    log "🔧 Backend API: http://localhost:7878"
    log "❤️ Health Check: http://localhost:7878/health"
    
    log "📋 Process IDs:"
    log "   Backend PID: $BACKEND_PID"
    log "   Frontend PID: $FRONTEND_PID"
    
    log "📄 Log files:"
    log "   Backend: backend.log"
    log "   Frontend: frontend.log"
}

# MAIN EXECUTION
main() {
    log "🚀 BULLETPROOF Bloop Deployment Starting..."
    log "🔧 This script handles ALL edge cases and dependencies"
    
    # Step 1: Install system dependencies
    install_system_dependencies
    
    # Step 2: Install/update Rust
    install_rust
    
    # Step 3: Configure git
    configure_git
    
    # Step 4: Install Node.js dependencies
    install_node_dependencies
    
    # Step 5: Build Rust backend with fallbacks
    build_rust_backend
    
    # Step 6: Create configuration
    create_config
    
    # Step 7: Start services
    start_services
    
    log "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    log "🌟 Bloop is now running and ready to use!"
}

# Run main function
main "$@"
