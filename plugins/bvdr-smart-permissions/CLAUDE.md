# smart-permissions plugin is active

Two-layer permission system running on your tool calls:
- **Layer 1 (instant):** Auto-allows known-safe operations (Read, Grep, git, tests, etc.). Everything else passes through.
- **Layer 2 (AI fallback):** Evaluates remaining commands via Claude Haiku against a policy file. ALLOW = auto-approved. DENY = shows permission dialog so user decides. Failures = normal dialog.

Customize rules: edit `permission-policy.md` in the plugin folder.

Debug log: `<your-claude-config>/hooks/smart-permissions.log` (e.g. `~/.claude/hooks/smart-permissions.log`)
Verbose Layer 1 logging: `export SMART_PERMISSIONS_DEBUG=1`
