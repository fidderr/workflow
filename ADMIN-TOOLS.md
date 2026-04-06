# Admin Tools

> These tools are for the administrator (Owner) only.

---

## File Locations

| Resource            | Path                                                        |
|---------------------|-------------------------------------------------------------|
| Config              | `/home/claw/.openclaw/openclaw.json`                        |
| Auth profiles       | `/home/claw/.openclaw/agents/main/agent/auth-profiles.json` |
| WhatsApp sessions   | `/home/claw/.openclaw/agents/whatsapp/sessions/`            |
| Media (voice/photo) | `/home/claw/.openclaw/media/inbound/`                       |
| Workspace           | `/home/claw/.openclaw/workspace-whatsapp/`                  |
| Memory              | `/home/claw/.openclaw/workspace-whatsapp/MEMORY.md`         |
| Heartbeat           | `/home/claw/.openclaw/workspace-whatsapp/HEARTBEAT.md`      |

---

## Sessions

### List all sessions

```bash
cat /home/claw/.openclaw/agents/whatsapp/sessions/sessions.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    print(f'{k}: session={v[\"sessionId\"]}')"
```

### Read a session transcript

```bash
cat /home/claw/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl
```

### Look up a specific user by phone number

Use the Owner's phone number from `credentials.md`:

```bash
OWNER_PHONE="<owner-phone-from-credentials>"
cat /home/claw/.openclaw/agents/whatsapp/sessions/sessions.json | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
for k, v in d.items():
    if '$OWNER_PHONE' in k:
        sid = v['sessionId']
        ts = datetime.datetime.fromtimestamp(v['updatedAt']/1000).strftime('%H:%M:%S')
        print(f'Session: {sid}, Last active: {ts}')
"
```

### Summarize recent messages from a session

```bash
python3 << 'EOF'
import json

with open('/home/claw/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl', 'r') as f:
    lines = f.readlines()

for line in lines[-20:]:
    data = json.loads(line.strip())
    if data.get('type') == 'message':
        msg = data['message']
        role = msg['role']
        content = msg.get('content', [])
        if role == 'user':
            text = content[0].get('text', '') if content else ''
            actual = text.split('\n')
            print(f'User: {actual[-1][:150]}')
        elif role == 'assistant':
            texts = [t['text'] for t in content if t.get('type') == 'text']
            for t in texts:
                print(f'Assistant: {t[:150]}')
EOF
```

### Reset a session

Moving the session file forces a fresh session on the user's next message:

```bash
# Find session files
ls -la /home/claw/.openclaw/agents/whatsapp/sessions/*.jsonl

# Move to .bak to force reset
mv /home/claw/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl \
   /home/claw/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl.bak
```

---

## Configuration

Config file: `/home/claw/.openclaw/openclaw.json`

Key settings:

| Setting                        | Purpose                                         |
|--------------------------------|-------------------------------------------------|
| `commands.allowFrom`           | Whitelist for slash commands (Owner only)        |
| `channels.whatsapp.allowFrom`  | Who can use WhatsApp                             |
| `tools.profile`               | Tool policy                                      |

Always back up before making changes:

```bash
cp /home/claw/.openclaw/openclaw.json /home/claw/.openclaw/openclaw.json.bak
```

---

## Sending Messages

Two methods, each for a different purpose.

### Method 1: Direct message (no AI reaction)

Use when you want to deliver a specific message to someone's phone without their agent reacting.

```bash
openclaw message send --channel whatsapp --target <phone-number> --message "your message here"
```

| Property    | Value                                          |
|-------------|------------------------------------------------|
| Delivers to | Recipient's phone directly                     |
| AI reaction | No — only your text is delivered                |
| Session     | Not stored in session logs                      |
| When to use | Warnings, direct messages, announcements        |

This is the default method. Always works, fastest option.

### Method 2: Trigger another AI via sub-agent

Use when you want another agent to process or react to your input.

Spawn a sub-agent with this task:

```
Send a message to agent:whatsapp:whatsapp:direct:<phone-number> with content: "[your message here]". Use sessions_send with the sessionKey parameter.
```

| Property    | Value                                                        |
|-------------|--------------------------------------------------------------|
| Delivers to | The other agent's session context                            |
| AI reaction | Yes — the receiving agent processes it and can respond        |
| When to use | Delegate tasks, cross-agent communication, prompting another AI |

To find a user's sessionKey, use the session lookup commands above with their phone number from `credentials.md`.

---

## OpenRouter API Key

Stored in:

```bash
cat /home/claw/.openclaw/agents/main/agent/auth-profiles.json
```

To top up: <https://openrouter.ai/settings/credits>

---

## Screen Capture & Mouse Control

Installed: `imagemagick`, `xdotool`, `scrot`

Screenshot:
```bash
DISPLAY=:10.0 import -window root /tmp/screen.png
```

Mouse move and click:
```bash
xdotool mousemove <x> <y> click 1
```

---

## Voice / TTS

See `TOOLS.MD` for full TTS documentation.
