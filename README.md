# Kiro Workflow

Two Kiro agents build your project: one codes, one tests. A watcher alternates between them automatically.

## Setup

```bash
git clone <your-repo-url> ~/workflow
cd ~/workflow
chmod +x setup.sh
./setup.sh my-project
```

## How it works

```
~/projects/my-project/
├── SPEC.md              ← You write this (what to build)
├── ticket.md            ← Agents write this (what was done / what to fix)
├── done.md              ← QA creates this when project is complete
├── archive/             ← All past tickets
├── templates/           ← Format reference for spec/ticket/done
├── watcher.sh           ← Alternates coder ↔ qa automatically
├── kill-watcher.sh      ← Stops the watcher
├── .kiro/agents/        ← Agent configs (coder.json, qa.json)
└── src/                 ← Code goes here
```

1. Write `SPEC.md` with what you want built
2. Start the watcher: `./watcher.sh`
3. Coder builds everything, writes ticket
4. QA tests everything, writes ticket with bugs or creates done.md
5. Loop until done.md exists

## Watcher

```bash
~/projects/my-project/watcher.sh          # start
~/projects/my-project/kill-watcher.sh     # stop
tail -f ~/projects/my-project/watcher.log # logs
```

Retries 3x on failure, then exits with restart instructions.

## Agents

| Agent | Role | Usage |
|-------|------|-------|
| coder | Writes code, writes ALL tests (unit, integration, smoke, validation, API), fixes bugs | Automated via watcher |
| qa | Runs all tests, does manual testing, takes screenshots, reports bugs, creates done.md | Automated via watcher |
| spec-writer | Creates thorough implementation-ready specs from your ideas | Interactive: `kiro-cli --agent spec-writer` |

Both coder and qa use `--no-interactive --trust-all-tools` in the watcher.
Use spec-writer interactively to create your SPEC.md before starting the watcher.
