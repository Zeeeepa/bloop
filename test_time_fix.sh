#!/bin/bash

# Test script to verify the time crate fix is working
# This script creates a minimal Rust project to test time crate compilation

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

log "🧪 Testing time crate compilation fix..."

# Create a temporary test project
TEST_DIR="time_test_$(date +%s)"
mkdir "$TEST_DIR"
cd "$TEST_DIR"

# Create a minimal Cargo.toml with time dependency
cat > Cargo.toml << 'EOF'
[package]
name = "time-test"
version = "0.1.0"
edition = "2021"

[dependencies]
time = { version = "0.3", features = ["macros", "formatting", "parsing"] }

[patch.crates-io]
# Fix time crate compilation issue with newer Rust versions
time = { git = "https://github.com/time-rs/time", branch = "main" }
EOF

# Create a simple main.rs that uses time crate
cat > src/main.rs << 'EOF'
use time::{format_description, OffsetDateTime};

fn main() {
    let now = OffsetDateTime::now_utc();
    let format = format_description::parse("[year]-[month]-[day] [hour]:[minute]:[second]").unwrap();
    let formatted = now.format(&format).unwrap();
    println!("Current time: {}", formatted);
    println!("Time crate compilation test: SUCCESS");
}
EOF

# Create src directory
mkdir -p src

# Create the main.rs file again (in case mkdir didn't work)
cat > src/main.rs << 'EOF'
use time::{format_description, OffsetDateTime};

fn main() {
    let now = OffsetDateTime::now_utc();
    let format = format_description::parse("[year]-[month]-[day] [hour]:[minute]:[second]").unwrap();
    let formatted = now.format(&format).unwrap();
    println!("Current time: {}", formatted);
    println!("Time crate compilation test: SUCCESS");
}
EOF

log "📦 Created test project with time crate dependency"

# Test compilation
log "🔨 Testing compilation..."
if cargo build --release; then
    log "✅ Time crate compilation test PASSED"
    
    # Run the test program
    log "🚀 Running test program..."
    if cargo run --release; then
        log "✅ Time crate runtime test PASSED"
    else
        warn "Time crate compiled but runtime test failed"
    fi
else
    error "Time crate compilation test FAILED"
fi

# Cleanup
cd ..
rm -rf "$TEST_DIR"

log "🎉 Time crate fix verification completed successfully!"
