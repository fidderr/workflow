# Credentials

Copy this file to `credentials.md` and fill in your actual values.
`credentials.md` is gitignored and will never be pushed.

## System
- **Sudo password:** your-sudo-password-here

## Owner Contact (WhatsApp)
- **Owner name:** your-name-here
- **Owner phone:** +31600000000
- **WhatsApp session key:** agent:whatsapp:whatsapp:direct:+31600000000

To find the session ID, look up the phone number in the sessions file:
```bash
cat /home/claw/.openclaw/agents/whatsapp/sessions/sessions.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    if '<owner-phone>' in k:
        print(f'sessionKey: {k}, sessionId: {v[\"sessionId\"]}')"
```

## API Keys
- **OpenRouter API key:** sk-or-xxxxxxxxxxxxxxxxxxxx
- **Kiro API key:** xxxxxxxxxxxxxxxxxxxx

## Services
- **GitHub token:** ghp_xxxxxxxxxxxxxxxxxxxx
- **Database password:** your-db-password-here

## Notes
Add any other credentials, tokens, or secrets you need here.
Keep this file on the VM only — never commit it.
