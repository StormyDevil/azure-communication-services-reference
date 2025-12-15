#!/bin/bash
set -e

echo "=========================================="
echo "Setting up development environment..."
echo "=========================================="

# Create Python virtual environment
echo "Creating Python virtual environment..."
python -m venv .venv
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install main application dependencies
echo "Installing main application dependencies..."
pip install -r src/python/requirements.txt

# Install Azure Functions dependencies
echo "Installing Azure Functions dependencies..."
if [ -f "src/python/functions/requirements.txt" ]; then
    pip install -r src/python/functions/requirements.txt
fi

# Install development tools
echo "Installing development tools..."
pip install black isort mypy pylint pytest pytest-cov

# Set up pre-commit hooks (if .pre-commit-config.yaml exists)
if [ -f ".pre-commit-config.yaml" ]; then
    echo "Setting up pre-commit hooks..."
    pip install pre-commit
    pre-commit install
fi

# Create .env file from example if it doesn't exist
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Verify Azure CLI installation
echo ""
echo "Verifying tool installations..."
echo "----------------------------------------"
echo "Azure CLI version:"
az --version | head -1

echo "Bicep CLI version:"
az bicep version

echo "PowerShell version:"
pwsh --version

echo "Azure Functions Core Tools version:"
func --version

echo "Python version:"
python --version

echo ""
echo "=========================================="
echo "Development environment setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run 'az login' to authenticate with Azure"
echo "  2. Run 'source .venv/bin/activate' to activate the virtual environment"
echo "  3. Run 'pwsh ./scripts/deploy.ps1 -Environment dev' to deploy"
echo ""
