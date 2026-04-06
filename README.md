# Kiro + OpenClaw Workflow

Two-agent development workflow: Kiro writes code, OpenClaw manages specs and does visual/functional QA.

## Setup (on the VM)

```bash
# Clone the repo
git clone <your-repo-url> ~/workflow
cd ~/workflow

# Make scripts executable
chmod +x bootstrap.sh

# Create your first project
./bootstrap.sh my-first-project
```

## Usage

1. Give OpenClaw an idea or spec
2. OpenClaw runs `./bootstrap.sh project-name` to create a project
3. OpenClaw writes a spec, updates STATUS.json → Kiro gets triggered
4. Kiro codes + tests → hands off to OpenClaw for QA
5. OpenClaw tests visually/functionally → reports back to Kiro
6. Loop until done

## Structure

```
~/workflow/
├── bootstrap.sh              # Creates new projects
├── openclaw/soul.md          # OpenClaw instructions
└── workflow-template/        # Blueprint copied per project

~/projects/
└── my-project/               # Each project is independent
    ├── .kiro/steering/       # Kiro instructions
    ├── orchestrator/         # Watcher + status scripts
    ├── specs/                # Specs, QA reports, handoffs
    └── src/                  # Code
```
