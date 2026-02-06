# Phase 8: Installer & Setup - UAT

## Testable Deliverables

### From 08-01 (Install & Uninstall Scripts)

| # | Test | How to Verify | Status |
|---|------|---------------|--------|
| 1 | install.sh exists and is valid bash | `bash -n scripts/install.sh` should exit 0 | |
| 2 | uninstall.sh exists and is valid bash | `bash -n scripts/uninstall.sh` should exit 0 | |
| 3 | install.sh detects architecture | Read lines 51-61: `uname -m` with arm64/x86_64 case match | |
| 4 | install.sh fails hard without Homebrew | Read lines 67-75: exits 1 with clear install instructions | |
| 5 | install.sh prevents duplicate shell source lines | Read line 190: `grep -qF "terminal-remote/init."` check before appending | |
| 6 | install.sh creates LaunchAgent on user opt-in | Read lines 227-265: interactive prompt, plist creation, default "n" for piped input | |
| 7 | install.sh uses release archive for shell scripts | Read lines 144-146: copies from `$TMPDIR/shell-integration/init.*` (not master branch) | |
| 8 | uninstall.sh has confirmation prompt | Read lines 39-49: interactive prompt, auto-confirms when piped | |
| 9 | uninstall.sh removes all components | Read lines 54-118: processes, LaunchAgent, .app, shell lines, install dir, IPC socket | |
| 10 | uninstall.sh optional dep removal | Read lines 122-137: asks about cloudflared/tmux, defaults "n" when piped | |

### From 08-02 (Homebrew Cask & Release Workflow)

| # | Test | How to Verify | Status |
|---|------|---------------|--------|
| 11 | Homebrew cask has arch-specific downloads | Read terminal-remote.rb lines 6-11: on_arm/on_intel blocks | |
| 12 | Cask depends on cloudflared, tmux, ventura+ | Read lines 56-58: depends_on formula/macos stanzas | |
| 13 | Cask postflight copies shell integration | Read lines 24-48: copies init scripts, creates launcher | |
| 14 | Release workflow triggers on v* tags | Read release.yml lines 3-6: `push: tags: - 'v*'` | |
| 15 | Workflow builds both architectures | Read lines 18-24: matrix with arm64/macos-14 + x86_64/macos-13 | |
| 16 | Workflow builds web UI before relay-server | Read lines 46-54: pnpm build step before cargo build | |
| 17 | Archive naming matches across all files | install.sh:108, cask:7/10, workflow:75 all use same pattern | |

## Results

_Pending user verification_
