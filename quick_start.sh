#!/bin/bash

# Quick Start Script for Bloop (Frontend + Mock Backend)
# This script skips the Rust compilation and uses a mock backend for faster setup

set -e

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

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

log "🚀 BLOOP QUICK START - Frontend + Mock Backend"
log "⚡ This script provides a fast setup without Rust compilation"

# Check if we're in the bloop directory
if [ ! -f "package.json" ]; then
    error "Please run this script from the bloop repository root directory"
fi

# Install Node.js dependencies
log "📦 Installing Node.js dependencies..."
if ! npm install; then
    error "Failed to install Node.js dependencies"
fi

# Install client dependencies
log "📦 Installing client dependencies..."
cd client
if ! npm install; then
    error "Failed to install client dependencies"
fi
cd ..

# Create mock server if it doesn't exist
if [ ! -f "mock-server.js" ]; then
    log "🔧 Creating mock backend server..."
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

// Mock search endpoint
app.post('/q', (req, res) => {
    res.json({
        data: [
            {
                relative_path: "src/main.rs",
                absolute_path: "/mock/src/main.rs",
                lang: "Rust",
                repo_name: "mock-repo",
                repo_ref: "main",
                branches: ["main"],
                indexed: true,
                data: {
                    kind: "file",
                    content: "fn main() {\n    println!(\"Hello, world!\");\n}",
                    line_end_indices: [0, 12, 42]
                }
            }
        ],
        metadata: {
            total_results: 1,
            page: 0,
            page_size: 20
        }
    });
});

// Mock repository list endpoint
app.get('/repos', (req, res) => {
    res.json([
        {
            name: "mock-repo",
            ref: "main",
            last_commit_unix_secs: Date.now() / 1000,
            last_index_unix_secs: Date.now() / 1000,
            most_common_lang: "Rust"
        }
    ]);
});

// Catch-all for other API endpoints
app.use('/api/*', (req, res) => {
    res.json({ message: 'Mock API endpoint', path: req.path });
});

app.listen(port, '127.0.0.1', () => {
    console.log(`🎭 Mock backend server running at http://127.0.0.1:${port}`);
    console.log(`📊 Health check: http://127.0.0.1:${port}/health`);
});
EOF
fi

# Create local configuration
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

# Start services
log "🚀 Starting services..."

# Start mock backend in background
log "🎭 Starting mock backend server..."
node mock-server.js &
BACKEND_PID=$!

# Wait a moment for backend to start
sleep 2

# Check if backend is running
if ! curl -s http://127.0.0.1:7878/health > /dev/null; then
    warn "Mock backend may not be running properly"
fi

# Start frontend
log "🌐 Starting frontend..."
log "📱 Frontend will be available at: http://localhost:3000"
log "🔧 Backend API available at: http://127.0.0.1:7878"

# Trap to cleanup background processes
trap 'kill $BACKEND_PID 2>/dev/null || true' EXIT

# Start the frontend (this will block)
npm run start-web -- --host 127.0.0.1 --port 3000

# This line will only be reached if the frontend exits
log "👋 Shutting down services..."
kill $BACKEND_PID 2>/dev/null || true
