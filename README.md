# Kiro Workflow v2

Seven Kiro agents build your project in a pipeline. A watcher runs them automatically.

## Setup

```bash
cd ~/workflow
chmod +x setup.sh
./setup.sh my-project
```

## How it works

```
~/projects/my-project/
├── SPEC.md              ← You write this (what to build)
├── ticket.md            ← Agents write this (what was done / what to fix)
├── done.md              ← Project lead creates this when complete
├── archive/             ← All past tickets
├── reports/             ← Agent reports (per round)
├── templates/           ← Format reference for spec/ticket/done
├── watcher.sh           ← Runs the pipeline automatically
├── kill-watcher.sh      ← Stops the watcher
├── .kiro/agents/        ← Agent configs
└── src/                 ← Code goes here
```

## Pipeline

```
coder → code-verifier → backend-tester → frontend-tester → visual-qa → functional-qa → project-lead
  ↑                                                                                         |
  └──────────────────────────────── ticket.md (if issues) ─────────────────────────────────┘
```

1. Write `SPEC.md` with what you want built
2. Start the watcher: `./watcher.sh`
3. Coder builds everything, writes ticket
4. Code verifier checks the codebase against spec, fixes gaps, updates ticket
5. Each QA agent runs in sequence — agents self-skip if nothing to test
6. If any agent finds a blocker, it writes ticket.md and remaining agents are skipped
7. Project lead reviews all reports, writes ticket for coder or creates done.md
8. Loop until done

## Agents

| Agent | Role |
|-------|------|
| coder | Builds features, writes basic tests, fixes bugs |
| code-verifier | Verifies codebase against spec, fixes missing features and code quality issues |
| backend-tester | Creates and runs server-side tests (unit, integration, API, validation, auth) |
| frontend-tester | Creates and runs client-side tests (components, forms, routing, a11y, i18n) |
| visual-qa | Screenshots every page, checks rendering, responsive, dark/light mode |
| functional-qa | Tests user flows, UX, security basics, production build |
| project-lead | Reviews all reports, writes prioritized ticket or creates done.md |
| spec-writer | Creates detailed specs from your ideas (interactive) |
| watchdog | Unsticks agents that get blocked (automatic) |

## Watcher

```bash
~/projects/my-project/watcher.sh          # start
~/projects/my-project/kill-watcher.sh     # stop
tail -f ~/projects/my-project/watcher.log # logs
```

## Key improvements over v1

- QA split into 4 focused agents instead of 1 overloaded agent
- Code verifier catches spec gaps and quality issues before QA even runs
- Each agent self-skips if there's nothing relevant to test (fast early rounds)
- Early exit: blocker found → skip remaining agents → ticket back to coder
- Project lead synthesizes all reports into one prioritized ticket
- Reports directory gives full visibility into what each agent found
- Coder prompt is lean — project requirements live in SPEC.md, not the agent
- PID-based kill script instead of pkill -f
