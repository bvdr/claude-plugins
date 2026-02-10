# Voice Alerts

Enable verbal notifications using macOS text-to-speech to alert when Claude needs attention or completes tasks.

## Installation

```bash
/plugin install macos-use-voice-alerts@bvdr
```

> Requires the `bvdr` marketplace. Add it first if you haven't:
> ```bash
> /plugin marketplace add bvdr/claude-plugins
> ```

## Usage

After installing, invoke the skill:

```
/enable-voice-alerts
```

With a custom voice:

```
/enable-voice-alerts Zarvox
```

## What It Does

Sets up spoken notifications for Claude Code events:

- **Permission requests** — "Claude needs your permission"
- **Questions** — "Claude has a question for you"
- **Idle prompts** — "Claude is waiting for your input"
- **Session completion** — "Claude has finished"

No restart needed — hooks take effect immediately.

## Popular Voice Options

| Voice | Style | Use Case |
|-------|-------|----------|
| `Zarvox` | Robotic | Fun, classic sci-fi feel |
| `Whisper` | Quiet | Discrete, subtle notifications |
| `Good News` | Upbeat | Positive task completions |
| `Bad News` | Ominous | Error notifications |
| `Jester` | Comedic | Playful interactions |
| `Samantha` | Natural | Professional settings |

To see all available voices on your system:

```bash
say -v "?"
```

## Requirements

- macOS (uses the `say` command)

## License

MIT
