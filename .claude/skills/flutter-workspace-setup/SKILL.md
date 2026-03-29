---
name: flutter-workspace-setup
description: Set up MCP servers and tooling for Flutter/Dart development in this repo. Installs dart-flutter MCP, mcp_flutter widget inspector, and GitHub MCP. Run once per developer machine. Use when onboarding to this project or setting up a new workstation.
argument-hint: ""
---

# Flutter Workspace MCP Setup

Set up the recommended MCP servers for Flutter/Dart development in this repo. Walk through each step interactively, explaining what will be installed and asking for confirmation before proceeding.

## Notes on this guide

This skill was written based on a real setup session. Several things from naive/LLM-generated setup guides were found to be broken or outdated — those are documented with ⚠️ warnings below. Trust this guide over any other version you may find.

---

## Phase 0: Prerequisites Check

Run all checks before doing anything else:

```bash
flutter --version    # Need Flutter 3.35+ / Dart 3.9+
dart --version
node --version       # Required for some MCP servers
claude --version
gh auth status       # GitHub CLI auth (needed for GitHub MCP)
```

If Dart SDK is below 3.9, stop and tell the user — `dart mcp-server` won't exist yet.

---

## Phase 1: dart-flutter MCP (Official Dart SDK Server)

**Explain to user:** This is the most important one. The official Dart MCP server ships with the Dart/Flutter SDK — no install needed. It gives Claude deep project context: error analysis, symbol resolution, pub.dev search, dependency management, test running, and code formatting. Without this, Claude is working blind on Dart code.

Ask the user if they want to proceed, then run:

```bash
claude mcp add --transport stdio dart-flutter --scope project -- dart mcp-server
```

Verify with `claude mcp list` — should show `dart-flutter: dart mcp-server - ✓ Connected`.

---

## Phase 2: flutter-mcp (pub.dev Documentation) — SKIP

**Explain to user and skip this step entirely.**

⚠️ This package (`npx flutter-mcp`) is broken. The npm wrapper tries to `pip install flutter-mcp` but that Python package does not exist on PyPI ("coming soon" per the README). There is no working installation path as of March 2026.

The dart-flutter MCP from Phase 1 already covers pub.dev search. Skip this.

---

## Phase 3: mcp_flutter (Flutter Inspector / Widget Tree)

**Explain to user:** This connects Claude to your *running* Flutter app via the Dart VM service. It enables live widget tree inspection and screenshot capture. Requires:
- Cloning a repo to `~/Developer/mcp_flutter` and building a native binary
- Adding a small `mcp_toolkit` package to this project's pubspec.yaml
- A few lines added to main.dart

Note the security tradeoff: running your app with `--disable-service-auth-codes` (required for the inspector to connect) disables VM service authentication. This is debug-only and never affects production builds.

Ask the user if they want to proceed, then:

**1. Clone and build:**

```bash
mkdir -p ~/Developer
git clone https://github.com/Arenukvern/mcp_flutter ~/Developer/mcp_flutter
cd ~/Developer/mcp_flutter && make install
```

Expected output ends with: `Generated: ~/Developer/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp`

**2. Register with Claude Code:**

```bash
claude mcp add flutter-inspector ~/Developer/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp -- --dart-vm-host=localhost --dart-vm-port=8181 --no-resources --images
```

Note: this registers at local (not project) scope because the binary path is machine-specific.

**3. Add mcp_toolkit to this project:**

```bash
cd <repo-root>/frontend && flutter pub add mcp_toolkit
```

**4. Initialize MCPToolkitBinding in main.dart:**

Read `frontend/lib/main.dart`. After `WidgetsFlutterBinding.ensureInitialized();`, add:

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

// in main():
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();
```

Run `dart analyze lib/main.dart` to confirm no issues.

**Tell the user:** To use the inspector, run the app with:

```bash
flutter run -d <device> --debug --host-vmservice-port=8181 --enable-vm-service --disable-service-auth-codes
```

---

## Phase 4: GitHub MCP Server

**Explain to user:** Gives Claude read/write access to GitHub issues, PRs, and branches. Requires `GITHUB_PERSONAL_ACCESS_TOKEN` to be set as an env var.

⚠️ The guide's original command (`npx -y @modelcontextprotocol/server-github`) is **deprecated and archived**. Use the official `github/github-mcp-server` Go binary instead.

Ask the user if they want to proceed.

**1. Check for an existing token:**

```bash
gh auth status
```

If authenticated, the `gh` token can be used directly — no separate PAT needed.

**2. Set up `~/.zshrc.auth`:**

Check if `~/.zshrc.auth` already exists. If not, create it:

```bash
# ~/.zshrc.auth
# Auth tokens for third-party tools
# Regenerate with: export GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token)
export GITHUB_PERSONAL_ACCESS_TOKEN=<output of `gh auth token`>
```

Write the **actual token value** (not the command substitution) so it doesn't call the API on every terminal open. Add the regeneration command as a comment.

Then add to `~/.zshrc` (if not already present):
```bash
source ~/.zshrc.auth
```

**3. Install the binary:**

```bash
brew install github-mcp-server
```

**4. Register with Claude Code:**

```bash
claude mcp add --transport stdio github --scope project -- github-mcp-server stdio
```

Do NOT use `-e GITHUB_PERSONAL_ACCESS_TOKEN=...` here — that would bake the token value into `.mcp.json` which gets committed to the repo. The server inherits the env var from the shell automatically since it's set in `~/.zshrc.auth`.

Verify with `claude mcp list` — should show `github: github-mcp-server stdio - ✓ Connected`.

---

## Phase 5: DCM MCP — SKIP

**Explain to user and skip.**

DCM is a commercial Flutter linter. Its free/community tier is being sunsetted. Unless the user has an active paid DCM license, skip this step.

---

## Phase 6: Dart LSP Plugin — NOT YET AVAILABLE

**Explain to user:** There is an open feature request for a Dart/Flutter LSP plugin for Claude Code (anthropics/claude-code#16849, opened January 2026, 67+ upvotes). It does not exist yet. Nothing to install.

---

## Phase 7: Commit .mcp.json

**Explain to user:** The `--scope project` flag in Phases 1 and 4 wrote server configs to `.mcp.json` in the repo root. Committing this means every team member automatically gets the same Claude setup.

Ask the user if they want to commit now. If yes:

```bash
git add .mcp.json
git commit -m "chore: add Claude MCP server configuration for Flutter development

- dart-flutter: official Dart SDK MCP server (code analysis, pub.dev search)
- github: official GitHub MCP server (issues, PRs, branches)

🤖 Co-created with Claude"
```

---

## Final Verification

Run `claude mcp list` and confirm the following are connected:
- `dart-flutter` ✓
- `github` ✓
- `flutter-inspector` ✓ (if Phase 3 was completed)

Test by asking Claude:
- "Search pub.dev for a package for infinite scroll" → exercises `dart-flutter`
- "List open GitHub issues in this repo" → exercises `github`

---

## What Was Skipped and Why

| Server | Status | Reason |
|--------|--------|--------|
| flutter-mcp | ⚠️ Broken | PyPI package doesn't exist; npm wrapper fails |
| DCM MCP | ⏭️ Commercial | Free tier being sunsetted |
| Dart LSP plugin | ⏳ Not released | Tracking: anthropics/claude-code#16849 |
