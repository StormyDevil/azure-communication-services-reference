#!/bin/bash
set -e

echo "=========================================="
echo "Setting up development environment..."
echo "=========================================="

# Install Azure Functions Core Tools
echo "Installing Azure Functions Core Tools..."
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
echo "deb [arch=amd64] https://packages.microsoft.com/debian/11/prod bullseye main" | sudo tee /etc/apt/sources.list.d/dotnetdev.list
sudo apt-get update && sudo apt-get install -y azure-functions-core-tools-4

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install main application dependencies
echo "Installing main application dependencies..."
if [ -f "src/python/requirements.txt" ]; then
    pip install -r src/python/requirements.txt
fi

# Install development tools
echo "Installing development tools..."
pip install black isort mypy pylint pytest

echo ""
echo "=========================================="
echo "Verifying installations..."
echo "=========================================="
echo "Python: $(python --version)"
echo "Azure CLI: $(az --version | head -1)"
echo "Bicep: $(az bicep version)"
echo "Functions Core Tools: $(func --version)"
echo ""
echo "Setup complete! Run 'az login' to authenticate."
