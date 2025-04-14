# Installing Claude Code in the Terminal

This guide provides instructions for installing and setting up Claude Code in your terminal environment.

## System Requirements

- macOS, Linux, or Windows with WSL
- Python 3.8 or higher
- pip (Python package installer)

## Installation Steps

### 1. Install the Claude CLI

```bash
pip install claude-cli
```

For a specific version:

```bash
pip install claude-cli==1.0.0
```

### 2. Login and Authenticate

After installation, authenticate with your Anthropic account:

```bash
claude login
```

This will open a browser window where you can complete the authentication process.

### 3. Set Up Your API Key

If you have an Anthropic API key, you can set it as an environment variable:

```bash
# For Unix-based systems (macOS, Linux)
export ANTHROPIC_API_KEY="your-api-key-here"

# For Windows
set ANTHROPIC_API_KEY="your-api-key-here"
```

To make this persistent, add it to your shell profile (.bashrc, .zshrc, etc.)

### 4. Verify the Installation

Check that Claude Code is installed correctly:

```bash
claude --version
```

### 5. Basic Usage

Start a new Claude Code session:

```bash
claude code
```

Get help with available commands:

```bash
claude code --help
```

Run Claude Code in a specific directory:

```bash
cd /your/project/directory
claude code
```

### 6. Custom Configuration

You can create a configuration file at `~/.claude-cli/config.json` with settings like:

```json
{
  "default_model": "claude-3-opus-20240229",
  "history_dir": "~/.claude-cli/history",
  "default_parameters": {
    "temperature": 0.7,
    "max_tokens": 4096
  }
}
```

### 7. Additional Features

- Use `claude code --non-interactive` for non-interactive use
- Use `claude code --model claude-3-sonnet-20240229` to specify a model
- Use `claude code --thinking show` to see Claude's thinking process

### 8. Troubleshooting

If you encounter issues:

- Check your API key is correctly set
- Update to the latest version with `pip install -U claude-cli`
- Ensure your Python environment is correctly configured
- Check the Claude Code documentation at https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview

### 9. Getting Help

For more information or help:

- Run `claude code --help` for command options
- Visit the official documentation at https://docs.anthropic.com
- File issues at https://github.com/anthropics/claude-code/issues