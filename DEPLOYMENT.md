# Bloop Deployment Guide

## Enhanced Deployment Script v2.0

This comprehensive deployment script (`bloop.sh`) provides a robust, production-ready way to deploy and run the bloop code search engine locally.

## Features

### 🔍 **Pre-flight System Validation**
- Checks for all required system dependencies
- Validates Node.js version compatibility
- Ensures build tools are available
- Provides clear installation instructions for missing dependencies

### 🛠️ **Intelligent Dependency Management**
- Automatic Rust toolchain installation
- Git configuration for dependency resolution
- Git LFS setup when available
- Handles authentication issues with tree-sitter dependencies

### 📁 **Smart Repository Management**
- Clones from the correct repository and branch
- Handles existing directory conflicts
- Automatic fallback to default branch if specified branch unavailable
- Git LFS object pulling when available

### 🏗️ **Robust Build Process**
- Multi-stage build with proper error handling
- Retry mechanisms for failed builds
- Environment variable configuration
- Fallback to mock server if Rust build fails

### ⚙️ **Configuration Management**
- Automatic local configuration generation
- Port conflict detection and resolution
- Service management with PID tracking
- Health check endpoints

### 📊 **Comprehensive Logging**
- Colored output for better readability
- Detailed log files for troubleshooting
- Progress indicators for long operations
- Error tracking with line numbers

## System Requirements

### Required Dependencies
- **Node.js** 16.0.0+ (recommended)
- **npm** (comes with Node.js)
- **git** (for repository management)
- **curl** (for downloads)
- **clang** (C compiler)
- **cmake** (build system)
- **pkg-config** (package configuration)
- **protobuf-compiler** (Protocol Buffers)

### Optional Dependencies
- **git-lfs** (for large file support)
- **Rust toolchain** (will be installed automatically if needed)

### Installation Commands

#### Ubuntu/Debian
```bash
sudo apt-get update && sudo apt-get install -y \
    nodejs npm git curl clang cmake pkg-config \
    protobuf-compiler libssl-dev git-lfs
```

#### macOS
```bash
brew install node git curl clang cmake pkg-config \
    protobuf git-lfs
```

## Usage

### Basic Deployment
```bash
# Make script executable
chmod +x bloop.sh

# Run deployment
./bloop.sh
```

### Interactive Options

The script will prompt you for several choices:

1. **Rust Installation**: Install or update Rust toolchain
2. **Directory Handling**: Remove existing bloop directory if present
3. **Backend Type**: Choose between Rust backend or mock server
4. **Port Conflicts**: Handle busy ports automatically

### Service Management

#### Starting Services
The script automatically starts both frontend and backend services:
- **Frontend**: http://localhost:3000
- **Backend**: http://localhost:7878

#### Stopping Services
```bash
# Stop backend
kill $(cat backend.pid)

# Stop frontend  
kill $(cat frontend.pid)

# Or use the cleanup function (Ctrl+C)
```

#### Restarting Services
Simply re-run the deployment script:
```bash
./bloop.sh
```

## Configuration

### Local Configuration File
The script creates `local_config.json` with optimal settings:

```json
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
```

### Environment Variables
The script sets several environment variables for optimal builds:
- `CARGO_NET_GIT_FETCH_WITH_CLI=true` (for git authentication)
- `RUSTFLAGS="-C target-cpu=native"` (for optimized builds)

## Troubleshooting

### Common Issues

#### 1. Git Authentication Errors
**Problem**: `failed to authenticate when downloading repository`
**Solution**: The script automatically configures git to use HTTPS instead of SSH

#### 2. Port Already in Use
**Problem**: `Port 3000/7878 is busy`
**Solution**: Script detects and offers to kill existing processes

#### 3. Rust Build Failures
**Problem**: Cargo build fails with dependency errors
**Solution**: Script retries builds and falls back to mock server

#### 4. Node.js Version Issues
**Problem**: Incompatible Node.js version
**Solution**: Install Node.js 16+ or use version manager like nvm

### Log Files

The script creates several log files for debugging:
- `bloop_deployment.log` - Main deployment log
- `backend.log` - Backend service logs
- `frontend.log` - Frontend service logs

### Health Checks

Verify services are running:
```bash
# Backend health check
curl http://localhost:7878/health

# Frontend check (should return HTML)
curl http://localhost:3000
```

## WSL2 Specific Notes

### Port Forwarding
- WSL2 automatically forwards ports to Windows
- Access services from Windows at `localhost:3000` and `localhost:7878`

### Firewall
- Windows Defender may prompt for Node.js network access
- Allow Node.js through the firewall when prompted

### Performance
- Keep files in WSL2 filesystem (`/home/username/`) for better performance
- Avoid Windows mounted drives (`/mnt/c/`) for development

## Advanced Usage

### Mock Server Mode
For development or when Rust build fails:
```bash
# The script will create mock-server.js automatically
node mock-server.js
```

### Custom Configuration
Edit `local_config.json` before starting services to customize:
- Port numbers
- Log levels
- Buffer sizes
- Thread counts

### Development Mode
For active development:
1. Use mock server for faster iteration
2. Run frontend in development mode: `npm run start-web`
3. Monitor logs: `tail -f frontend.log backend.log`

## Architecture

### Components
- **Frontend**: React application (client/)
- **Backend**: Rust service (server/bleep/)
- **Configuration**: JSON config files
- **Dependencies**: Node.js packages and Rust crates

### Service Flow
1. Backend starts on port 7878
2. Frontend starts on port 3000
3. Frontend communicates with backend API
4. Health checks verify service status

## Contributing

When modifying the deployment script:
1. Test on clean systems
2. Update this documentation
3. Maintain backward compatibility
4. Add appropriate error handling

## Support

For issues with the deployment script:
1. Check log files for detailed errors
2. Verify system requirements are met
3. Try mock server mode for development
4. Report issues with log file contents

