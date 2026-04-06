# Kiro + OpenClaw Workflow

Two-agent development workflow: Kiro writes code, OpenClaw manages specs and does visual/functional QA. An orchestrator watches for phase changes and triggers the right agent automatically.

## Setup (on the VM)

```bash
git clone <your-repo-url> ~/workflow
cd ~/workflow
chmod +x vm-setup.sh
./vm-setup.sh
```

This installs prerequisites (git, python3, node), sets up UI testing tools (Playwright, xdotool, scrot), and configures git.

After setup, copy `credentials.example.md` to `credentials.md` and fill in your values. The credentials file is gitignored.

## Usage

```bash
# Create a new project
./bootstrap.sh my-project

# Optionally start the watcher immediately
./bootstrap.sh my-project --start-watcher
```

Then:
1. Give OpenClaw an idea or spec
2. OpenClaw writes a full spec, updates STATUS.json → orchestrator triggers Kiro
3. Kiro implements + tests → hands off to OpenClaw for QA
4. OpenClaw tests (using Playwright for web, xdotool for desktop) → reports issues
5. Loop until done → OpenClaw notifies Admin via WhatsApp

## Structure

```
~/workflow/                       ← This repo
├── bootstrap.sh                  # Creates new projects from template
├── vm-setup.sh                   # One-time VM setup
├── credentials.example.md        # Template for credentials.md
├── TOOLS.md                      # All tools reference (WhatsApp, Whisper, TTS, Playwright, etc.)
├── openclaw/soul.md              # OpenClaw agent instructions
├── .kiro/steering/               # Kiro steering rules
└── workflow-template/            # Blueprint copied per project
    ├── orchestrator/             # Watcher + status update scripts
    └── specs/                    # Templates, workflow docs

~/projects/                       ← Created projects
└── my-project/
    ├── .kiro/steering/           # Kiro instructions (copied from template)
    ├── orchestrator/             # Watcher + status scripts
    ├── specs/                    # Specs, QA reports, handoffs, templates
    └── src/                      # Code goes here
```

## Key Files

| File | Purpose |
|------|---------|
| `TOOLS.md` | All tools: WhatsApp, Whisper, TTS, Playwright, Computer Use, config |
| `openclaw/soul.md` | OpenClaw's full instructions (PM + QA role) |
| `.kiro/steering/agent-workflow.md` | Kiro's instructions (developer role) |
| `credentials.example.md` | Template for secrets (copy to `credentials.md`) |
