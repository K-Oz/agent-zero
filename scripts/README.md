# Agent Zero Automated Installation Scripts

This directory contains automated installation scripts for Agent Zero on different platforms. These scripts automate the entire "full binaries installation" process described in the documentation.

## Quick Start

### One-line installation (Linux/macOS):
```bash
curl -fsSL https://raw.githubusercontent.com/agent0ai/agent-zero/main/scripts/install.sh | bash
```

### Platform-specific installation:

#### Universal installer (Linux/macOS/Windows with WSL):
```bash
bash scripts/install.sh
```

#### Linux:
```bash
bash scripts/install-linux.sh
```

#### macOS:
```bash
bash scripts/install-macos.sh
```

#### Windows:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

## What These Scripts Do

The automated installers perform all the steps from the "In-Depth Guide for Full Binaries Installation":

1. **Install Miniconda/Conda** - Downloads and installs the appropriate version for your platform
2. **Create Conda Environment** - Sets up a Python 3.12 environment named 'a0'
3. **Install Dependencies** - Installs all Python packages from requirements.txt
4. **Install Playwright** - Downloads Chromium browser for web automation
5. **Install Docker** - Installs Docker Desktop or docker-ce depending on platform
6. **Pull Agent Zero Image** - Downloads the latest agent0ai/agent-zero Docker image
7. **Create Data Directory** - Sets up ~/agent-zero-data for persistent storage
8. **Generate Run Scripts** - Creates platform-specific scripts to easily start Agent Zero

## Script Details

### install.sh (Universal)
- Detects the operating system automatically
- Works on Linux, macOS, and Windows (via WSL/Git Bash)
- Falls back to manual instructions for Windows-specific steps

### install-linux.sh
- Supports major Linux distributions (Ubuntu, Debian, Fedora, CentOS, Arch, openSUSE)
- Automatically detects package manager and distribution
- Installs system dependencies using the appropriate package manager
- Handles Docker installation and user group management

### install-macos.sh
- Optimized for macOS (Intel and Apple Silicon)
- Installs Homebrew if not present
- Handles Xcode Command Line Tools installation
- Uses Homebrew to install Docker Desktop and Miniconda
- Creates macOS-specific activation scripts

### install.ps1
- PowerShell script for Windows
- Downloads and installs Miniconda silently
- Provides guidance for Docker Desktop installation
- Creates Windows batch files for easy startup

## Usage Examples

### Basic installation:
```bash
# Clone the repository
git clone https://github.com/agent0ai/agent-zero.git
cd agent-zero

# Run the installer
bash scripts/install.sh
```

### With custom options (Windows):
```powershell
# Skip Docker installation (install manually)
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -SkipDocker

# Custom data directory
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -InstallPath "C:\MyAgentZero"
```

## After Installation

Once installation completes, you'll have:

1. **Run Scripts**: Platform-specific scripts to start Agent Zero
   - Linux/macOS: `./run_agent_zero.sh`
   - Windows: `run_agent_zero.bat`

2. **Conda Activation Scripts**: For development work
   - Linux/macOS: `./activate_agent_zero.sh`
   - Windows: Available through Anaconda Prompt

3. **Data Directory**: `~/agent-zero-data` (or custom path) for persistent storage

## Starting Agent Zero

### Using Docker (Recommended):
```bash
./run_agent_zero.sh
```

### For Development:
```bash
# Activate conda environment
./activate_agent_zero.sh  # or source activate_agent_zero.sh

# Run locally
python run_ui.py
```

## Troubleshooting

### Common Issues:

1. **Permission Denied**: Make scripts executable
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Docker Group**: On Linux, log out and back in after installation
   ```bash
   # Check if you're in docker group
   groups $USER | grep docker
   ```

3. **Conda Not Found**: Restart terminal or source your shell profile
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

4. **Windows Execution Policy**: 
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Platform-Specific Notes:

#### Linux:
- Requires sudo access for system package installation
- Supports major distributions; others may need manual dependency installation
- Docker installation adds user to docker group (requires re-login)

#### macOS:
- Requires admin password for Homebrew and Xcode tools
- Must enable Docker socket in Docker Desktop Settings > Advanced
- Supports both Intel and Apple Silicon Macs

#### Windows:
- Requires PowerShell execution policy changes
- Docker Desktop installation is manual (requires restart)
- Uses Anaconda Prompt for conda commands

## Manual Installation Fallback

If automated scripts fail, refer to the manual installation guide:
- [Installation Documentation](../docs/installation.md)
- [Development Setup](../docs/development.md)

## Contributing

To improve these scripts:
1. Test on your platform
2. Report issues or add platform support
3. Follow the existing code style and error handling patterns
4. Update this README with any changes

## Support

For help:
- Check [Troubleshooting Documentation](../docs/troubleshooting.md)
- Visit [Agent Zero Community](https://discord.gg/B8KZKNsPpj)
- Open an issue on [GitHub](https://github.com/agent0ai/agent-zero/issues)