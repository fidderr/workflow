# Kiro + OpenClaw Workflow

Two-agent development workflow: Kiro writes code, OpenClaw manages specs and does visual/functional QA. An orchestrator watches for phase changes and triggers the right agent automatically.

## Setup (on the VM)

```bash
git clone <your-repo-url> ~/workflow
cd ~/workflow
chmod +x setup.sh
./setup.sh my-agent
```

This handles everything: system dependencies, Node.js, OpenClaw + agent creation, Kiro CLI + auth, Playwright, git config, and credentials template.

After setup, edit `credentials.md` with your actual values.

## Usage

1. Run setup once: `./setup.sh my-agent`
2. Open the OpenClaw agent: `openclaw tui --session my-agent`
3. OpenClaw bootstraps the project, writes the spec, and triggers Kiro automatically
4. Kiro implements + tests → OpenClaw does QA → loop until done
5. OpenClaw notifies you via WhatsApp when it's finished

## Structure

```
~/workflow/                       ← This repo
├── setup.sh                      # Full setup (run this first)
├── bootstrap.sh                  # Creates new projects from template
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
