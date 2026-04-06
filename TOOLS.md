# Tools

All available tools, commands, and reference paths.

---

## File Locations

All paths are relative to the VM user's home directory (`$HOME`).

| Resource            | Path                                                  |
|---------------------|-------------------------------------------------------|
| Config              | `~/.openclaw/openclaw.json`                           |
| Auth profiles       | `~/.openclaw/agents/main/agent/auth-profiles.json`    |
| WhatsApp sessions   | `~/.openclaw/agents/whatsapp/sessions/`               |
| Media (voice/photo) | `~/.openclaw/media/inbound/`                          |
| Workspace           | `~/.openclaw/workspace-whatsapp/`                     |
| Memory              | `~/.openclaw/workspace-whatsapp/MEMORY.md`            |
| Heartbeat           | `~/.openclaw/workspace-whatsapp/HEARTBEAT.md`         |

---

## WhatsApp — Sessions & Messaging

### List all sessions

```bash
cat $HOME/.openclaw/agents/whatsapp/sessions/sessions.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k, v in d.items():
    print(f'{k}: session={v[\"sessionId\"]}')"
```

### Read a session transcript

```bash
cat $HOME/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl
```

### Look up a user by phone number

Use a phone number from `.env`:

```bash
PHONE="<phone-from-credentials>"
cat $HOME/.openclaw/agents/whatsapp/sessions/sessions.json | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
for k, v in d.items():
    if '$PHONE' in k:
        sid = v['sessionId']
        ts = datetime.datetime.fromtimestamp(v['updatedAt']/1000).strftime('%H:%M:%S')
        print(f'Session: {sid}, Last active: {ts}')
"
```

### Summarize recent messages

```bash
python3 << 'EOF'
import json, os

sessions_dir = os.path.expanduser("~/.openclaw/agents/whatsapp/sessions")
session_file = os.path.join(sessions_dir, "<session-id>.jsonl")

with open(session_file, 'r') as f:
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
ls -la $HOME/.openclaw/agents/whatsapp/sessions/*.jsonl

mv $HOME/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl \
   $HOME/.openclaw/agents/whatsapp/sessions/<session-id>.jsonl.bak
```

### Send a direct message (no AI reaction)

Delivers text straight to someone's phone. No agent processes it.

```bash
openclaw message send --channel whatsapp --target <phone-number> --message "your message here"
```

### Trigger another AI via sub-agent

Use when you want the receiving agent to process and respond to your input.

```
Send a message to agent:whatsapp:whatsapp:direct:<phone-number> with content: "[your message here]". Use sessions_send with the sessionKey parameter.
```

To find a sessionKey, use the phone number lookup above.

---

## OpenClaw Configuration

Config file: `~/.openclaw/openclaw.json`

| Setting                        | Purpose                                         |
|--------------------------------|-------------------------------------------------|
| `commands.allowFrom`           | Whitelist for slash commands                     |
| `channels.whatsapp.allowFrom`  | Who can use WhatsApp                             |
| `tools.profile`               | Tool policy                                      |

Back up before editing:

```bash
cp $HOME/.openclaw/openclaw.json $HOME/.openclaw/openclaw.json.bak
```

OpenRouter API key is stored in:

```bash
cat $HOME/.openclaw/agents/main/agent/auth-profiles.json
```

Top up credits: <https://openrouter.ai/settings/credits>

---

## Whisper — Voice Transcription

Transcribes WhatsApp voice messages (`.ogg`) to text.

### Quick one-liner

```bash
LATEST_OGG=$(ls -t $HOME/.openclaw/media/inbound/*.ogg | head -1)
ffmpeg -y -i "$LATEST_OGG" /tmp/t.wav 2>/dev/null \
  && whisper /tmp/t.wav --language nl --model small 2>/dev/null | tail -5
```

### Step by step

1. Find the latest voice note:
   ```bash
   ls -lt $HOME/.openclaw/media/inbound/*.ogg | head -3
   ```

2. Convert to WAV:
   ```bash
   ffmpeg -y -i "/path/to/file.ogg" /tmp/transcribe.wav 2>&1 | tail -2
   ```

3. Transcribe:
   ```bash
   whisper /tmp/transcribe.wav --language nl --model small 2>&1 | tail -5
   ```

4. Clean up:
   ```bash
   rm -f /tmp/transcribe.wav /tmp/t.wav transcribe.* t.*
   ```

### Models

| Model    | Size    | Speed   | Quality              |
|----------|---------|---------|----------------------|
| `tiny`   | ~72 MB  | Fastest | Basic                |
| `base`   | ~142 MB | Fast    | Decent               |
| `small`  | ~461 MB | Normal  | Good (recommended)   |
| `medium` | ~1.5 GB | Slow    | Very good            |

---

## TTS — Voice Generation

Generates Dutch voice messages using sherpa-onnx TTS.
Default voice: Miro. Location: `~/.openclaw/tools/sherpa-onnx-tts/`

### Usage

1. Generate WAV:
   ```bash
   STATE_DIR="$HOME/.openclaw"
   TTS_BIN="$STATE_DIR/tools/sherpa-onnx-tts/runtime/bin/sherpa-onnx-offline-tts"
   MODELS_DIR="$STATE_DIR/tools/sherpa-onnx-tts/models"

   $TTS_BIN \
     --vits-model="$MODELS_DIR/vits-piper-nl_NL-miro-high/nl_NL-miro-high.onnx" \
     --vits-tokens="$MODELS_DIR/vits-piper-nl_NL-miro-high/tokens.txt" \
     --vits-data-dir="$MODELS_DIR/vits-piper-nl_NL-miro-high/espeak-ng-data" \
     --output-filename=/tmp/tts.wav \
     "Tekst hier"
   ```

2. Convert to OGG/Opus for WhatsApp:
   ```bash
   ffmpeg -y -i /tmp/tts.wav -c:a libopus -b:a 16k /tmp/tts.oga
   ```

3. Send:
   ```bash
   openclaw message send --channel whatsapp --target <number> --media /tmp/tts.oga
   ```

4. Clean up:
   ```bash
   rm -f /tmp/tts.wav /tmp/tts.oga
   ```

### Rules

- Write "Mr." out as "Mister" — otherwise the voice reads "M-R"
- Only send voice messages when explicitly requested
- Default is text; use voice only when asked

### Available voices

| Voice   | Model                | Quality            |
|---------|----------------------|--------------------|
| Miro    | nl_NL-miro-high      | High (default)     |
| Ronnie  | nl_NL-ronnie-medium  | Medium             |
| Pim     | nl_NL-pim-medium     | Medium             |
| Dii     | nl_NL-dii-high       | High               |

---

## Playwright — Browser Automation & Web QA

Reliable browser automation using CSS/aria selectors. Use for all web app testing.
Location: `~/.openclaw/tools/playwright-skill/`

### Setup (one-time)

```bash
cd ~/.openclaw/tools/playwright-skill && npm run setup
```

### Auto-detect dev servers

```bash
cd ~/.openclaw/tools/playwright-skill && node -e "require('./lib/helpers').detectDevServers().then(s => console.log(JSON.stringify(s, null, 2)))"
```

### Write and run a test

Always write scripts to `/tmp/`, never to the skill directory.

```javascript
// /tmp/playwright-test.js
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  await page.goto(TARGET_URL);
  console.log('Page title:', await page.title());
  await page.screenshot({ path: '/tmp/screenshot-full.png', fullPage: true });
  await browser.close();
})();
```

```bash
cd ~/.openclaw/tools/playwright-skill && node run.js /tmp/playwright-test.js
```

### Common patterns

```javascript
// Click by text
await page.click('text=Submit');

// Fill a form field
await page.fill('input[name="email"]', 'test@example.com');

// Check visibility
await expect(page.locator('h1')).toBeVisible();
await expect(page.locator('h1')).toHaveText('Welcome');

// Responsive screenshots
for (const [name, w, h] of [['mobile',375,812],['tablet',768,1024],['desktop',1920,1080]]) {
  await page.setViewportSize({ width: w, height: h });
  await page.screenshot({ path: `/tmp/screenshot-${name}.png` });
}

// Catch console errors
const errors = [];
page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
await page.goto(TARGET_URL);
if (errors.length) console.log('Console errors:', errors);

// Check all links
const links = await page.locator('a[href]').all();
for (const link of links) {
  const href = await link.getAttribute('href');
  const text = await link.textContent();
  console.log(`Link: "${text.trim()}" → ${href}`);
}
```

---

## Computer Use — Desktop GUI Control

X11-level desktop control via screenshots and mouse/keyboard. Use for non-browser apps or OS-level interaction.

Requires: `DISPLAY=:99` (or whatever display the virtual desktop runs on)

### Screenshots

```bash
DISPLAY=:99 scrot /tmp/screen.png
# or
DISPLAY=:99 import -window root /tmp/screen.png
```

### Mouse

```bash
DISPLAY=:99 xdotool mousemove 500 300 click 1       # left click
DISPLAY=:99 xdotool mousemove 500 300 click 3       # right click
DISPLAY=:99 xdotool mousemove 500 300 click --repeat 2 1  # double click
```

### Keyboard

```bash
DISPLAY=:99 xdotool type --delay 50 "Hello world"   # type text
DISPLAY=:99 xdotool key Return                       # enter
DISPLAY=:99 xdotool key Tab                          # tab
DISPLAY=:99 xdotool key Escape                       # escape
DISPLAY=:99 xdotool key ctrl+s                       # save
DISPLAY=:99 xdotool key ctrl+a                       # select all
```

### Scroll

```bash
DISPLAY=:99 xdotool click 5   # scroll down
DISPLAY=:99 xdotool click 4   # scroll up
```

### Drag and drop

```bash
DISPLAY=:99 xdotool mousemove 100 200 mousedown 1 mousemove 400 500 mouseup 1
```

### Workflow: screenshot → analyze → act → verify

Always follow this pattern. Never click blindly — screenshot first to know where things are, act, then screenshot again to confirm.

---

## When to use what

| Scenario | Tool |
|----------|------|
| Testing a web app in a browser | Playwright |
| Desktop-only app (no browser) | Computer Use |
| Forms, buttons, links on a website | Playwright |
| OS dialogs, file pickers | Computer Use |
| Responsive layout testing | Playwright |
| Anything needing a real display | Computer Use |
