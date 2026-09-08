# AdoetzGPT Project Context & Architectural Specification

> **Current Document Version:** 2.3.0  
> **Last Updated:** September 2026  
> **Project Codebase:** `AdoetzGPT-flutter-enh`  
> **Repository Owner / Author:** Abdurahman Ali (`alids522`)

---

## 1. Executive Summary

**AdoetzGPT** is a production-grade, privacy-first, cross-platform AI assistant and multi-agent orchestrator. Built with a high-performance **Flutter** frontend and a lightweight **Node.js / Express / TypeScript** backend, it supports multimodal conversational intelligence, real-time live voice/video streaming, autonomous tool calling, side-by-side LLM benchmarking, and end-to-end encrypted cloud synchronization.

Originally created as a web and React-based interface, the application has undergone a complete architectural evolution into a native-first Flutter solution supporting **Web, Android, iOS, and Windows Desktop**, backed by local file storage, direct PostgreSQL connections, Supabase cloud sync, and an Express proxy gateway.

---

## 2. Technology Stack & Key Dependencies

### 2.1 Frontend (Flutter / Dart)
- **Framework & SDK:** Flutter `3.44.1` (channel stable) • Dart SDK `^3.12.1`
- **State Management:** `provider: ^6.1.5+1` with decoupled `ValueNotifier` streams for performance-critical 60fps audio meters.
- **Networking & Real-Time Streaming:**
  - `http: ^1.6.0`: REST API calls and SSE streaming chunk parsers.
  - `web_socket_channel: ^3.0.3`: Low-latency WebSocket connections for Gemini Live.
  - `mcp_dart: 2.2.1`: Official Model Context Protocol (MCP) Dart client with `StreamableHttpClientTransport`.
- **Media, Audio & Multimodal:**
  - `record: 7.1.0`: Native microphone capture with raw PCM streaming at 24kHz.
  - `audioplayers: 6.7.1`: Sound effects, notification chimes, and TTS output.
  - `camera: 0.12.0+1`: Real-time camera feed capture and live frame extraction for Gemini Live Vision.
  - `speech_to_text: ^6.6.1`: On-device client dictation.
- **UI, Markdown & Typography:**
  - `google_fonts: 8.1.0`: Dynamic font typography across design themes.
  - `lucide_icons_flutter: 3.1.14+2`: Modern, consistent icon library.
  - `flutter_markdown: 0.7.7+1` & `flutter_markdown_latex: ^0.5.0`: Full Markdown rendering with syntax-highlighted code blocks, tables, and mathematical LaTeX formulas.
  - `syncfusion_flutter_pdf: 33.2.13+1`: PDF document text extraction and document querying.
  - `archive: 4.0.9`: ZIP and compressed archive extraction.
- **Security & Cloud Storage:**
  - `supabase_flutter: 2.15.0`: Supabase authentication and realtime database synchronization.
  - `postgres: 3.1.2`: Direct client-side PostgreSQL connectivity for desktop/mobile.
  - `bcrypt: ^1.1.3`: Client-side password hashing.
  - `dart_jsonwebtoken: ^2.14.0`: Client-side JWT verification and token handling.
  - `shared_preferences: ^2.5.5`: Persistent local configuration and guest cache.

### 2.2 Backend (Node.js / Express / TypeScript)
- **Runtime & Loader:** Node.js (ES Modules `type: "module"`) running with `tsx` (`^4.21.0`).
- **Server Framework:** `express: ^4.21.2` with custom CORS, JSON limits (50MB), and static hosting.
- **Database & Security:**
  - `pg: ^8.20.0`: PostgreSQL pooling and transaction management.
  - `bcryptjs: ^3.0.3`: Secure credential hashing.
  - `jsonwebtoken: ^9.0.3`: API authentication token signing and verification.
  - `dotenv: ^17.2.3`: Configuration and environment injection.
- **Build & Dev Tooling:** `cross-env: ^10.1.0`, `typescript: ~5.8.2`.

---

## 3. Directory Structure & Code Organization

```text
AdoetzGPT-flutter-enh/
├── data/                             # Local runtime storage
│   └── app-state.json                # Default local JSON database (when Postgres is unconfigured)
├── lib/                              # Flutter Application Core
│   ├── main.dart                     # App entry point, bootstrap, and multi-provider injection
│   ├── models.dart                   # Central domain models, schemas, enums, and JSON mappers
│   ├── translations.dart             # Internationalization (English & Indonesian)
│   ├── screens/                      # Main Screen Views
│   │   ├── app_shell.dart            # Responsive shell layout, sidebar, header, navigation
│   │   ├── auth_screen.dart          # Sign In, Sign Up, Guest mode, and DB configuration dialog
│   │   ├── chat_screen.dart          # Chat interface, streaming markdown, thinking box, tool cards
│   │   ├── settings_screen.dart      # Master-detail settings panel (12 configuration tabs)
│   │   └── token_usage_screen.dart   # Token usage metrics, cost analytics, and model benchmarks
│   ├── services/                     # Business Logic, Networking & Infrastructure
│   │   ├── ai_service.dart           # Unified LLM client (Gemini, OpenAI, Ollama, Groq, Mistral)
│   │   ├── gemini_live_service.dart  # Gemini Live bidirectional WebSocket audio/video stream
│   │   ├── live_audio_player.dart    # Conditional audio playback export (Web / Mobile)
│   │   ├── live_audio_player_mobile.dart # Native low-latency AudioTrack PCM playback
│   │   ├── live_audio_player_web.dart    # Web Audio API / AudioContext playback
│   │   ├── live_foreground_service.dart  # Background service runner for continuous live audio
│   │   ├── live_socket.dart          # Conditional WebSocket channel export
│   │   ├── mcp_service.dart          # Model Context Protocol (MCP) client manager
│   │   ├── memory_agent.dart         # Autonomous memory extraction & sensitivity auditing
│   │   ├── memory_retriever.dart     # Contextual memory retrieval and prompt injection
│   │   ├── storage_service.dart      # Abstract local storage layer
│   │   └── sync_service.dart         # Cloud sync coordinator (Postgres / Supabase / Express API)
│   ├── state/
│   │   └── app_state.dart            # Global Application State (~4,300 lines ChangeNotifier)
│   ├── ui/
│   │   └── app_theme.dart            # 13 dynamic visual themes & responsive styling palette
│   ├── utils/
│   │   ├── artifact_parser.dart      # Extracts code/HTML/SVG artifacts from assistant markdown
│   │   ├── crypto_utils.dart         # Zero-Knowledge E2EE cipher (PBKDF key derivation + stream cipher)
│   │   └── download_helper.dart      # Cross-platform file saving and web download triggers
│   └── widgets/
│       ├── artifact_preview.dart     # Tabbed code viewer, copy actions, and sandboxed previews
│       ├── live_camera_feed.dart     # Multimodal camera controller for live video input
│       └── streaming_text_renderer.dart # Fast, smooth streaming markdown text renderer
├── server/
│   └── index.ts                      # Express API server, transparent proxy, DB sync & auth
├── scripts/                          # Platform launcher scripts
│   ├── run_android.ps1               # Automated Android deployment script
│   ├── run_chrome_debug.ps1          # Chrome debugging runner with port collision detection
│   └── run_web.ps1                   # Web server runner
├── web/                              # Flutter web static assets and HTML templates
├── package.json                      # Node.js dependencies and lifecycle scripts
└── pubspec.yaml                      # Flutter dependencies and asset registrations
```

---

## 4. Core Features & System Capabilities

### 4.1 Multi-Provider AI Inference (`lib/services/ai_service.dart`)
Supports unified communication across leading AI APIs:
1. **Google Gemini:** Native Gemini REST API (`gemini-2.5-flash`, `gemini-1.5-pro`, etc.) and real-time live WebSocket.
2. **OpenAI & OpenAI-Compatible Endpoints:** Native OpenAI, Ollama, OpenRouter, Groq, Mistral, LM Studio, or self-hosted LLMs.
3. **Agent Server Connectors:** Direct integration with agent servers like **OpenClaw Gateway** and **Hermes Agent** with capability synchronization.

### 4.2 Multi-Level Thinking Mode & Dynamic UI
Offers 5 granular reasoning effort tiers with dynamic lightbulb icon tinting:
- **Auto:** Model determines reasoning length (`Color(0xfffacc15)` Yellow-Amber)
- **Light:** ~1,024 token reasoning budget (`Color(0xff34d399)` Emerald)
- **Medium:** ~4,096 token reasoning budget (`Color(0xff38bdf8)` Sky Cyan)
- **High:** ~16,384 token reasoning budget (`Color(0xffa855f7)` Purple Violet)
- **Extra High (xHigh):** ~32,768 token reasoning budget (`Color(0xfff43f5e)` Rose Pink)

Parameters are dynamically mapped to OpenAI's `reasoning_effort` and Gemini's `thinkingConfig / thinkingBudget`.

### 4.3 Multi-Model Arena (`ArenaSessionState`)
Allows side-by-side competitive benchmarking of multiple models on identical user prompts:
- Streamed in parallel with real-time HUD rendering.
- Measures **Time to First Token (TTFT)** in ms, **Tokens Per Second (t/s)** throughput, generation latency, and estimated cost in USD.
- "Pick Winner" action seamlessly promotes the selected model's output into the active chat session.

### 4.4 Multi-Agent Swarm Pipeline (`SwarmAgent`)
An autonomous 4-stage collaboration pipeline connecting specialized roles:
1. **Architect:** System design and structural strategy.
2. **Coder:** Concrete code generation and implementation.
3. **Critic:** Adversarial code review, edge case detection, and security audit.
4. **Researcher:** Deep contextual fact-checking and validation.

Can be triggered interactively or via the `/swarm` slash command.

### 4.5 Semantic Context Compactor (`ConversationSummaryCompaction`)
Lossless long-context compression system:
- Runs automatically when conversation turns exceed token thresholds or manually via `/compact`.
- Condenses historical context into structured JSON metadata (`summaryText`, `keyFacts`, `activeConstraints`).
- Prepends compacted context into subsequent prompts, drastically extending effective context limits while conserving tokens.

### 4.6 Gemini Live: Multimodal Real-Time Voice & Video (`lib/services/gemini_live_service.dart`)
Bidirectional real-time multimodal interaction using Google's `BidiGenerateContent` WebSocket protocol:
- **24kHz PCM Audio Streaming:** Ultra-low latency voice input and output.
- **All 30 Gemini Live Voice Personas:** Puck, Charon, Kore, Fenrir, Aoede, Leda, Orus, Zephyr, Lyra, Vega, etc.
- **Three Speech Modes:**
  - `voice`: Conversational voice assistant.
  - `transcribe`: Real-time speech-to-text transcription.
  - `translate`: Real-time speech translation with source and target language selection.
- **Multimodal Video Input:** Real-time camera frames encoded as JPEG chunks and streamed over WebSocket.
- **Background Persistence:** Background service integration (`LiveForegroundService`) for uninterrupted audio on mobile.

### 4.7 Autonomous Antigravity Web Search Engine
- Autonomous tool-calling loop detecting `web_search` triggers.
- Supports Antigravity, DuckDuckGo, Brave, Tavily, and SearxNG providers.
- Streams live intermediate search status inside collapsible `<think>...</think>` blocks before injecting tool results back into the model context.

### 4.8 Model Context Protocol (MCP) Integration (`lib/services/mcp_service.dart`)
- Full compliance with Anthropic's Model Context Protocol.
- Connects to external MCP servers over HTTP/SSE with custom headers and authorization.
- Discovers tools dynamically and makes them available for LLM autonomous execution.

### 4.9 Long-Term Memory System (`lib/services/memory_agent.dart`)
- Automatically analyzes user prompts to extract persistent personal facts, preferences, and project context.
- Sanitizes and rejects passwords, tokens, API keys, and sensitive financial data.
- Normalizes canonical keys via `MemoryCanonicalKeys` to prevent duplicates.
- Injects relevant memories into future prompts using `MemoryRetriever`.

### 4.10 Comprehensive Theming Engine (`lib/ui/app_theme.dart`)
Includes 13 visual themes, each supporting both Dark and Light variations:
1. **Default (Classic):** Original modern balanced theme.
2. **Liquid Glass:** Frosted translucent panels with soft depth.
3. **Aurora Neon:** Deep space contrast with electric glow.
4. **Modern Minimal:** Clean, distraction-free monochrome aesthetic.
5. **iOS 26 Vision:** High-blur translucent visionOS-inspired depth.
6. **Midnight Bloom:** Deep indigo garden with emerald, gold, and rose accents.
7. **Cyberpunk OLED:** Pure black `#000000` with electric magenta and cyber amber.
8. **Synthwave 80s:** Retro outrun laser hot pink, cosmic violet, and neon cyan.
9. **Matrix Phosphor:** Classic green terminal CRT phosphor glow.
10. **Solar Flare:** Molten ember with magma orange, gold, and plasma red.
11. **Nordic Frost:** Arctic glacial blue and frosted silver clarity.
12. **Obsidian Slate:** Architectural deep charcoal granite and platinum balance.
13. **Tokyo Executive:** Corporate midnight sapphire, ink grey, and champagne gold.

---

## 5. Backend Architecture & Cloud Data Layer

### 5.1 Express Server (`server/index.ts`)
The Node.js backend serves dual purposes:
1. **Development & Web Hosting:** Serves the compiled Flutter web application from `build/web` and provides fallback routing for single-page application navigation.
2. **API & Proxy Services:**
   - **CORS Bypassing Proxy (`/api/proxy`):** Forwards requests to remote LLMs or search APIs with HTTP streaming pipe support.
   - **Health Endpoint (`/api/health`):** Reports server status, local database path, and Postgres connectivity.
   - **Database Synchronization (`/api/sync/push`, `/api/sync/backup`):** Provides batch persistence and cross-database backup.
   - **Authentication (`/api/auth/signup`, `/api/auth/signin`):** Issues signed JWT tokens for PostgreSQL users.

### 5.2 PostgreSQL Database Schema
When PostgreSQL is enabled (via `DATABASE_URL` or user settings), the backend or direct client manages the following schema:

```sql
CREATE SCHEMA IF NOT EXISTS adoetzgpt;

CREATE TABLE IF NOT EXISTS adoetzgpt.users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  email TEXT UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS adoetzgpt.user_settings (
  user_id TEXT PRIMARY KEY REFERENCES adoetzgpt.users(id) ON DELETE CASCADE,
  state JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS adoetzgpt.chat_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES adoetzgpt.users(id) ON DELETE CASCADE,
  session JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 5.3 Zero-Knowledge Client-Side E2EE (`lib/utils/crypto_utils.dart`)
- Users can specify a client-side passphrase for cloud sync.
- Payload is encrypted before leaving the device using a 64-round PBKDF key derivation combined with a secure stream cipher and 12-byte cryptographic nonce.
- Encrypted payloads are stored as `e2ee:v1:<base64>` in the remote database, guaranteeing that neither the host nor the database operator can read chat sessions or settings.

---

## 6. Slash Command System

The chat interface includes a rich set of slash commands accessible by typing `/`:

| Command | Category | Description |
|---|---|---|
| `/new` | Core Chat | Start a fresh chat session |
| `/clear` | Core Chat | Clear current conversation messages |
| `/delete` | Core Chat | Delete current chat session |
| `/rename` | Core Chat | Rename the active session |
| `/sessions` | Core Chat | Open session history drawer |
| `/search` | Core Chat | Search historical chat messages |
| `/model` | Model | Open model selector sheet |
| `/thinking` | Thinking | Toggle Thinking Mode on/off |
| `/arena` | Arena & Swarm | Open Multi-Model Arena comparison |
| `/swarm` | Arena & Swarm | Launch Multi-Agent Swarm workflow |
| `/compact` | Memory & Context | Trigger Semantic Context Compaction |
| `/persona` | Thinking | Open Persona Studio personality selector |
| `/settings` | Settings | Navigate to Settings screen |
| `/theme` | Settings | Toggle theme or switch theme presets |
| `/language` | Settings | Switch between English and Indonesian |
| `/stop` | Generation | Abort current generation |
| `/regenerate` | Generation | Regenerate latest AI response |
| `/export` | Admin | Export active session to JSON |
| `/import` | Admin | Import chat session data |

---

## 7. Build, Run, and Deployment Workflows

### 7.1 Local Development
1. **Start Backend Server:**
   ```bash
   npm run dev
   ```
   *Runs `tsx server/index.ts` on port 3000.*

2. **Build Flutter Web App:**
   ```bash
   npm run build:web
   # or directly: flutter build web
   ```
   *Generates production assets under `build/web/` which are served by the backend at `http://localhost:3000/`.*

3. **Run Flutter with Hot Reload / Debugging:**
   ```powershell
   # Debug in Chrome
   ./scripts/run_chrome_debug.ps1

   # Run as Web Server
   ./scripts/run_web.ps1

   # Run on Android Device / Emulator
   ./scripts/run_android.ps1
   ```

### 7.2 Production Compilation
- **Web:** `flutter build web --release`
- **Android APK:** `flutter build apk --release`
- **Android App Bundle:** `flutter build appbundle --release`
- **Windows Desktop:** `flutter build windows --release`
- **iOS:** `flutter build ipa --no-codesign`

---

## 8. Summary of Architectural Guidelines

1. **State Performance:** Never bind 60Hz real-time streams (like audio RMS meters) to `AdoetzAppState.notifyListeners()`. Always use targeted `ValueNotifier` instances (`liveInputLevelNotifier`, `liveOutputLevelNotifier`) to prevent UI lag.
2. **Target Neutrality:** All message dispatching routes through `activeChatTarget`. Ensure both `model` and `agentServer` target types are supported when adding features.
3. **Privacy by Default:** When syncing settings or sessions to external databases, respect `SyncSettings.useClientEncryption` and utilize `CryptoUtils.encryptPayload`.
4. **Memory Hygiene:** Ensure any new automated memory extraction runs through `MemoryAgent` to sanitize API keys, credentials, and sensitive private tokens.
