#!/bin/bash

# Agent Zero macOS Installer
# This script automates the installation of Agent Zero on macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Homebrew is installed
check_homebrew() {
    if ! command_exists brew; then
        log_info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed successfully"
    else
        log_success "Homebrew is already installed"
    fi
}

# Install Command Line Tools
install_xcode_tools() {
    log_info "Checking for Xcode Command Line Tools..."
    
    if ! xcode-select -p &> /dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        
        log_warning "Please complete the Xcode Command Line Tools installation in the popup window"
        log_warning "Press any key after the installation is complete..."
        read -n 1 -s
        
        # Verify installation
        if ! xcode-select -p &> /dev/null; then
            log_error "Xcode Command Line Tools installation failed"
            exit 1
        fi
    fi
    
    log_success "Xcode Command Line Tools are available"
}

# Install miniconda via Homebrew
install_miniconda() {
    log_info "Installing Miniconda..."
    
    if command_exists conda; then
        log_success "Conda is already installed"
        return 0
    fi
    
    # Install miniconda via Homebrew
    brew install --cask miniconda
    
    # Initialize conda for the current shell
    eval "$(/opt/homebrew/Caskroom/miniconda/base/bin/conda shell.bash hook)"
    
    # Initialize conda for future shells
    /opt/homebrew/Caskroom/miniconda/base/bin/conda init bash
    /opt/homebrew/Caskroom/miniconda/base/bin/conda init zsh
    
    log_success "Miniconda installed successfully"
}

# Setup conda environment
setup_conda_env() {
    log_info "Setting up Conda environment..."
    
    # Make sure conda is available
    if [[ $(uname -m) == "arm64" ]]; then
        # Apple Silicon
        if [[ -f "/opt/homebrew/Caskroom/miniconda/base/bin/conda" ]]; then
            eval "$(/opt/homebrew/Caskroom/miniconda/base/bin/conda shell.bash hook)"
        elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
            eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
        fi
    else
        # Intel Mac
        if [[ -f "/usr/local/Caskroom/miniconda/base/bin/conda" ]]; then
            eval "$(/usr/local/Caskroom/miniconda/base/bin/conda shell.bash hook)"
        elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
            eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
        fi
    fi
    
    # Create environment
    conda create -n a0 python=3.12 -y
    conda activate a0
    
    log_success "Conda environment 'a0' created and activated"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies..."
    
    if [[ ! -f "requirements.txt" ]]; then
        log_error "requirements.txt not found. Please run this script from the Agent Zero directory."
        exit 1
    fi
    
    pip install -r requirements.txt
    playwright install chromium
    
    log_success "Python dependencies installed successfully"
}

# Install Docker Desktop
install_docker() {
    log_info "Checking Docker installation..."
    
    if command_exists docker; then
        log_success "Docker is already installed"
        return 0
    fi
    
    log_info "Installing Docker Desktop..."
    brew install --cask docker
    
    log_warning "Please start Docker Desktop from your Applications folder"
    log_warning "After Docker Desktop starts, you may need to complete the setup process"
    log_warning "Press any key after Docker Desktop is running..."
    read -n 1 -s
    
    # Wait for Docker to be ready
    local max_attempts=30
    local attempt=1
    
    while ! docker info >/dev/null 2>&1 && [ $attempt -le $max_attempts ]; do
        log_info "Waiting for Docker to start... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker failed to start. Please start Docker Desktop manually and rerun this script."
        exit 1
    fi
    
    log_success "Docker Desktop installed and running"
}

# Pull Agent Zero Docker image
pull_agent_zero_image() {
    log_info "Pulling Agent Zero Docker image..."
    
    if ! command_exists docker; then
        log_error "Docker is not available. Please install Docker Desktop first."
        exit 1
    fi
    
    docker pull agent0ai/agent-zero
    
    log_success "Agent Zero Docker image pulled successfully"
}

# Create data directory
create_data_directory() {
    log_info "Creating Agent Zero data directory..."
    
    AGENT_ZERO_DATA="$HOME/agent-zero-data"
    mkdir -p "$AGENT_ZERO_DATA"
    
    log_info "Data directory created at: $AGENT_ZERO_DATA"
}

# Create macOS-specific run script
create_run_script() {
    log_info "Creating run script..."
    
    cat > run_agent_zero.sh << 'EOF'
#!/bin/bash

# Agent Zero macOS Runner Script
# This script helps you run Agent Zero with proper Docker configuration

AGENT_ZERO_DATA="$HOME/agent-zero-data"
CONTAINER_NAME="agent-zero"
IMAGE_NAME="agent0ai/agent-zero"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Agent Zero on macOS...${NC}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop first.${NC}"
    echo "You can start Docker Desktop from your Applications folder."
    exit 1
fi

# Check if container already exists
if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    docker stop $CONTAINER_NAME >/dev/null 2>&1
    docker rm $CONTAINER_NAME >/dev/null 2>&1
fi

# Run new container
echo -e "${GREEN}Running Agent Zero container...${NC}"
docker run -d \
    --name $CONTAINER_NAME \
    -p 0:80 \
    -v "$AGENT_ZERO_DATA:/a0" \
    $IMAGE_NAME

# Wait for container to start
sleep 5

# Get the mapped port
PORT=$(docker port $CONTAINER_NAME 80/tcp | cut -d':' -f2)

if [ -z "$PORT" ]; then
    echo -e "${RED}Failed to get container port. Please check Docker logs.${NC}"
    docker logs $CONTAINER_NAME
    exit 1
fi

echo -e "${GREEN}Agent Zero is running!${NC}"
echo -e "${GREEN}Access the Web UI at: http://localhost:$PORT${NC}"
echo -e "${YELLOW}Data directory: $AGENT_ZERO_DATA${NC}"
echo ""
echo "To stop Agent Zero, run: docker stop $CONTAINER_NAME"
echo "To view logs, run: docker logs $CONTAINER_NAME"

# Open browser automatically (optional)
read -p "Open the Web UI in your default browser? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "http://localhost:$PORT"
fi
EOF

    chmod +x run_agent_zero.sh
    
    log_success "Run script created: run_agent_zero.sh"
}

# Create conda activation script
create_conda_script() {
    log_info "Creating conda activation script..."
    
    cat > activate_agent_zero.sh << 'EOF'
#!/bin/bash

# Agent Zero Conda Environment Activation Script
# This script activates the conda environment for Agent Zero development

# Detect conda installation path
if [[ $(uname -m) == "arm64" ]]; then
    # Apple Silicon - check multiple possible locations
    if [[ -f "/opt/homebrew/Caskroom/miniconda/base/bin/conda" ]]; then
        CONDA_PATH="/opt/homebrew/Caskroom/miniconda/base"
    elif [[ -f "/opt/homebrew/bin/conda" ]]; then
        CONDA_PATH="/opt/homebrew"
    elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
        CONDA_PATH="$HOME/miniconda3"
    fi
else
    # Intel Mac
    if [[ -f "/usr/local/Caskroom/miniconda/base/bin/conda" ]]; then
        CONDA_PATH="/usr/local/Caskroom/miniconda/base"
    elif [[ -f "/usr/local/bin/conda" ]]; then
        CONDA_PATH="/usr/local"
    elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
        CONDA_PATH="$HOME/miniconda3"
    fi
fi

if [[ -n "$CONDA_PATH" ]]; then
    eval "$($CONDA_PATH/bin/conda shell.bash hook)"
    conda activate a0
    echo "Conda environment 'a0' activated"
    echo "You can now run: python run_ui.py"
else
    echo "Could not find conda installation. Please activate manually:"
    echo "conda activate a0"
fi
EOF

    chmod +x activate_agent_zero.sh
    
    log_success "Conda activation script created: activate_agent_zero.sh"
}

# Main installation function
main() {
    echo "=================================="
    echo "  Agent Zero macOS Installer     "
    echo "=================================="
    echo ""
    
    log_info "Starting Agent Zero installation on macOS..."
    
    # Check if we're in the right directory
    if [[ ! -f "agent.py" ]] || [[ ! -f "requirements.txt" ]]; then
        log_error "This script must be run from the Agent Zero repository directory"
        exit 1
    fi
    
    # Check macOS version
    macos_version=$(sw_vers -productVersion)
    log_info "macOS version: $macos_version"
    
    # Installation steps
    install_xcode_tools
    check_homebrew
    install_miniconda
    setup_conda_env
    install_python_deps
    install_docker
    pull_agent_zero_image
    create_data_directory
    create_run_script
    create_conda_script
    
    echo ""
    log_success "Agent Zero installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Start a new terminal session to ensure conda is properly initialized"
    echo "2. Run ./run_agent_zero.sh to start Agent Zero with Docker"
    echo "3. Or run ./activate_agent_zero.sh to activate conda environment for development"
    echo "4. Access the Web UI at the displayed URL"
    echo "5. Configure your API keys and settings in the Web UI"
    echo ""
    echo "Important macOS-specific notes:"
    echo "• Make sure to enable 'Allow the default Docker socket to be used' in Docker Desktop Settings > Advanced"
    echo "• For development, you may need to allow terminal access in System Preferences > Security & Privacy"
    echo ""
    echo "For development setup, see: docs/development.md"
    echo "For troubleshooting, see: docs/troubleshooting.md"
}

# Run main function
main "$@"