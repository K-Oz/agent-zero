# Agent Zero Windows Installer
# PowerShell script to automate Agent Zero installation on Windows

param(
    [string]$InstallPath = "$env:USERPROFILE\agent-zero-data",
    [switch]$SkipDocker = $false,
    [switch]$SkipConda = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        default { Write-Host $Message }
    }
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Blue"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Download file with progress
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Info "Downloading $Url..."
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Success "Downloaded successfully"
    }
    catch {
        Write-Error "Failed to download: $($_.Exception.Message)"
        throw
    }
}

# Install Miniconda
function Install-Miniconda {
    Write-Info "Checking Miniconda installation..."
    
    if (Test-Command "conda") {
        Write-Success "Conda is already installed"
        return
    }
    
    if ($SkipConda) {
        Write-Warning "Skipping Conda installation as requested"
        return
    }
    
    Write-Info "Installing Miniconda..."
    
    $minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
    $installerPath = "$env:TEMP\Miniconda3-latest-Windows-x86_64.exe"
    
    Download-File $minicondaUrl $installerPath
    
    Write-Info "Running Miniconda installer..."
    $process = Start-Process -FilePath $installerPath -ArgumentList "/InstallationType=AllUsers", "/RegisterPython=0", "/S", "/D=$env:ProgramFiles\Miniconda3" -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Error "Miniconda installation failed with exit code $($process.ExitCode)"
        throw "Installation failed"
    }
    
    # Add conda to PATH for current session
    $env:PATH = "$env:ProgramFiles\Miniconda3;$env:ProgramFiles\Miniconda3\Scripts;$env:PATH"
    
    Remove-Item $installerPath -Force
    Write-Success "Miniconda installed successfully"
}

# Setup Conda environment
function Setup-CondaEnvironment {
    Write-Info "Setting up Conda environment..."
    
    if (-not (Test-Command "conda")) {
        Write-Error "Conda is not available. Please install Miniconda first."
        throw "Conda not found"
    }
    
    # Initialize conda for PowerShell
    & conda init powershell
    
    # Create environment
    Write-Info "Creating conda environment 'a0' with Python 3.12..."
    & conda create -n a0 python=3.12 -y
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create conda environment"
        throw "Environment creation failed"
    }
    
    Write-Success "Conda environment 'a0' created successfully"
}

# Install Python dependencies
function Install-PythonDependencies {
    Write-Info "Installing Python dependencies..."
    
    if (-not (Test-Path "requirements.txt")) {
        Write-Error "requirements.txt not found. Please run this script from the Agent Zero directory."
        throw "Requirements file not found"
    }
    
    # Activate conda environment and install dependencies
    Write-Info "Activating conda environment and installing packages..."
    
    $activateScript = "$env:ProgramFiles\Miniconda3\Scripts\activate.bat"
    if (Test-Path $activateScript) {
        & cmd /c "$activateScript a0 && pip install -r requirements.txt && playwright install chromium"
    }
    else {
        Write-Warning "Could not find conda activate script. Please manually activate 'a0' environment and run:"
        Write-Warning "pip install -r requirements.txt"
        Write-Warning "playwright install chromium"
    }
    
    Write-Success "Python dependencies installed successfully"
}

# Check Docker installation
function Install-Docker {
    Write-Info "Checking Docker installation..."
    
    if (Test-Command "docker") {
        Write-Success "Docker is already installed"
        return
    }
    
    if ($SkipDocker) {
        Write-Warning "Skipping Docker installation as requested"
        return
    }
    
    Write-Warning "Docker Desktop is not installed."
    Write-Info "Please download and install Docker Desktop from:"
    Write-Info "https://www.docker.com/products/docker-desktop"
    Write-Info ""
    Write-Info "After installing Docker Desktop:"
    Write-Info "1. Restart your computer"
    Write-Info "2. Start Docker Desktop"
    Write-Info "3. Rerun this installer"
    
    $response = Read-Host "Do you want to download Docker Desktop now? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Start-Process "https://www.docker.com/products/docker-desktop"
    }
    
    throw "Docker installation required"
}

# Pull Agent Zero Docker image
function Pull-AgentZeroImage {
    Write-Info "Pulling Agent Zero Docker image..."
    
    if (-not (Test-Command "docker")) {
        Write-Error "Docker is not available. Please install Docker Desktop first."
        throw "Docker not found"
    }
    
    & docker pull agent0ai/agent-zero
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pull Agent Zero Docker image"
        throw "Docker pull failed"
    }
    
    Write-Success "Agent Zero Docker image pulled successfully"
}

# Create data directory
function Create-DataDirectory {
    Write-Info "Creating Agent Zero data directory..."
    
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    Write-Info "Data directory created at: $InstallPath"
    Write-Info "You can map this directory when running the Docker container"
}

# Create Windows batch file to run Agent Zero
function Create-RunScript {
    Write-Info "Creating run script..."
    
    $batchContent = @"
@echo off
REM Agent Zero Windows Runner Script
REM This script helps you run Agent Zero with proper Docker configuration

set AGENT_ZERO_DATA=%USERPROFILE%\agent-zero-data
set CONTAINER_NAME=agent-zero
set IMAGE_NAME=agent0ai/agent-zero

echo Starting Agent Zero...

REM Check if container already exists and stop/remove it
docker ps -a --format "table {{.Names}}" | findstr /r "^%CONTAINER_NAME%$" >nul 2>&1
if %errorlevel% equ 0 (
    echo Stopping existing container...
    docker stop %CONTAINER_NAME% >nul 2>&1
    docker rm %CONTAINER_NAME% >nul 2>&1
)

REM Run new container
echo Running Agent Zero container...
docker run -d --name %CONTAINER_NAME% -p 0:80 -v "%AGENT_ZERO_DATA%:/a0" %IMAGE_NAME%

REM Wait a moment for container to start
timeout /t 5 /nobreak >nul

REM Get the mapped port
for /f "tokens=2 delims=:" %%a in ('docker port %CONTAINER_NAME% 80/tcp') do set PORT=%%a

echo.
echo Agent Zero is running!
echo Access the Web UI at: http://localhost:%PORT%
echo Data directory: %AGENT_ZERO_DATA%
echo.
echo To stop Agent Zero, run: docker stop %CONTAINER_NAME%
echo To view logs, run: docker logs %CONTAINER_NAME%
echo.
pause
"@

    $batchContent | Out-File -FilePath "run_agent_zero.bat" -Encoding ASCII
    
    Write-Success "Run script created: run_agent_zero.bat"
}

# Main installation function
function Main {
    Write-Host ""
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "  Agent Zero Windows Installer     " -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Info "Starting Agent Zero installation on Windows..."
    
    # Check if we're in the right directory
    if (-not (Test-Path "agent.py") -or -not (Test-Path "requirements.txt")) {
        Write-Error "This script must be run from the Agent Zero repository directory"
        throw "Wrong directory"
    }
    
    try {
        # Installation steps
        Install-Miniconda
        Setup-CondaEnvironment
        Install-PythonDependencies
        Install-Docker
        Pull-AgentZeroImage
        Create-DataDirectory
        Create-RunScript
        
        Write-Host ""
        Write-Success "Agent Zero installation completed successfully!"
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Restart PowerShell to ensure conda is properly initialized"
        Write-Host "2. Run run_agent_zero.bat to start Agent Zero"
        Write-Host "3. Access the Web UI at the displayed URL"
        Write-Host "4. Configure your API keys and settings in the Web UI"
        Write-Host ""
        Write-Host "For development setup, see: docs/development.md"
        Write-Host "For troubleshooting, see: docs/troubleshooting.md"
    }
    catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Please check the error message above and try again."
        Write-Host "For help, visit: https://github.com/agent0ai/agent-zero/issues"
        exit 1
    }
}

# Check PowerShell execution policy
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq "Restricted") {
    Write-Warning "PowerShell execution policy is restricted. You may need to run:"
    Write-Warning "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Write-Warning "Or run this script with: powershell -ExecutionPolicy Bypass -File install.ps1"
}

# Run main function
Main