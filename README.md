# Kiro + OpenClaw Workflow

Two-agent dev workflow. Kiro writes code, OpenClaw manages specs and does QA.

## Setup

```bash
git clone <your-repo-url> ~/workflow
cd ~/workflow
cp .env.example .env
nano .env
chmod +x setup.sh
./setup.sh my-project
```

## How it works

```
~/projects/my-project/
├── SPEC.md              ← Project spec (you + OpenClaw create this)
├── ticket.md            ← Agent writes this when done (watcher archives it)
├── done.md              ← OpenClaw creates this when project is complete
├── archive/             ← All past tickets + worker.md (whose turn)
├── templates/           ← Reference for spec/ticket/done format
├── watcher.sh           ← Alternates between agents automatically
├── .kiro/steering/      ← Kiro instructions
└── src/                 ← Code
```

1. Create the spec with OpenClaw in the dashboard
2. Start the watcher: `~/projects/my-project/watcher.sh`
3. Watcher triggers OpenClaw → writes first ticket for Kiro
4. Watcher triggers Kiro → builds, writes ticket for OpenClaw
5. Watcher triggers OpenClaw → tests, writes ticket (issues) or done.md
6. Loop until done.md → project complete

## Watcher

```bash
~/projects/my-project/watcher.sh          # start
ps aux | grep watcher.sh                   # check
tail -f ~/projects/my-project/watcher.log  # logs
```

Retries 3x on failure, then exits with restart instructions.
Saves state in `archive/worker.md` so it can resume after crash.

## Files

| File | Purpose |
|------|---------|
| `soul.md` | OpenClaw instructions (copied to agent workspace) |
| `TOOLS.md` | Tools reference for all agents |
| `copy/` | Project template (copied per project) |
| `.env.example` | Credentials template |
