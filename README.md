# Kiro + OpenClaw Workflow

Two-agent development workflow: Kiro writes code, OpenClaw manages specs and does visual/functional QA. An orchestrator watches for phase changes and triggers the right agent automatically.

## Setup (on the VM)

```bash
git clone <your-repo-url> ~/workflow
cd ~/workflow

# Fill in credentials first
cp .env.example .env
nano .env

# Then run setup
chmod +x setup.sh
./setup.sh my-agent
```

This reads your API key and model from `.env` and handles everything: system dependencies, Node.js, OpenClaw + config + agent creation, Kiro CLI + auth, Playwright, and git config.

## Usage

1. Run setup once: `./setup.sh my-agent`
2. Open the OpenClaw agent: `openclaw tui --session my-agent`
3. Give it your idea or spec
4. OpenClaw bootstraps the project, writes the spec, and triggers Kiro automatically
5. Kiro implements + tests → OpenClaw does QA → loop until done
6. OpenClaw notifies you via WhatsApp when it's finished

## Watcher

The watcher monitors STATUS.json and triggers the right agent on phase changes. Setup starts it automatically.

```bash
# Start watcher (opens in its own terminal if GUI available)
~/projects/my-project/orchestrator/watcher.sh

# Check if it's running
ps aux | grep watcher.sh

# Re-trigger a phase change (if watcher is already running)
~/projects/my-project/orchestrator/update-status.sh ready-for-kiro openclaw "Retry round 1"
~/projects/my-project/orchestrator/update-status.sh ready-for-qa kiro "Retry QA"

# View live logs
tail -f ~/projects/my-project/orchestrator/orchestrator.log
```

The watcher retries up to 3 times if an agent fails. After that it exits and logs how to restart.

## Structure

```
~/workflow/                       ← This repo
├── setup.sh                      # Full setup (run this first)
├── bootstrap.sh                  # Creates new projects from template
├── .env.example                  # Template for .env (credentials)
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
| `.env.example` | Template for secrets (copy to `.env`) |
