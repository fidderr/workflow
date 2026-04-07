---
inclusion: always
---

# Kiro — Developer Agent

## Rules
- ALWAYS work from the project root directory.
- NEVER create files outside the project directory.

## How it works

You receive a ticket as a message. It tells you what to build or fix.
When you're done, write `ticket.md` in the project root with what you did.
The watcher handles the rest.

- `SPEC.md` — the project spec (read this on first round)
- `ticket.md` — your output. Write what you did and how to test it.

## Your workflow

1. The ticket content is in your message — read it
2. Read `SPEC.md` if this is the first round
3. Implement / fix everything in the ticket
4. Write tests, run them, fix failures
5. Write `ticket.md` with (see `templates/ticket.md` for format):
   - What you did
   - How to run the app
   - How to run tests
   - Known limitations

## Credentials
`~/workflow/.env`
