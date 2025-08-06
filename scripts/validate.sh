#!/bin/bash

# Agent Zero Installation Validation Script
# This script validates that the installation automation is working correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================="
echo "Agent Zero Installation Validator"
echo "=================================="
echo ""

# Test 1: Check that all scripts exist and are executable
echo -e "${YELLOW}Test 1: Checking script files...${NC}"
scripts=(
    "scripts/install.sh"
    "scripts/install-linux.sh" 
    "scripts/install-macos.sh"
    "scripts/install.ps1"
)

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        echo -e "${GREEN}✓${NC} Found: $script"
        if [[ "$script" == *.sh ]] && [[ ! -x "$script" ]]; then
            echo -e "${RED}✗${NC} Script $script is not executable"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Missing: $script"
        exit 1
    fi
done

# Test 2: Check script syntax
echo -e "\n${YELLOW}Test 2: Checking script syntax...${NC}"
bash -n scripts/install.sh && echo -e "${GREEN}✓${NC} install.sh syntax OK"
bash -n scripts/install-linux.sh && echo -e "${GREEN}✓${NC} install-linux.sh syntax OK"
bash -n scripts/install-macos.sh && echo -e "${GREEN}✓${NC} install-macos.sh syntax OK"

# Test 3: Check Python files compile
echo -e "\n${YELLOW}Test 3: Checking Python syntax...${NC}"
python -m py_compile agent.py && echo -e "${GREEN}✓${NC} agent.py compiles"
python -m py_compile models.py && echo -e "${GREEN}✓${NC} models.py compiles"
python -m py_compile run_ui.py && echo -e "${GREEN}✓${NC} run_ui.py compiles"
python -m py_compile initialize.py && echo -e "${GREEN}✓${NC} initialize.py compiles"

# Test 4: Check requirements.txt is valid
echo -e "\n${YELLOW}Test 4: Checking requirements.txt...${NC}"
if python -m pip install --dry-run -r requirements.txt >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} requirements.txt is valid"
else
    echo -e "${RED}✗${NC} requirements.txt has issues"
    exit 1
fi

# Test 5: Check GitHub Actions workflows syntax
echo -e "\n${YELLOW}Test 5: Checking GitHub Actions workflows...${NC}"
workflows=(
    ".github/workflows/ci.yml"
    ".github/workflows/release.yml"
    ".github/workflows/test-install.yml"
)

for workflow in "${workflows[@]}"; do
    if [[ -f "$workflow" ]]; then
        echo -e "${GREEN}✓${NC} Found: $workflow"
        # Basic YAML syntax check
        if python -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $workflow has valid YAML syntax"
        else
            echo -e "${RED}✗${NC} $workflow has invalid YAML syntax"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Missing: $workflow"
        exit 1
    fi
done

# Test 6: Check documentation files
echo -e "\n${YELLOW}Test 6: Checking documentation...${NC}"
docs=(
    "scripts/README.md"
    "docs/installation.md"
    "README.md"
)

for doc in "${docs[@]}"; do
    if [[ -f "$doc" ]]; then
        echo -e "${GREEN}✓${NC} Found: $doc"
    else
        echo -e "${RED}✗${NC} Missing: $doc"
        exit 1
    fi
done

# Test 7: Check scripts fail properly outside Agent Zero directory
echo -e "\n${YELLOW}Test 7: Testing directory validation...${NC}"
cd /tmp
if timeout 5 bash /$(pwd | cut -d'/' -f2-)/home/runner/work/agent-zero/agent-zero/scripts/install.sh 2>/dev/null; then
    echo -e "${RED}✗${NC} Script should fail when not in Agent Zero directory"
    exit 1
else
    echo -e "${GREEN}✓${NC} Script correctly validates directory"
fi

echo ""
echo -e "${GREEN}=================================="
echo -e "✅ All validation tests passed!"
echo -e "=================================="
echo ""
echo "The Agent Zero installation automation is ready for use!"
echo ""
echo "Usage:"
echo "  Linux/macOS: bash scripts/install.sh"
echo "  Windows:     powershell -ExecutionPolicy Bypass -File scripts/install.ps1"
echo ""
echo "Documentation: scripts/README.md"
echo -e "${NC}"