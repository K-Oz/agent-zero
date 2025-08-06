#!/bin/bash

# Agent Zero Universal Installer
# This script automates the full installation of Agent Zero on Linux, macOS, and Windows (via WSL/Git Bash)

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

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    log_info "Detected OS: $OS"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install miniconda
install_miniconda() {
    log_info "Installing Miniconda..."
    
    if command_exists conda; then
        log_success "Conda is already installed"
        return 0
    fi
    
    case $OS in
        "linux")
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
            INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
            ;;
        "macos")
            if [[ $(uname -m) == "arm64" ]]; then
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
                INSTALLER="Miniconda3-latest-MacOSX-arm64.sh"
            else
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
                INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
            fi
            ;;
        "windows")
            log_warning "On Windows, please download and install Miniconda manually from:"
            log_warning "https://docs.conda.io/en/latest/miniconda.html"
            log_warning "Then rerun this script from Anaconda Prompt"
            exit 1
            ;;
    esac
    
    # Download and install miniconda
    curl -o "$INSTALLER" "$MINICONDA_URL"
    bash "$INSTALLER" -b -p "$HOME/miniconda3"
    rm "$INSTALLER"
    
    # Initialize conda
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    conda init bash
    
    log_success "Miniconda installed successfully"
}

# Setup conda environment
setup_conda_env() {
    log_info "Setting up Conda environment..."
    
    # Initialize conda in current shell
    if [[ $OS != "windows" ]]; then
        eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
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

# Install Docker
install_docker() {
    log_info "Checking Docker installation..."
    
    if command_exists docker; then
        log_success "Docker is already installed"
        return 0
    fi
    
    case $OS in
        "linux")
            log_info "Installing Docker on Linux..."
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Add Docker repository
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            
            # Add user to docker group
            sudo usermod -aG docker $USER
            
            log_warning "Please log out and log back in to use Docker without sudo"
            ;;
        "macos")
            log_warning "On macOS, please download and install Docker Desktop manually from:"
            log_warning "https://www.docker.com/products/docker-desktop"
            log_warning "Then rerun this script"
            exit 1
            ;;
        "windows")
            log_warning "On Windows, please download and install Docker Desktop manually from:"
            log_warning "https://www.docker.com/products/docker-desktop"
            log_warning "Then rerun this script"
            exit 1
            ;;
    esac
    
    log_success "Docker installed successfully"
}

# Pull Agent Zero Docker image
pull_agent_zero_image() {
    log_info "Pulling Agent Zero Docker image..."
    
    if ! command_exists docker; then
        log_error "Docker is not available. Please install Docker first."
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
    log_info "You can map this directory when running the Docker container"
}

# Create run script
create_run_script() {
    log_info "Creating run script..."
    
    cat > run_agent_zero.sh << 'EOF'
#!/bin/bash

# Agent Zero Runner Script
# This script helps you run Agent Zero with proper Docker configuration

AGENT_ZERO_DATA="$HOME/agent-zero-data"
CONTAINER_NAME="agent-zero"
IMAGE_NAME="agent0ai/agent-zero"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Agent Zero...${NC}"

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

# Get the mapped port
sleep 5
PORT=$(docker port $CONTAINER_NAME 80/tcp | cut -d':' -f2)

echo -e "${GREEN}Agent Zero is running!${NC}"
echo -e "${GREEN}Access the Web UI at: http://localhost:$PORT${NC}"
echo -e "${YELLOW}Data directory: $AGENT_ZERO_DATA${NC}"
echo ""
echo "To stop Agent Zero, run: docker stop $CONTAINER_NAME"
echo "To view logs, run: docker logs $CONTAINER_NAME"
EOF

    chmod +x run_agent_zero.sh
    
    log_success "Run script created: run_agent_zero.sh"
}

# Main installation function
main() {
    echo "=================================="
    echo "  Agent Zero Automated Installer  "
    echo "=================================="
    echo ""
    
    detect_os
    
    log_info "Starting Agent Zero installation..."
    
    # Check if we're in the right directory
    if [[ ! -f "agent.py" ]] || [[ ! -f "requirements.txt" ]]; then
        log_error "This script must be run from the Agent Zero repository directory"
        exit 1
    fi
    
    # Installation steps
    install_miniconda
    setup_conda_env
    install_python_deps
    install_docker
    pull_agent_zero_image
    create_data_directory
    create_run_script
    
    echo ""
    log_success "Agent Zero installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. If on Linux, log out and log back in to use Docker without sudo"
    echo "2. Run ./run_agent_zero.sh to start Agent Zero"
    echo "3. Access the Web UI at the displayed URL"
    echo "4. Configure your API keys and settings in the Web UI"
    echo ""
    echo "For development setup, see: docs/development.md"
    echo "For troubleshooting, see: docs/troubleshooting.md"
}

# Run main function
main "$@"