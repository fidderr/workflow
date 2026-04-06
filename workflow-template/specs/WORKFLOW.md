# Agent Workflow: Kiro + OpenClaw

## Roles
- **Admin (You):** Delivers the initial idea or feature request
- **OpenClaw PM:** Refines specs, manages the project, performs visual/functional QA
- **Kiro:** Writes code, writes tests, handles implementation

---

## Project Structure
Each project gets its own folder with this layout:
```
projects/
└── my-project/
    ├── specs/
    │   ├── STATUS.json
    │   ├── WORKFLOW.md          ← You are here
    │   ├── templates/
    │   ├── active/
    │   ├── questions/
    │   ├── qa-reports/
    │   ├── handoffs/
    │   └── archive/
    ├── orchestrator/
    │   ├── watcher.sh
    │   ├── update-status.sh
    │   └── orchestrator.log
    ├── .kiro/
    │   └── steering/
    │       └── agent-workflow.md
    └── src/                     ← Your code goes here
```

All paths are relative to the project root. Scripts auto-detect their location.

---

## Workflow Cycle

### Phase 1: Spec Creation
1. Admin delivers idea to OpenClaw PM
2. OpenClaw PM creates a spec using `specs/templates/PROJECT_SPEC_TEMPLATE.md`
3. OpenClaw fills gaps, adds detail, defines "definition of done"
4. OpenClaw places spec in `specs/active/`
5. OpenClaw updates STATUS.json → orchestrator triggers Kiro

### Phase 2: Implementation
1. Kiro reads STATUS.json to find the spec
2. Kiro implements the code + writes all tests possible
3. If Kiro has questions → drops a file in `specs/questions/`
4. OpenClaw PM monitors questions and answers them
5. When done, Kiro creates a handoff in `specs/handoffs/` and updates STATUS.json

### Phase 3: QA
1. OpenClaw reads the handoff from `specs/handoffs/`
2. OpenClaw sets up a dev build and tests:
   - Functional testing (does everything work?)
   - Visual testing (does everything look right?)
   - Logic testing (does everything make sense?)
   - Enhancement spotting (anything missing?)
3. OpenClaw creates a QA report in `specs/qa-reports/`
4. If issues found → updates STATUS.json → back to Phase 2
5. If all clear → Phase 4

### Phase 4: Delivery
1. OpenClaw confirms Definition of Done is met
2. OpenClaw creates final delivery doc
3. Spec moves to `specs/archive/`
4. STATUS.json set to `done` → orchestrator exits

---

## Communication Rules
- All communication goes through files in `specs/`
- Each round is numbered (Round 1, Round 2, etc.)
- Blockers must be fixed before anything else
- Enhancements can be added freely during bug-fix rounds — no approval needed
- Once spec is met with zero bugs, max 5 polish rounds for enhancements, then ship
- Questions should be answered within the same round

## Naming Conventions
- Specs: `specs/active/SPEC-001-project-name.md`
- QA Reports: `specs/qa-reports/QA-R1-project-name.md`
- Questions: `specs/questions/Q-001-short-description.md`
- Handoffs: `specs/handoffs/HANDOFF-R1-project-name.md`

## Orchestrator
The watcher script auto-detects the project root and monitors STATUS.json:
```bash
./orchestrator/watcher.sh
# Or run in background:
./orchestrator/watcher.sh &
```
It triggers the right agent on phase changes and exits when the project is done.
