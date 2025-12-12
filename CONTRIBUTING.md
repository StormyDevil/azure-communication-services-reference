# Contributing to Azure Communication Services Reference Architecture

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)

## Code of Conduct

This project adheres to the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- Azure subscription with Contributor access
- Azure CLI 2.50+ with Bicep CLI
- PowerShell 7+
- Python 3.9+
- Git 2.30+
- VS Code with recommended extensions

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/azure-communication-services-reference.git
cd azure-communication-services-reference
```

3. Add upstream remote:

```bash
git remote add upstream https://github.com/ORIGINAL_ORG/azure-communication-services-reference.git
```

## Development Setup

### Install Dependencies

```bash
# Python dependencies
pip install -r src/python/requirements.txt

# Install pre-commit hooks
pip install pre-commit
pre-commit install
```

### Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
code .env
```

### Validate Setup

```bash
# Validate Bicep templates
bicep build infra/bicep/main.bicep
bicep lint infra/bicep/main.bicep

# Run Python tests
pytest tests/ -v
```

## Making Changes

### Branch Naming

Use descriptive branch names:

- `feature/add-email-capability`
- `fix/sms-retry-logic`
- `docs/update-waf-assessment`
- `refactor/modularize-bicep`

### Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

Examples:

```
feat(sms): add bulk SMS endpoint

- Add /api/v1/sms/send-bulk endpoint
- Support up to 100 recipients per request
- Include delivery report aggregation

Closes #42
```

## Pull Request Process

1. **Update your fork**:

```bash
git fetch upstream
git rebase upstream/main
```

2. **Create feature branch**:

```bash
git checkout -b feature/your-feature
```

3. **Make changes** following coding standards

4. **Test your changes**:

```bash
# Validate Bicep
bicep build infra/bicep/main.bicep

# Run tests
pytest tests/ -v

# Check linting
pylint src/python/
```

5. **Commit and push**:

```bash
git add .
git commit -m "feat(scope): description"
git push origin feature/your-feature
```

6. **Create Pull Request** on GitHub

### PR Requirements

- [ ] All tests pass
- [ ] Bicep templates validate successfully
- [ ] Documentation updated (if applicable)
- [ ] WAF assessment updated (if architecture changes)
- [ ] No secrets or credentials in code
- [ ] Follows coding standards

## Coding Standards

### Bicep

- Use 2-space indentation
- Add `@description()` decorators for all parameters
- Group resources logically
- Include comprehensive outputs
- Follow CAF naming conventions

```bicep
@description('Environment name for resource naming')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${projectName}${environment}'
  // ...
}
```

### Python

- Follow PEP 8 style guide
- Use type hints
- Add docstrings for all public functions
- Use logging instead of print statements

```python
def send_sms(
    from_number: str,
    to_number: str,
    message: str,
    enable_delivery_report: bool = True
) -> Dict[str, Any]:
    """
    Send an SMS message.
    
    Args:
        from_number: Sender phone number (E.164 format)
        to_number: Recipient phone number (E.164 format)
        message: Message content
        enable_delivery_report: Request delivery confirmation
    
    Returns:
        Send result with message ID and status
    
    Raises:
        HttpResponseError: If SMS fails to send
    """
    # Implementation
```

### PowerShell

- Use 4-space indentation
- Follow PSScriptAnalyzer rules
- Add comment-based help
- Use approved verbs

```powershell
<#
.SYNOPSIS
    Deploys the ACS reference architecture.

.DESCRIPTION
    Detailed description here.

.PARAMETER Environment
    Target environment (dev, staging, prod).

.EXAMPLE
    ./deploy.ps1 -Environment dev
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment
)
```

## Testing Guidelines

### Unit Tests

```python
# tests/test_identity_service.py
import pytest
from unittest.mock import Mock, patch

def test_create_user_success():
    """Test successful user creation."""
    # Arrange
    mock_client = Mock()
    mock_client.create_user.return_value = Mock(properties={"id": "test-user"})
    
    # Act
    service = ACSIdentityService(config)
    service.client = mock_client
    user = service.create_user()
    
    # Assert
    assert user.properties["id"] == "test-user"
    mock_client.create_user.assert_called_once()
```

### Integration Tests

```python
# tests/integration/test_sms_integration.py
import pytest
import os

@pytest.mark.integration
@pytest.mark.skipif(not os.environ.get("ACS_ENDPOINT"), reason="ACS not configured")
def test_send_sms_integration():
    """Test actual SMS sending (requires ACS resource)."""
    # Test implementation
```

### Bicep Tests

```bash
# Validate syntax
bicep build infra/bicep/main.bicep

# Check for linting issues
bicep lint infra/bicep/main.bicep

# What-if deployment
az deployment group what-if \
    --resource-group rg-test \
    --template-file infra/bicep/main.bicep \
    --parameters infra/bicep/parameters/dev.bicepparam
```

## Documentation

### Update Documentation For

- New features or capabilities
- API changes
- Configuration changes
- Architecture changes (update WAF assessment)

### Documentation Structure

```
docs/
├── architecture/          # Architecture decisions
├── waf-assessment/       # WAF compliance
├── api/                  # API documentation
└── guides/               # How-to guides
```

## Questions?

- Open an [issue](https://github.com/ORG/REPO/issues) for bugs or feature requests
- Start a [discussion](https://github.com/ORG/REPO/discussions) for questions
- Check existing issues before creating new ones

Thank you for contributing! 🎉
