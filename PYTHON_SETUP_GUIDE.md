# Bloop Python Setup & Preview System

A comprehensive Python-based setup and preview system for bloop with variable validation, dependency management, and persistent UI streaming.

## 🚀 Quick Start

```bash
# 1. Install Python dependencies
pip3 install -r requirements.txt

# 2. Run setup (interactive configuration)
python3 setup.py

# 3. Start persistent UI
python3 preview.py
```

## 📋 Features

### Setup.py Features
- **🔍 Comprehensive Dependency Checking** - Validates all system dependencies
- **🔑 API Key Management** - Secure collection and validation of OpenAI/GitHub tokens
- **⚙️ Interactive Configuration** - User-friendly prompts with validation
- **📁 Directory Management** - Automatic creation of required directories
- **💾 Multiple Config Formats** - JSON config + .env file generation
- **🛡️ Security** - Masked input for sensitive data, proper file permissions

### Preview.py Features
- **🎬 Persistent UI Streaming** - Services run continuously, don't exit after launch
- **📊 Service Monitoring** - Real-time health checks and automatic restarts
- **🎛️ Interactive Management** - Live service control and status monitoring
- **📋 Log Management** - Centralized logging with easy access
- **🌐 Browser Integration** - Automatic browser opening
- **🔄 Graceful Shutdown** - Proper cleanup and signal handling

## 🔧 Configuration Variables

### Required Variables
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `BLOOP_HOST` | Host address for services | `127.0.0.1` | Yes |
| `BLOOP_BACKEND_PORT` | Backend service port | `7878` | Yes |
| `BLOOP_FRONTEND_PORT` | Frontend service port | `3000` | Yes |
| `BLOOP_LOG_LEVEL` | Logging level | `info` | Yes |
| `BLOOP_DATA_DIR` | Data storage directory | `./data` | Yes |
| `BLOOP_INDEX_DIR` | Search index directory | `./index` | Yes |

### Optional Variables
| Variable | Description | When Needed |
|----------|-------------|-------------|
| `OPENAI_API_KEY` | OpenAI API key for AI features | AI-powered code analysis |
| `GITHUB_TOKEN` | GitHub personal access token | Private repository access |

## 🔑 API Key Integration

### OpenAI API Key
- **Purpose**: AI-powered code analysis and search enhancement
- **Format**: Must start with `sk-`
- **Validation**: Tested against OpenAI API during setup
- **Usage**: Backend services for intelligent code understanding

### GitHub Token
- **Purpose**: Access private repositories and enhanced GitHub integration
- **Format**: GitHub personal access token
- **Validation**: Tested against GitHub API during setup
- **Usage**: Repository indexing and code fetching

### When to Provide API Keys

#### During Setup (setup.py):
1. **OpenAI API Key** - Prompted during configuration
   - Optional for basic functionality
   - Required for AI features
   - Validated in real-time

2. **GitHub Token** - Prompted during configuration
   - Optional for public repositories
   - Required for private repository access
   - Validated against GitHub API

#### Security Measures:
- Input is masked during entry
- Keys stored in `.env` file with restricted permissions (600)
- Never logged or displayed in plain text
- Validation happens over HTTPS

## 🚀 Deployment Modes

### Quick Start Mode
- **Setup Time**: ~2 minutes
- **Backend**: Mock Express.js server
- **Features**: Full frontend functionality for testing
- **Use Case**: Development, UI testing, quick demos

### Full Deployment Mode
- **Setup Time**: 20-40 minutes
- **Backend**: Full Rust backend
- **Features**: Complete production functionality
- **Use Case**: Production deployment, full feature access

## 📊 Service Management

### Service Status
```bash
# Check service status
python3 preview.py --status

# Interactive service management
python3 preview.py
```

### Available Services

#### Quick Mode:
1. **Mock Backend** (Port 7878)
   - Express.js server with realistic API responses
   - Health check endpoint
   - Mock search and repository data

2. **Frontend** (Port 3000)
   - React-based UI
   - Full user interface functionality
   - Connected to mock backend

#### Full Mode:
1. **Rust Backend** (Port 7878)
   - Full bloop search engine
   - Real code indexing and search
   - AI-powered features (if API key provided)

2. **Frontend** (Port 3000)
   - React-based UI
   - Connected to full Rust backend
   - All production features available

## 🎛️ Interactive Management

When running `python3 preview.py`, you get an interactive menu:

```
🎛️ Bloop Service Manager
1. Show status
2. Restart all services
3. Open browser
4. View logs
5. Quit
```

### Menu Options:
- **Show status**: Display current service status and health
- **Restart all services**: Stop and restart all services
- **Open browser**: Open default browser to bloop UI
- **View logs**: Access service logs for debugging
- **Quit**: Gracefully shutdown all services

## 📋 Log Management

### Log Files:
- `setup.log` - Setup process logs
- `preview.log` - Preview service management logs
- `logs/backend.log` - Backend service logs
- `logs/frontend.log` - Frontend service logs

### Viewing Logs:
```bash
# View setup logs
tail -f setup.log

# View preview logs
tail -f preview.log

# View service logs through interactive menu
python3 preview.py
# Then select option 4
```

## 🔍 System Dependencies

### Required Dependencies:
- **Git** - Version control
- **Node.js** - JavaScript runtime
- **NPM** - Package manager

### Optional Dependencies (Full Mode):
- **Rust** - Rust compiler
- **Cargo** - Rust package manager

### Automatic Installation:
The setup script can automatically install missing dependencies on supported systems (Ubuntu/Debian, CentOS/RHEL, Arch Linux).

## 🛠️ Troubleshooting

### Common Issues:

#### 1. Configuration Not Found
```bash
❌ Configuration file not found. Run setup.py first.
```
**Solution**: Run `python3 setup.py` to create configuration

#### 2. Port Already in Use
```bash
❌ Port 3000 is already in use
```
**Solution**: 
- Kill existing processes: `lsof -ti:3000 | xargs kill -9`
- Or change port in configuration

#### 3. API Key Validation Failed
```bash
❌ Invalid value for OPENAI_API_KEY
```
**Solution**:
- Verify API key format (starts with `sk-`)
- Check API key permissions
- Ensure internet connectivity

#### 4. Service Won't Start
```bash
❌ Failed to start Frontend
```
**Solution**:
- Check logs: `python3 preview.py` → option 4
- Verify dependencies are installed
- Check port availability

### Debug Commands:
```bash
# Check system dependencies
python3 setup.py  # Will show dependency status

# Check service status
python3 preview.py --status

# View detailed logs
tail -f logs/backend.log
tail -f logs/frontend.log
```

## 🔄 Workflow Examples

### First Time Setup:
```bash
# 1. Clone repository
git clone https://github.com/Zeeeepa/bloop.git
cd bloop
git checkout codegen-bot/upgrade-bloop-local-port-3000-1757524345

# 2. Install Python dependencies
pip3 install -r requirements.txt

# 3. Run interactive setup
python3 setup.py
# Follow prompts for:
# - Deployment mode selection
# - API key configuration
# - Port configuration
# - Directory setup

# 4. Start services
python3 preview.py
# Services start automatically
# Browser opens to http://localhost:3000
# Interactive menu available
```

### Daily Usage:
```bash
# Start bloop
python3 preview.py

# Check status
python3 preview.py --status

# View logs if issues
python3 preview.py
# Select option 4 for logs
```

### Configuration Updates:
```bash
# Re-run setup to update configuration
python3 setup.py

# Restart services to apply changes
python3 preview.py
# Select option 2 to restart services
```

## 🔐 Security Considerations

### API Key Storage:
- Keys stored in `.env` file with 600 permissions
- Never logged in plain text
- Validated over HTTPS only
- Can be updated by re-running setup

### Network Security:
- Services bind to localhost by default
- Health checks use local connections
- API validation uses official endpoints

### Process Security:
- Services run in separate process groups
- Graceful shutdown with proper cleanup
- PID file management for process tracking

## 📈 Performance Features

### Service Monitoring:
- Health checks every 10 seconds
- Automatic restart on failure (max 3 attempts)
- Process group management for clean shutdown

### Resource Management:
- Log rotation through external tools
- Directory structure optimization
- Efficient configuration loading

### Startup Optimization:
- Parallel dependency checking
- Fast configuration validation
- Quick mode for development

## 🤝 Integration Points

### With Existing Scripts:
- Compatible with existing shell scripts
- Can coexist with `setup.sh` and `preview.sh`
- Uses same configuration formats

### With External Tools:
- Integrates with system package managers
- Works with existing Node.js/Rust toolchains
- Compatible with standard logging tools

### With Development Workflow:
- Supports both development and production modes
- Easy switching between configurations
- Comprehensive logging for debugging

This Python-based system provides a robust, user-friendly alternative to shell scripts with better error handling, validation, and persistent service management.
