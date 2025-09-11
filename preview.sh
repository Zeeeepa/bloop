#!/bin/bash

# BLOOP PREVIEW SCRIPT
# Quick startup for bloop UI and backend

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    log "⏳ Waiting for $name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            log "✅ $name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done
    
    warn "$name didn't start within $max_attempts seconds"
    return 1
}

# Main preview function
main() {
    log "🚀 BLOOP PREVIEW - Starting services..."
    
    # Check if we're in the right directory
    if [ ! -f "package.json" ] || [ ! -d "server" ]; then
        error "Not in bloop directory. Run from bloop root directory."
    fi
    
    # Kill any existing processes on our ports
    log "🧹 Cleaning up existing processes..."
    if check_port 3000; then
        warn "Port 3000 is in use, killing processes..."
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    if check_port 7878; then
        warn "Port 7878 is in use, killing processes..."
        lsof -ti:7878 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Check if backend binary exists
    log "🔍 Checking for backend binary..."
    cd server
    
    BINARY=""
    if [ -f "target/release/bleep" ]; then
        BINARY="target/release/bleep"
        info "Found release binary"
    elif [ -f "target/debug/bleep" ]; then
        BINARY="target/debug/bleep"
        info "Found debug binary"
    else
        error "No bleep binary found. Run setup.sh first to build the project."
    fi
    
    # Check if config exists
    cd ..
    if [ ! -f "local_config.json" ]; then
        log "📝 Creating default configuration..."
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
    fi
    
    # Start backend
    log "🔧 Starting Rust backend..."
    cd server
    nohup ./$BINARY --config-file=../local_config.json > ../backend.log 2>&1 &
    BACKEND_PID=$!
    cd ..
    
    # Wait for backend to be ready
    if wait_for_service "http://localhost:7878/health" "Backend"; then
        log "✅ Backend started successfully (PID: $BACKEND_PID)"
    else
        error "Backend failed to start. Check backend.log for details."
    fi
    
    # Start frontend
    log "🌐 Starting frontend..."
    nohup npm run start-web > frontend.log 2>&1 &
    FRONTEND_PID=$!
    
    # Wait for frontend to be ready
    if wait_for_service "http://localhost:3000" "Frontend"; then
        log "✅ Frontend started successfully (PID: $FRONTEND_PID)"
    else
        warn "Frontend may still be starting. Check frontend.log for details."
    fi
    
    # Display status
    echo ""
    log "🎉 BLOOP IS RUNNING!"
    echo ""
    echo "🌐 Frontend: http://localhost:3000"
    echo "🔧 Backend API: http://localhost:7878"
    echo "❤️ Health Check: http://localhost:7878/health"
    echo ""
    echo "📋 Process Information:"
    echo "   Backend PID: $BACKEND_PID"
    echo "   Frontend PID: $FRONTEND_PID"
    echo ""
    echo "📄 Log Files:"
    echo "   Backend: backend.log"
    echo "   Frontend: frontend.log"
    echo ""
    echo "🛑 To stop services:"
    echo "   kill $BACKEND_PID $FRONTEND_PID"
    echo "   or use: pkill -f bleep && pkill -f 'npm.*start-web'"
    echo ""
    
    # Check if services are actually running
    sleep 2
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        error "Backend process died. Check backend.log"
    fi
    
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        warn "Frontend process may have issues. Check frontend.log"
    fi
    
    # Option to show logs
    echo "📊 Options:"
    echo "   1. Press Enter to show live logs"
    echo "   2. Press Ctrl+C to exit and run in background"
    echo ""
    
    read -t 10 -p "Show logs? (auto-continue in 10s): " choice || true
    
    if [[ "$choice" != "n" && "$choice" != "no" ]]; then
        log "📊 Showing live logs (Ctrl+C to exit)..."
        echo ""
        tail -f backend.log frontend.log 2>/dev/null || {
            warn "Could not tail logs. Services are running in background."
            log "Use 'tail -f backend.log frontend.log' to view logs manually."
        }
    else
        log "🎯 Services running in background. Access at http://localhost:3000"
    fi
}

# Handle Ctrl+C gracefully
trap 'echo ""; log "👋 Exiting preview. Services continue running in background."; exit 0' INT

# Run main function
main "$@"

