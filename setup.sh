#!/bin/bash

# BLOOP COMPLETE SETUP SCRIPT
# One-command deployment for bloop code search engine
# Handles all dependencies, builds, and configuration

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

# Main setup function
main() {
    log "🚀 BLOOP COMPLETE SETUP - Starting deployment..."
    
    # Step 1: Clone repository if not exists
    if [ ! -d "bloop" ]; then
        log "📥 Cloning bloop repository..."
        git clone https://github.com/Zeeeepa/bloop.git || error "Failed to clone repository"
        cd bloop
        git checkout codegen-bot/upgrade-bloop-local-port-3000-1757524345 || warn "Branch not found, using current branch"
    else
        log "📁 Using existing bloop directory..."
        cd bloop
    fi
    
    # Step 2: Choose deployment option
    log "🚀 Choose your deployment option:"
    echo "1. Full deployment (Rust backend + Frontend) - Production ready but slower"
    echo "2. Quick start (Mock backend + Frontend) - Fast setup for development"
    echo ""
    read -p "Enter your choice (1 or 2): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[1]$ ]]; then
        if [ -f "bloop_deploy.sh" ]; then
            log "🏗️ Running full deployment with Rust backend..."
            chmod +x bloop_deploy.sh
            ./bloop_deploy.sh || error "Deployment script failed"
        else
            error "bloop_deploy.sh not found in repository"
        fi
    elif [[ $REPLY =~ ^[2]$ ]]; then
        if [ -f "quick_start.sh" ]; then
            log "⚡ Running quick deployment with mock backend..."
            chmod +x quick_start.sh
            # For setup, we just want to prepare, not run the server
            log "📦 Installing Node.js dependencies..."
            npm install || error "Failed to install Node.js dependencies"
            cd client && npm install && cd .. || error "Failed to install client dependencies"
            log "✅ Quick start setup completed"
        else
            error "quick_start.sh not found in repository"
        fi
    else
        error "Invalid choice. Please run the script again and choose 1 or 2."
    fi
    
    # Step 3: Verify installation
    log "✅ Verifying installation..."
    
    if [[ $REPLY =~ ^[1]$ ]]; then
        if [ -f "server/bleep/target/release/bleep" ] || [ -f "server/bleep/target/debug/bleep" ]; then
            log "✅ Backend binary found"
        else
            error "Backend binary not found"
        fi
    else
        log "✅ Mock backend setup (no binary needed)"
    fi
    
    if [ -f "package.json" ]; then
        log "✅ Frontend package.json found"
    else
        error "Frontend package.json not found"
    fi
    
    # Step 4: Create startup scripts
    log "📝 Creating startup scripts..."
    
    # Create preview.sh if it doesn't exist
    if [ ! -f "preview.sh" ]; then
        cat > preview.sh << 'EOF'
#!/bin/bash

# BLOOP PREVIEW SCRIPT
# Quick startup for bloop UI and backend

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Kill any existing processes on our ports
log "🧹 Cleaning up existing processes..."
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:7878 | xargs kill -9 2>/dev/null || true

# Start backend
log "🔧 Starting Rust backend..."
cd server

# Find the binary (release or debug)
if [ -f "target/release/bleep" ]; then
    BINARY="target/release/bleep"
elif [ -f "target/debug/bleep" ]; then
    BINARY="target/debug/bleep"
else
    error "No bleep binary found. Run setup.sh first."
fi

# Start backend in background
nohup ./$BINARY --config-file=../local_config.json > ../backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait for backend to start
log "⏳ Waiting for backend to start..."
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
log "⏳ Waiting for services to initialize..."
sleep 5

# Display status
log "🎉 BLOOP IS RUNNING!"
echo ""
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:7878"
echo "❤️ Health Check: http://localhost:7878/health"
echo ""
echo "📋 Process IDs:"
echo "   Backend PID: $BACKEND_PID"
echo "   Frontend PID: $FRONTEND_PID"
echo ""
echo "📄 Log files:"
echo "   Backend: backend.log"
echo "   Frontend: frontend.log"
echo ""
echo "🛑 To stop: kill $BACKEND_PID $FRONTEND_PID"
echo ""

# Keep script running to show logs
log "📊 Showing live logs (Ctrl+C to exit)..."
tail -f backend.log frontend.log
EOF
        chmod +x preview.sh
        log "✅ Created preview.sh"
    fi
    
    # Step 5: Final success message
    log "🎉 SETUP COMPLETED SUCCESSFULLY!"
    echo ""
    if [[ $REPLY =~ ^[1]$ ]]; then
        echo "🚀 NEXT STEPS (Full Deployment):"
        echo "   1. Run: ./preview.sh"
        echo "   2. Open: http://localhost:3000"
        echo "   3. Enjoy bloop code search with Rust backend!"
        echo ""
        echo "📁 Files created:"
        echo "   - bloop_deploy.sh (deployment script)"
        echo "   - preview.sh (startup script)"
        echo "   - local_config.json (configuration)"
    else
        echo "🚀 NEXT STEPS (Quick Start):"
        echo "   1. Run: ./quick_start.sh"
        echo "   2. Open: http://localhost:3000"
        echo "   3. Enjoy bloop code search with mock backend!"
        echo ""
        echo "📁 Files created:"
        echo "   - quick_start.sh (quick startup script)"
        echo "   - mock-server.js (mock backend)"
        echo "   - local_config.json (configuration)"
    fi
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   - Check backend.log for backend issues"
    echo "   - Check frontend.log for frontend issues"
    echo "   - Re-run setup.sh if needed"
}

# Run main function
main "$@"
