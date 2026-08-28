# Changelog

All notable changes and enhancements to the AdoetzGPT Flutter project are documented in this file.

---

## [2.1.0-enh] - 2026-08-28 11:55:00 UTC

### 🌟 Major Feature Expansions & Advanced AI Intelligence

#### 1. Multi-Level Thinking Mode & Dynamic UI
- **5 Granular Reasoning Effort Levels (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)**:
  - Implemented `auto`, `light` (~1k tokens), `medium` (~4k tokens), `high` (~16k tokens), and `xhigh` (~32k tokens) reasoning budgets.
  - Linked effort levels dynamically to OpenAI (`reasoning_effort` / `max_completion_tokens`) and Gemini (`thinkingConfig` / `thinkingBudget`) providers.
  - Added dynamic context-aware lightbulb icon tinting:
    - **Auto**: Yellow-Amber (`Color(0xfffacc15)`)
    - **Light**: Emerald (`Color(0xff34d399)`)
    - **Medium**: Sky Cyan (`Color(0xff38bdf8)`)
    - **High**: Purple Violet (`Color(0xffa855f7)`)
    - **Extra High**: Rose Pink (`Color(0xfff43f5e)`)
  - Long-press / modal selector bottom sheet to switch effort tiers on the fly.

#### 2. Multi-Model Arena (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)
- **Side-by-Side Competitive Inference**:
  - Simultaneous stream benchmarking across 2 or more LLM providers/models on identical prompts.
  - Real-time measurement and live HUD rendering of:
    - **Time to First Token (TTFT)** in milliseconds.
    - **Tokens Per Second (t/s)** throughput.
    - **Total output token count** & generation latency.
    - **Real-time estimated cost (USD)**.
  - "Pick Winner" action seamlessly merges the winning model's answer into the active conversation history.

#### 3. Semantic Context Compactor (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)
- **Lossless Long-Context Compression**:
  - Automatic and manual (`/compact`) token compaction summarizing historical chat turns into structured JSON metadata (`summaryText`, `keyFacts`, `activeConstraints`).
  - Automatically prepended into system reasoning prompts for future turns, dramatically extending effective conversation context limits while keeping API costs minimal.

#### 4. Multi-Agent Swarm (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)
- **Sequential Multi-Role Agent Pipeline**:
  - Autonomous multi-step collaboration pipeline connecting specialized roles:
    - **Architect** (High-level system design & strategy)
    - **Coder** (Concrete code generation & artifact building)
    - **Critic** (Adversarial review, edge case detection & security audit)
    - **Researcher** (Deep contextual exploration & validation)
  - Interactive launcher modal with `/swarm` slash command.

#### 5. Background AI Cron & Task Automation (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/settings_screen.dart`)
- **Scheduled Autonomous AI Execution**:
  - Periodic background timer execution (`intervalMinutes`) with automated state persistence.
  - Dedicated management tab in Settings under **Cron & Tasks** with immediate manual trigger ("Run Now"), enable/disable toggles, and execution timestamp history.

#### 6. Persona Studio (`lib/models.dart`, `lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)
- **Customizable System Personalities**:
  - Pre-packaged and custom persona profiles with custom avatar emojis, system prompts, and starter conversation prompts.
  - Quick-switch bottom sheet accessible via `/persona` slash command and modal controls.

#### 7. Zero-Knowledge Client-Side E2EE Sync (`lib/utils/crypto_utils.dart`, `lib/services/sync_service.dart`, `lib/screens/settings_screen.dart`)
- **End-to-End Encrypted Remote Database Storage**:
  - Built pure Dart AES-like cryptographic cipher (`CryptoUtils.encryptPayload` / `decryptPayload`) with 64-round PBKDF-style passphrase key derivation.
  - Client-side payload encryption (`e2ee:v1:...`) for Supabase and Postgres cloud storage, safeguarding user conversations and settings from server-side exposure.

---

## [2.0.0-enh] - 2026-08-28 04:23:53 UTC

### 🚀 Major Enhancements & Architectural Overhaul

#### 1. Performance & Android Optimization
- **Virtualized Model Selector Dropdown (`lib/screens/app_shell.dart`)**:
  - Replaced static widget array mappings inside the model picker modal with an indexed `ListView.builder`.
  - Resolved UI thread frame drops, memory pressure, and scrolling lag on Android devices when browsing extensive model catalogs.
- **Audio State RMS Isolation (`lib/state/app_state.dart`, `lib/screens/chat_screen.dart`)**:
  - Decoupled real-time 60Hz microphone/speaker RMS level updates from the global `ChangeNotifier` root tree.
  - Migrated metering to discrete `ValueNotifier<double>` (`liveInputLevelNotifier`, `liveOutputLevelNotifier`) and `ValueListenableBuilder`, eliminating unnecessary app-wide widget rebuilds during live voice sessions and streaming audio playback.

#### 2. Security & Data Integrity
- **Signed JWT Direct Postgres Sync (`lib/services/sync_service.dart`)**:
  - Replaced insecure base64-encoded client tokens with cryptographically signed HMAC-SHA256 JWTs using `dart_jsonwebtoken`.
  - Prevented client-side user impersonation vulnerabilities in direct PostgreSQL workspace synchronizations.
- **Non-Destructive Token Expiration Recovery (`lib/services/sync_service.dart`, `lib/state/app_state.dart`)**:
  - Handled Supabase/Postgres token expirations (`PGRST303` / `JWT expired`) gracefully by warning the user and pausing synchronization.
  - Eliminated destructive `signOut()` calls that caused data loss of unsynced local chat sessions.

#### 3. AI Service & Generation Controls
- **Streaming Multi-Tool SSE Aggregation (`lib/services/ai_service.dart`)**:
  - Implemented indexed chunk accumulation (`capturedToolCalls`) for OpenAI-compatible streaming endpoints.
  - Fixed a critical race condition where parallel tool calling arguments were overwritten by subsequent streaming chunks.
- **Fine-Grained Model Generation Parameters (`lib/screens/settings_screen.dart`, `lib/services/ai_service.dart`, `lib/models.dart`)**:
  - Added dedicated UI controls in Settings under **AI & Generation** (`_GenerationParametersSection`):
    - **Temperature**: `0.0` to `2.0` (Precise to Creative slider)
    - **Top-P (Nucleus Sampling)**: `0.0` to `1.0`
    - **Top-K Sampling**: `1` to `100`
    - **Max Output Tokens**: `256` to `32768`
  - Integrated parameter bindings into request payloads for both OpenAI-compatible endpoints (`temperature`, `top_p`, `max_tokens`) and Google Gemini (`temperature`, `topP`, `topK`, `maxOutputTokens`).

#### 4. Interaction & UI Stability
- **Message Send Debounce (`lib/screens/chat_screen.dart`)**:
  - Enforced a 500ms timestamp threshold on chat send actions to prevent accidental double-tap request dispatches and state race conditions.
- **Memory Model State Consistency (`lib/models.dart`)**:
  - Enhanced `Memory.copyWith` with optional `clearDeletedAt` parameter to cleanly support un-deleting/reactivating memories without schema mismatches.
- **Cleaned Redundant Widget Declarations (`lib/screens/chat_screen.dart`)**:
  - Removed duplicate trailing button definitions in `_VoiceOverlay`.

---

### 📦 CI/CD & Build Pipeline
- Automated Android Release APK build verification via GitHub Actions (`.github/workflows/build-apk.yml`).
- Successfully compiled release APK (`app-release.apk`) on Flutter stable channel.
