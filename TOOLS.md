# Tools

Overview of available tools and usage instructions.

---

## Whisper — Voice Transcription

Transcribes WhatsApp voice messages (`.ogg`) to text using OpenAI Whisper.

### Quick one-liner

```bash
LATEST_OGG=$(ls -t /home/claw/.openclaw/media/inbound/*.ogg | head -1)
ffmpeg -y -i "$LATEST_OGG" /tmp/t.wav 2>/dev/null \
  && whisper /tmp/t.wav --language nl --model small 2>/dev/null | tail -5
```

### Step by step

**1. Find the audio file**

WhatsApp voice notes are stored in `/home/claw/.openclaw/media/inbound/`. List the most recent files:

```bash
ls -lt /home/claw/.openclaw/media/inbound/*.ogg | head -3
```

**2. Convert to WAV**

```bash
ffmpeg -y -i "/path/to/inbound/file.ogg" /tmp/transcribe.wav 2>&1 | tail -2
```

**3. Transcribe with Whisper**

```bash
whisper /tmp/transcribe.wav --language nl --model small 2>&1 | tail -5
```

**4. Clean up temp files**

Always remove temporary files after transcription is complete:

```bash
rm -f /tmp/transcribe.wav /tmp/t.wav
```

Whisper also generates output files (`.txt`, `.vtt`, `.srt`, `.tsv`, `.json`) in the current directory. Remove those too:

```bash
rm -f transcribe.* t.*
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

Generates voice messages in Dutch using sherpa-onnx TTS.

Default voice: Miro (vits-piper-nl_NL-miro-high).
Location: `~/.openclaw/tools/sherpa-onnx-tts/`

### Usage

1. Generate WAV with sherpa-onnx TTS:

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

3. Send via WhatsApp:

```bash
openclaw message send --channel whatsapp --target <number> --media /tmp/tts.oga
```

4. Clean up:

```bash
rm -f /tmp/tts.wav /tmp/tts.oga
```

### Important rules

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
