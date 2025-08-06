#!/bin/bash

# Agent Zero Linux Installer
# This script automates the installation of Agent Zero on Linux distributions

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

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VERSION=$(lsb_release -sr)
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected Linux distribution: $DISTRO $VERSION"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."
    
    case $DISTRO in
        "ubuntu"|"debian")
            sudo apt-get update
            sudo apt-get install -y curl wget git build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release
            ;;
        "fedora"|"rhel"|"centos")
            if command_exists dnf; then
                sudo dnf update -y
                sudo dnf install -y curl wget git gcc gcc-c++ make dnf-plugins-core
            else
                sudo yum update -y
                sudo yum install -y curl wget git gcc gcc-c++ make yum-utils
            fi
            ;;
        "arch"|"manjaro")
            sudo pacman -Sy --noconfirm curl wget git base-devel
            ;;
        "opensuse"|"suse")
            sudo zypper refresh
            sudo zypper install -y curl wget git gcc gcc-c++ make
            ;;
        *)
            log_warning "Unknown distribution. Attempting to install basic dependencies..."
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y curl wget git build-essential
            elif command_exists dnf; then
                sudo dnf install -y curl wget git gcc gcc-c++ make
            elif command_exists yum; then
                sudo yum install -y curl wget git gcc gcc-c++ make
            elif command_exists pacman; then
                sudo pacman -Sy --noconfirm curl wget git base-devel
            else
                log_error "Cannot determine package manager. Please install curl, wget, git, and build tools manually."
                exit 1
            fi
            ;;
    esac
    
    log_success "System dependencies installed"
}

# Install miniconda
install_miniconda() {
    log_info "Installing Miniconda..."
    
    if command_exists conda; then
        log_success "Conda is already installed"
        return 0
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        "x86_64")
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
            INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
            ;;
        "aarch64"|"arm64")
            MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
            INSTALLER="Miniconda3-latest-Linux-aarch64.sh"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download and install miniconda
    wget -O "$INSTALLER" "$MINICONDA_URL"
    bash "$INSTALLER" -b -p "$HOME/miniconda3"
    rm "$INSTALLER"
    
    # Initialize conda
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    "$HOME/miniconda3/bin/conda" init bash
    
    # Also initialize for zsh if it exists
    if command_exists zsh; then
        "$HOME/miniconda3/bin/conda" init zsh
    fi
    
    log_success "Miniconda installed successfully"
}

# Setup conda environment
setup_conda_env() {
    log_info "Setting up Conda environment..."
    
    # Initialize conda in current shell
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    
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
    
    # Install Python packages
    pip install -r requirements.txt
    
    # Install Playwright browsers
    playwright install chromium
    
    # Install additional system dependencies for Playwright
    case $DISTRO in
        "ubuntu"|"debian")
            playwright install-deps chromium || log_warning "Could not install all Playwright dependencies automatically"
            ;;
        *)
            log_warning "Please ensure system dependencies for Playwright are installed manually if needed"
            ;;
    esac
    
    log_success "Python dependencies installed successfully"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command_exists docker; then
        log_success "Docker is already installed"
        # Check if user is in docker group
        if groups $USER | grep -q docker; then
            log_success "User is already in docker group"
        else
            log_info "Adding user to docker group..."
            sudo usermod -aG docker $USER
            log_warning "Please log out and log back in to use Docker without sudo"
        fi
        return 0
    fi
    
    case $DISTRO in
        "ubuntu"|"debian")
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Add Docker repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        "fedora")
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        "centos"|"rhel")
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        "arch"|"manjaro")
            sudo pacman -S --noconfirm docker docker-compose
            ;;
        "opensuse"|"suse")
            sudo zypper install -y docker docker-compose
            ;;
        *)
            log_error "Automatic Docker installation not supported for $DISTRO"
            log_info "Please install Docker manually from: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
    log_warning "Please log out and log back in to use Docker without sudo"
}

# Pull Agent Zero Docker image
pull_agent_zero_image() {
    log_info "Pulling Agent Zero Docker image..."
    
    if ! command_exists docker; then
        log_error "Docker is not available. Please install Docker first."
        exit 1
    fi
    
    # Try to pull the image, use sudo if user is not in docker group
    if docker pull agent0ai/agent-zero 2>/dev/null; then
        log_success "Agent Zero Docker image pulled successfully"
    elif sudo docker pull agent0ai/agent-zero; then
        log_success "Agent Zero Docker image pulled successfully (with sudo)"
        log_warning "Please log out and log back in to use Docker without sudo"
    else
        log_error "Failed to pull Agent Zero Docker image"
        exit 1
    fi
}

# Create data directory
create_data_directory() {
    log_info "Creating Agent Zero data directory..."
    
    AGENT_ZERO_DATA="$HOME/agent-zero-data"
    mkdir -p "$AGENT_ZERO_DATA"
    
    log_info "Data directory created at: $AGENT_ZERO_DATA"
}

# Create run script
create_run_script() {
    log_info "Creating run script..."
    
    cat > run_agent_zero.sh << 'EOF'
#!/bin/bash

# Agent Zero Linux Runner Script
# This script helps you run Agent Zero with proper Docker configuration

AGENT_ZERO_DATA="$HOME/agent-zero-data"
CONTAINER_NAME="agent-zero"
IMAGE_NAME="agent0ai/agent-zero"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Agent Zero on Linux...${NC}"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Docker is not available. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker daemon is not running. Please start Docker service:${NC}"
    echo "sudo systemctl start docker"
    exit 1
fi

# Function to run docker command (with sudo fallback)
run_docker() {
    if docker "$@" 2>/dev/null; then
        return 0
    elif sudo docker "$@"; then
        echo -e "${YELLOW}Note: Using sudo for Docker. Add your user to docker group to avoid this.${NC}"
        return 0
    else
        return 1
    fi
}

# Check if container already exists
if run_docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Stopping existing container...${NC}"
    run_docker stop $CONTAINER_NAME >/dev/null 2>&1
    run_docker rm $CONTAINER_NAME >/dev/null 2>&1
fi

# Run new container
echo -e "${GREEN}Running Agent Zero container...${NC}"
if ! run_docker run -d \
    --name $CONTAINER_NAME \
    -p 0:80 \
    -v "$AGENT_ZERO_DATA:/a0" \
    $IMAGE_NAME; then
    echo -e "${RED}Failed to start container${NC}"
    exit 1
fi

# Wait for container to start
sleep 5

# Get the mapped port
PORT=$(run_docker port $CONTAINER_NAME 80/tcp | cut -d':' -f2)

if [ -z "$PORT" ]; then
    echo -e "${RED}Failed to get container port. Please check Docker logs.${NC}"
    run_docker logs $CONTAINER_NAME
    exit 1
fi

echo -e "${GREEN}Agent Zero is running!${NC}"
echo -e "${GREEN}Access the Web UI at: http://localhost:$PORT${NC}"
echo -e "${YELLOW}Data directory: $AGENT_ZERO_DATA${NC}"
echo ""
echo "To stop Agent Zero, run: docker stop $CONTAINER_NAME"
echo "To view logs, run: docker logs $CONTAINER_NAME"

# Try to open browser if available
if command -v xdg-open >/dev/null 2>&1; then
    read -p "Open the Web UI in your default browser? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "http://localhost:$PORT"
    fi
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

if [[ -f "$HOME/miniconda3/bin/conda" ]]; then
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
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
    echo "  Agent Zero Linux Installer     "
    echo "=================================="
    echo ""
    
    detect_distro
    
    log_info "Starting Agent Zero installation on Linux..."
    
    # Check if we're in the right directory
    if [[ ! -f "agent.py" ]] || [[ ! -f "requirements.txt" ]]; then
        log_error "This script must be run from the Agent Zero repository directory"
        exit 1
    fi
    
    # Installation steps
    install_system_deps
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
    echo "1. Log out and log back in to use Docker without sudo"
    echo "2. Start a new terminal session to ensure conda is properly initialized"
    echo "3. Run ./run_agent_zero.sh to start Agent Zero with Docker"
    echo "4. Or run ./activate_agent_zero.sh to activate conda environment for development"
    echo "5. Access the Web UI at the displayed URL"
    echo "6. Configure your API keys and settings in the Web UI"
    echo ""
    echo "For development setup, see: docs/development.md"
    echo "For troubleshooting, see: docs/troubleshooting.md"
}

# Run main function
main "$@"