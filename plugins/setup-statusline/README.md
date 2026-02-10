# Setup Statusline

Interactive wizard to configure a custom Claude Code statusline with folder display, git info, context bar, and last message.

## Installation

```bash
/plugin install setup-statusline@bvdr
```

> Requires the `bvdr` marketplace. Add it first if you haven't:
> ```bash
> /plugin marketplace add bvdr/claude-plugins
> ```

## Usage

After installing, invoke the skill:

```
/setup-statusline
```

The wizard will ask you to configure:

- **Folder display** — Last folder only / Last 2 folders / Full path / Hidden
- **Accent color** — Blue / Orange / Green / Gray
- **Git info** — Full status (branch + uncommitted + sync) / Branch only / Hidden
- **Last message** — Show your last prompt on a second line

## Example Output

```
📁myproject | 🔀main (2 files uncommitted, synced) | [███░░░░░░░] 15% of 200k tokens used
💬 Can you check if the edd license plugin is enabled...
```

## Features

- Visual context bar showing token usage
- Git branch with uncommitted count and sync status
- Color-coded with customizable accent colors
- Second line shows your last message for easy conversation identification
- Automatically updates your `settings.json`

## Requirements

- macOS or Linux
- `jq` for JSON parsing (`brew install jq`)
- `git` for branch info (optional)

## License

MIT
