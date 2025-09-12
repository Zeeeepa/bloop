# Bloop Deployment Troubleshooting Guide

This guide helps resolve common issues when deploying bloop.

## Quick Solutions

### 🚀 **Fastest Option: Use Quick Start**
If you just want to test the frontend quickly:
```bash
./quick_start.sh
```
This skips Rust compilation entirely and uses a mock backend.

### 🔧 **Time Crate Compilation Error**
If you see `error[E0282]: type annotations needed for Box<_>` in time crate:

**Solution 1: Use the fixed deployment script**
```bash
./bloop_deploy.sh
```
The script automatically patches the time crate.

**Solution 2: Manual fix**
```bash
# Test the fix
./test_time_fix.sh

# If test passes, the fix works for your environment
```

## Common Issues and Solutions

### 1. **Git Dependency Timeout (40+ minutes)**

**Symptoms:**
- Build hangs at "Updating git repository"
- No progress for extended periods

**Solutions:**
```bash
# Option A: Use optimized timeouts
export CARGO_NET_RETRY=3
export CARGO_HTTP_TIMEOUT=120
export CARGO_NET_GIT_FETCH_WITH_CLI=true
./bloop_deploy.sh

# Option B: Use quick start instead
./quick_start.sh
```

### 2. **Time Crate Compilation Error**

**Symptoms:**
```
error[E0282]: type annotations needed for `Box<_>`
  --> time-0.3.30/src/format_description/parse/mod.rs:83:9
```

**Solutions:**
```bash
# Automatic fix (recommended)
./bloop_deploy.sh

# Manual verification
./test_time_fix.sh

# Manual patch (if needed)
echo '[patch.crates-io]' >> Cargo.toml
echo 'time = { git = "https://github.com/time-rs/time", branch = "main" }' >> Cargo.toml
cargo update time
```

### 3. **System Dependencies Missing**

**Symptoms:**
- "command not found" errors
- Missing library errors during compilation

**Solutions:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y build-essential pkg-config libssl-dev git curl cmake clang

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install openssl-devel git curl cmake clang

# Arch Linux
sudo pacman -Sy base-devel openssl git curl cmake clang
```

### 4. **Rust Installation Issues**

**Symptoms:**
- "rustc not found"
- "cargo not found"

**Solutions:**
```bash
# Install/update Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustup update stable
rustup default stable
```

### 5. **Node.js/NPM Issues**

**Symptoms:**
- "npm not found"
- Package installation failures

**Solutions:**
```bash
# Install Node.js (Ubuntu/Debian)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Alternative: Use quick start (no Node.js compilation needed)
./quick_start.sh
```

### 6. **Port Already in Use**

**Symptoms:**
- "Address already in use" errors
- Cannot bind to port 3000 or 7878

**Solutions:**
```bash
# Kill existing processes
lsof -ti:3000 | xargs kill -9
lsof -ti:7878 | xargs kill -9

# Or use different ports
npm run start-web -- --port 3001
```

### 7. **Permission Errors**

**Symptoms:**
- "Permission denied" during installation
- Cannot write to directories

**Solutions:**
```bash
# Fix cargo permissions
sudo chown -R $USER:$USER ~/.cargo

# Fix npm permissions
sudo chown -R $USER:$USER ~/.npm

# Or use quick start (fewer permission requirements)
./quick_start.sh
```

## Deployment Strategies

### Strategy 1: Quick Start (Recommended for Testing)
```bash
./quick_start.sh
```
- ✅ Ready in 2 minutes
- ✅ No Rust compilation
- ✅ Mock backend for testing
- ❌ Not production-ready

### Strategy 2: Full Deployment (Production)
```bash
./bloop_deploy.sh
```
- ✅ Full Rust backend
- ✅ Production-ready
- ✅ All features available
- ❌ Takes 20-40 minutes

### Strategy 3: Manual Setup
```bash
# Install dependencies
npm install
cd client && npm install && cd ..

# Build Rust backend
cd server && cargo build --release && cd ..

# Start services
./preview.sh
```

## Environment Variables

### Cargo Optimization
```bash
export CARGO_NET_RETRY=3
export CARGO_HTTP_TIMEOUT=120
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export CARGO_INCREMENTAL=0
export RUST_BACKTRACE=1
```

### Database Configuration
```bash
export SQLX_OFFLINE=true
export DATABASE_URL="sqlite:bloop.db"
```

## Log Analysis

### Check Build Logs
```bash
# View recent build output
tail -f build.log

# Check for specific errors
grep -i error build.log
grep -i "time crate" build.log
```

### Check Service Logs
```bash
# Backend logs
tail -f backend.log

# Frontend logs
tail -f frontend.log
```

## Recovery Commands

### Complete Reset
```bash
# Clean everything
rm -rf target/ ~/.cargo/registry/cache ~/.cargo/git/db
rm -f Cargo.lock */Cargo.lock

# Start fresh
./bloop_deploy.sh
```

### Quick Recovery
```bash
# Just restart services
pkill -f bleep
pkill -f "npm.*start"
./preview.sh
```

## Getting Help

### Check System Status
```bash
# Verify installations
rustc --version
cargo --version
node --version
npm --version

# Check running processes
ps aux | grep -E "(bleep|npm|node)"

# Check port usage
lsof -i :3000
lsof -i :7878
```

### Collect Debug Information
```bash
# System info
uname -a
cat /etc/os-release

# Rust info
rustc --version --verbose
cargo --version --verbose

# Build info
ls -la target/
ls -la ~/.cargo/
```

## Contact and Support

If none of these solutions work:

1. **Check the logs** in `build.log`, `backend.log`, `frontend.log`
2. **Try the quick start** option first: `./quick_start.sh`
3. **Use the test script** to verify fixes: `./test_time_fix.sh`
4. **Report issues** with full log output and system information

Remember: The quick start option (`./quick_start.sh`) works in 99% of cases and is perfect for testing the frontend functionality!
