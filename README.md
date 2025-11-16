<p align="center">
  <img src="assets/summon-icon.svg" width="100" alt="Summon">
  <h1 align="center">Summon</h1>
  <a href="https://github.com/adi-sen/summon/releases">
    <img src="https://img.shields.io/github/v/release/adi-sen/summon?label=Download&style=flat-square" alt="Download">
  </a>
  <a href="https://github.com/adi-sen/summon/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/adi-sen/summon/release.yml?style=flat-square" alt="Build">
  </a>
  <br><br>
  <p>Summon is a fast, lightweight macOS launcher designed for efficient app access, clipboard management, and text expansion. Implemented in Rust and Swift, with performance-critical operations handled in Rust, it serves as an alternative to Spotlight, Raycast, and Alfred.</p>
</p>

## Features

- Application launcher with fuzzy search
- Clipboard history with image preview
- Text snippet expansion (Aho-Corasick)
- Calculator (math, currency, timezone conversion)
- Vim-style keyboard navigation
- Customizable themes and shortcuts

## Installation

Download the latest release from the [releases page](https://github.com/adi-sen/summon/releases).

Or build from source:

```bash
./scripts/build.sh release
./scripts/package.sh
cp -r .build/macos/Summon.app /Applications/
```

**Requirements**: macOS 12.0+, Rust, Xcode tools

## Usage

- **Open**: `Cmd+Space`
- **Navigate**: `↑/↓`, `Ctrl+J/K`, `Ctrl+N/P`
- **Quick select**: `Cmd+1-9`
- **Clipboard**: Press `Tab` or type `clip`
- **Calculator**: `2+2`, `100 USD to EUR`, `3pm EST to PST`

## Architecture

```
Swift/SwiftUI Frontend
└── FFI → Rust Core
         ├── nucleo (fuzzy search)
         ├── Aho-Corasick (snippets)
         ├── evalexpr (calculator)
         └── rkyv (storage)
```


