# Antigravity-bar

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Antigravity Stats Icon">
</p>

<p align="center">
  <strong>The macOS menu bar companion for Google Antigravity IDE</strong><br>
  Monitor your AI quota usage, cache size, prevent context bloat, and access quick actions — all right from your macOS menu bar.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS_13%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📊 **Quota Indicators** | Flash, Pro, Claude — color-coded percentages |
| ⏱ **Timer Circles** | Pie-fill showing time until your Google Antigravity quota resets |
| 💾 **Cache Size** | Colored by thresholds to stop context bloat (🟢 <100MB, 🟡 <300MB, 🟠 <500MB, 🔴 >500MB) |
| 🔌 **Quick Actions** | Rules, MCP servers, Allowlist, Restart Language Server, Reset Updater, Reload |
| 🧹 **Cleanup** | Clear Brain & Code Tracker with confirmation |
| 💬 **New Chat** | Launch an entirely fresh Google Antigravity chat from the menu |
| 🧪 **Playground** | Open the playground directory |
| 🚀 **Launch at Login** | Toggle auto-start transparently |
| 🔴 **Offline Detection** | Shows "OFF" when the Google Antigravity daemon is not running |

## 📸 Preview

**Menu Bar:**

<img src="assets/screenshots/menubar.png" width="500" alt="Menu Bar">

**Context Menu:**

<img src="assets/screenshots/context-menu.png" width="350" alt="Context Menu">

## 📥 Install

### From Source

```bash
git clone https://github.com/helgklaizar/antigravity-stats.git
cd antigravity-stats
chmod +x build-app.sh
./build-app.sh
cp -r "Antigravity Stats.app" /Applications/
```

### Quick Run (Development)

```bash
swift build
.build/debug/StellarBar
```

## 🔧 Requirements

- **macOS 13.0+** (Ventura)
- **Google Antigravity IDE** installed and running
- **Swift 6.0+** toolchain (for building from source)

## 🏗 Architecture

```
┌─────────────────────────────────────────────────┐
│                 Menu Bar                         │
│  77.6 MB  |  ◐ 100%  |  ◐ 100%  |  ◑ 40%      │
└──────────────────┬──────────────────────────────┘
                   │ click
┌──────────────────▼──────────────────────────────┐
│              Context Menu                        │
│  ├─ Quota details (per AI model)                │
│  ├─ New Chat / Playground                       │
│  ├─ Rules / MCP / Allowlist                     │
│  ├─ Restart Server / Reset Updater / Reload     │
│  ├─ Clear Brain / Code Tracker                  │
│  ├─ Launch at Login toggle                      │
│  └─ Quit                                        │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│          Google Antigravity API                  │
│  ├─ Daemon discovery (~/.gemini/antigravity/)   │
│  ├─ Connect/Protobuf quota fetch                │
│  └─ Cache size calculation                      │
└─────────────────────────────────────────────────┘
```

## 🔌 How It Works

1. **Daemon Discovery** — reads JSON files from `~/.gemini/antigravity/daemon/` to find the active Language Server.
2. **Quota Fetch** — sends a `GetUserStatus` request via Connect protocol to the local HTTP port.
3. **Polling** — refreshes data every 30 seconds.
4. **Cache Calculation** — sums `brain/` and `conversations/` directory sizes to monitor memory bloat.

## 📁 Project Structure

```
├── Package.swift                    # Swift Package Manager manifest
├── build-app.sh                     # .app bundle builder
├── Sources/AntigravityStats/
│   ├── main.swift                   # Entry point
│   ├── AppDelegate.swift            # Menu bar UI & actions
│   ├── AntigravityAPI.swift         # Daemon API & utilities
│   └── Resources/
│       ├── Info.plist               # App metadata
│       └── AppIcon.icns             # App icon
```

## 🛣 Roadmap

| # | Task | Details |
|---|------|--------|
| 1 | **Adaptive polling** | Faster refresh when menu is open, slower in background (currently fixed 30s) |
| 2 | **New model support** | Add quota rows & icons when Google Antigravity adds new models |
| 3 | **Modern macOS APIs** | Audit and migrate deprecated AppKit APIs for macOS 14/15 |
| 4 | **Daemon discovery stability** | Add timeout + retry logic when reading JSON from `~/.gemini/antigravity/daemon/` |
| 5 | **Rename binary** | Rename `StellarBar` → `AntigravityBar` in `Package.swift` and `build-app.sh` |

## 📄 License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  Made with ⚡ for the Google Antigravity community
</p>


---

---

## 🍏 The Mac AI Ecosystem
This initiative is a suite of high-performance tools natively optimized for Apple Silicon (MLX).

- [🌌 **Aether-MLX**](https://github.com/helgklaizar/aether-mlx) — Geometric Sparse Attention.
- [🧬 **Attention-Matching-MLX**](https://github.com/helgklaizar/attention-matching-mlx) — 50x context compression.
- [🔳 **BitNet-MLX**](https://github.com/helgklaizar/bitnet-mlx) — Native Ternary (1.58-bit) Kernels.
- [🌉 **Cuda-Bridge-MLX**](https://github.com/helgklaizar/cuda-bridge-mlx) — Run CUDA projects natively.
- [🌌 **DeepSeek-MLX**](https://github.com/helgklaizar/deepseek-mlx) — High-throughput inference engine.
- [🍏 **Env-Selector-MLX**](https://github.com/helgklaizar/env-selector-mlx) — UI configurator.
- [🧬 **Evol-KV-MLX**](https://github.com/helgklaizar/evol-kv-mlx) — Adaptive KV cache evolution.
- [⚡️ **Flash-Attention-MLX**](https://github.com/helgklaizar/flash-attention-mlx) — Native FA3 for Metal.
- [🔥 **Flamegraph-MLX**](https://github.com/helgklaizar/flamegraph-mlx) — Visual energy & performance profiler.
- [🎞 **Flux-Studio-MLX**](https://github.com/helgklaizar/flux-studio-mlx) — Professional UI for image generation.
- [⚒️ **Forge-MLX**](https://github.com/helgklaizar/forge-mlx) — Fast and memory-efficient Fine-Tuning.
- [🧊 **Gaussian-Splatting-MLX**](https://github.com/helgklaizar/gaussian-splatting-mlx) — High-speed 3D rendering.
- [💧 **H2O-MLX**](https://github.com/helgklaizar/h2o-mlx) — Heuristic-based KV cache eviction.
- [📡 **KVTC-MLX**](https://github.com/helgklaizar/kvtc-mlx) — Transform coding for KV cache.
- [🐅 **Liger-Kernel-MLX**](https://github.com/helgklaizar/liger-kernel-mlx) — Fused training kernels for Metal.
- [🎲 **MCTS-RL-MLX**](https://github.com/helgklaizar/mcts-rl-mlx) — Highly parallel MCTS framework.
- [🗣 **Moshi-Voice-MLX**](https://github.com/helgklaizar/moshi-voice-mlx) — Realtime Voice-to-Voice agents.
- [👁️ **OmniParser-MLX**](https://github.com/helgklaizar/omni-parser-mlx) — Blazing-fast visual GUI agent.
- [🎞 **Open-Sora-MLX**](https://github.com/helgklaizar/open-sora-mlx) — Text-to-Video generation pipeline.
- [🚦 **Paged-Attention-MLX**](https://github.com/helgklaizar/paged-attention-mlx) — vLLM-style high-throughput serving.
- [🧠 **Rag-Indexer-MLX**](https://github.com/helgklaizar/rag-indexer-mlx) — Native system RAG with zero battery drain.
- [🚀 **RocketKV-MLX**](https://github.com/helgklaizar/rocket-kv-mlx) — Extreme cache pruning.
- [🌿 **SageAttention-MLX**](https://github.com/helgklaizar/sage-attention-mlx) — 5x faster quantized attention.
- [🚀 **TurboQuant-MLX**](https://github.com/helgklaizar/turboquant-mlx) — Extreme KV Cache Compression (1-3 bit).

---
**Core Ecosystem:**
[📡 **TeleFeed**](https://github.com/helgklaizar/TeleFeed) | [🧬 **Morphs**](https://github.com/helgklaizar/morphs) | [🏠 **Crafthouse**](https://github.com/helgklaizar/crafthouse) | [📊 **Stats-Bar-MLX**](https://github.com/helgklaizar/stats-bar-mlx)

