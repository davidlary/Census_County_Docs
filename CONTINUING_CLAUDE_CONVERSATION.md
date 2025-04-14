# Continuing a Claude Code Conversation on Another Machine

This guide explains how to continue your Claude Code conversation across different machines.

## Prerequisites

- Claude Code installed on both machines (see CLAUDE_CODE_INSTALL.md)
- Authenticated with the same Anthropic account on both machines
- Access to the same project files (via Git, Dropbox, etc.)

## Option 1: Using Conversation History Files

Claude Code saves conversation history that can be transferred between machines.

### 1. Find Your Conversation History

On your first machine:

```bash
# The default location is ~/.claude-cli/history
ls -la ~/.claude-cli/history
```

Look for the most recent .json file with your conversation.

### 2. Transfer the History File

Copy this file to your second machine using any file transfer method:

- Cloud storage (Dropbox, Google Drive)
- Direct file transfer (SCP, SFTP)
- USB drive
- Email attachment

Example with SCP:
```bash
scp ~/.claude-cli/history/conversation-YYYYMMDD-HHMMSS.json user@secondmachine:~/.claude-cli/history/
```

### 3. Load the Conversation on the Second Machine

On your second machine:

```bash
claude code --continue conversation-YYYYMMDD-HHMMSS.json
```

## Option 2: Using Git Repository

If your project is in a Git repository (recommended):

### 1. Commit and Push Your Changes

On your first machine:

```bash
git add .
git commit -m "Save progress for continuation on another machine"
git push
```

### 2. Pull Changes on Second Machine

On your second machine:

```bash
git pull
```

### 3. Start a New Claude Code Session

```bash
claude code
```

Provide a brief summary of your previous work to help Claude understand the context.

## Option 3: Conversation Export/Import

### 1. Export the Conversation

Some Claude Code versions support exporting the full conversation:

```bash
claude code --export myconversation.json
```

### 2. Transfer the Export File

Move this file to your second machine.

### 3. Import the Conversation

On your second machine:

```bash
claude code --import myconversation.json
```

## Best Practices for Seamless Continuation

1. **Ensure File Consistency**: Make sure all project files are identical on both machines
2. **Use Git or Another Version Control System**: Track all changes to ensure consistency
3. **Summarize Work**: Briefly describe what you've accomplished when starting on the new machine
4. **Use Cloud Storage**: Keep your project in cloud storage (Dropbox, Google Drive) for automatic syncing
5. **Use GitHub Codespaces or Similar**: Consider cloud development environments that can be accessed from any machine

## Limitations

- Some context from the original conversation may be lost when switching machines
- File paths might need adjustment if your directory structure differs between machines
- The exact state of the conversation might not be perfectly preserved

## Additional Resources

- For more details, visit: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/tutorials
- File issues at: https://github.com/anthropics/claude-code/issues