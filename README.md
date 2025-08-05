# AI Code Assistant

A powerful bash-based AI coding assistant that acts like Claude Code, capable of creating, editing, and managing files in your workspace using AI assistance.

## ✨ Features

- **Interactive Mode**: Chat-like interface for ongoing development work
- **File Operations**: Create, edit, and analyze files automatically
- **Workspace Awareness**: Understands your project structure and context
- **Multiple AI Commands**: analyze, create, edit, refactor, test, debug, explain
- **No Dependencies**: Only requires `curl` (no `jq` needed)
- **Environment Variable Support**: Secure API key management
- **Session Logging**: Track all operations and changes
- **Backup Support**: Automatic file backups before modifications

## 🚀 Quick Start

### 1. Installation

```bash
# Download the script
wget https://example.com/aicode.sh
# or
curl -O https://example.com/aicode.sh

# Make it executable
chmod +x aicode.sh
```

### 2. Setup

Set your API key as an environment variable:

```bash
export COPILOT_KEY="your-api-key-here"

# Add to your shell profile for persistence
echo 'export COPILOT_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

Run the interactive setup:

```bash
./aicode.sh --setup
```

### 3. Start Using

```bash
# Start interactive mode (default)
./aicode.sh

# Or run specific commands
./aicode.sh create "A Python web scraper for news articles"
./aicode.sh analyze "Review the project architecture"
./aicode.sh edit -f main.py "Add error handling"
```

## 📖 Usage

### Interactive Mode

The tool defaults to interactive mode when no parameters are provided:

```bash
./aicode.sh
```

```
AI Code Assistant - Interactive Mode
Type 'help' for commands, 'exit' to quit

ai-code> create "A REST API with authentication"
ai-code> edit main.py "Add logging functionality"
ai-code> test "Generate unit tests for the auth module"
ai-code> workspace
ai-code> exit
```

### Command Line Usage

```bash
# Syntax
./aicode.sh [OPTIONS] [COMMAND] "Description"

# Examples
./aicode.sh create "A React component for user profiles"
./aicode.sh edit -f "*.js" --backup "Convert to ES6 modules"
./aicode.sh analyze --verbose "Security review of authentication"
./aicode.sh refactor -f src/ "Improve error handling"
```

## 🛠️ Commands

| Command | Description | Example |
|---------|-------------|---------|
| `create` | Generate new files or projects | `create "A Python CLI tool"` |
| `edit` | Modify existing files | `edit -f main.py "Add validation"` |
| `analyze` | Code review and analysis | `analyze "Check for security issues"` |
| `refactor` | Improve code structure | `refactor "Clean up the database layer"` |
| `test` | Generate test suites | `test "Unit tests for user service"` |
| `debug` | Help with debugging | `debug "Fix the login error"` |
| `explain` | Code education | `explain "How does JWT work?"` |
| `interactive` | Start interactive mode | `interactive` |

## ⚙️ Options

### General Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose logging
- `-w, --workspace` - Show workspace overview
- `--dry-run` - Show what would be done without executing
- `--setup` - Run interactive configuration

### API Configuration

- `-e, --endpoint URL` - API endpoint URL
- `-k, --key KEY` - API key (or use COPILOT_KEY env var)
- `-m, --model MODEL` - AI model to use
- `-t, --temperature NUM` - Response creativity (0.0-2.0)
- `-T, --max-tokens NUM` - Maximum response length

### File Operations

- `-f, --files FILES` - Target files (comma-separated)
- `-d, --directory DIR` - Working directory
- `-l, --language LANG` - Programming language hint
- `-y, --yes` - Auto-confirm operations
- `--backup` - Create backups before editing

## 🔧 Configuration

### Environment Variables

The tool uses the `COPILOT_KEY` environment variable for API authentication:

```bash
export COPILOT_KEY="your-api-key-here"
```

### Config File

Configuration is stored in `~/.ai-code-config`:

```bash
# AI Code Assistant Configuration
API_ENDPOINT="https://api.openai.com/v1/chat/completions"
# API_KEY is using COPILOT_KEY environment variable
DEFAULT_MODEL="gpt-4"
DEFAULT_TEMPERATURE="0.1"
DEFAULT_MAX_TOKENS="4000"
```

### Supported APIs

The tool works with OpenAI-compatible APIs:

- **OpenAI API**: `https://api.openai.com/v1/chat/completions`
- **Azure OpenAI**: `https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2024-02-15-preview`
- **LLM Forge**: `https://xxx/assistants/your-assistant-id/completions`
- **Local APIs**: `http://localhost:8000/v1/chat/completions`

## 📁 File Management

### Automatic File Creation

The tool can automatically create files from AI responses:

```bash
ai-code> create "A Python Flask app with authentication"
# Creates app.py, requirements.txt, etc.

ai-code> edit -f app.py "Add rate limiting"
# Modifies app.py with AI suggestions
```

### Backup System

Enable backups to protect your files:

```bash
./aicode.sh edit --backup -f important.py "Refactor the main function"
# Creates important.py.backup.20240805_143022 before changes
```

### Session Logging

All operations are logged in `.ai-session.log`:

```
2024-08-05 14:30:22 [SESSION] Started in /home/user/project
2024-08-05 14:30:25 [ACTION] File operation: app.py
2024-08-05 14:30:30 [SUCCESS] Created/updated: requirements.txt
```

## 🎯 Examples

### Web Development

```bash
# Create a full-stack project
./aicode.sh create "A Node.js REST API with Express and MongoDB"

# Add authentication
./aicode.sh edit -f "*.js" "Add JWT authentication middleware"

# Generate tests
./aicode.sh test "Create integration tests for the API endpoints"
```

### Python Development

```bash
# Start interactive session
./aicode.sh

ai-code> create "A Python data analysis script with pandas"
ai-code> edit -f analysis.py "Add data visualization with matplotlib"
ai-code> test "Generate pytest tests for data processing functions"
ai-code> explain "How does the correlation analysis work?"
```

### Code Review

```bash
# Analyze entire project
./aicode.sh analyze "Review code quality and suggest improvements"

# Security review
./aicode.sh analyze -f "auth*.py" "Check for security vulnerabilities"

# Performance analysis
./aicode.sh analyze --verbose "Identify performance bottlenecks"
```

## 🛡️ Security

### API Key Management

- **Never commit API keys** to version control
- Use environment variables for secure storage
- Rotate keys regularly
- Use the minimum required permissions

### File Safety

- Use `--backup` for important files
- Review changes with `--dry-run` first
- Check session logs for operation history
- Test in non-production environments first

## 🔍 Troubleshooting

### Common Issues

**API Authentication Errors (401)**
```bash
# Check if API key is set
echo $COPILOT_KEY

# Verify endpoint configuration
cat ~/.ai-code-config

# Test API connection manually
curl -H "Authorization: Bearer $COPILOT_KEY" $API_ENDPOINT
```

**Permission Errors**
```bash
# Make script executable
chmod +x aicode.sh

# Check file permissions
ls -la aicode.sh
```

**Missing Dependencies**
```bash
# Check for curl
curl --version

# Install if missing (Ubuntu/Debian)
sudo apt install curl
```

### Debug Mode

Use verbose mode for detailed debugging:

```bash
./aicode.sh -v create "Debug this issue"
```

### Log Analysis

Check session logs for issues:

```bash
tail -f .ai-session.log
```

## 🤝 Contributing

### Reporting Issues

1. Include the command that failed
2. Provide verbose output (`-v` flag)
3. Share relevant log entries
4. Specify your system (OS, bash version)

### Feature Requests

The tool is designed to be extensible. Common requests:

- Additional AI model support
- Enhanced file parsing
- Custom prompt templates
- Integration with git workflows

## 📄 License

This project is released under the MIT License. See LICENSE file for details.

## 🔗 Related Projects

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) - Official Anthropic coding assistant
- [GitHub Copilot CLI](https://github.com/github/gh-copilot) - GitHub's AI assistant
- [Aider](https://github.com/paul-gauthier/aider) - AI pair programming tool

## 📞 Support

For support and questions:

1. Check the troubleshooting section
2. Review session logs
3. Test with verbose mode
4. Verify API configuration

---

**Happy Coding! 🚀**
