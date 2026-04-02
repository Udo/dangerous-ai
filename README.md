# dangerous-ai

Small wrapper scripts for terminal AI tools that:

- install the tool automatically if it is missing
- try to follow the latest upstream release instead of pinning old versions
- smooth over local PATH/install-location issues
- expose a mostly consistent startup interface where the upstream tool allows it

ONLY USE THIS IN WELL-ISOLATED CONTAINERS! In fact, you probably should not use this at all. The name is intentional: several of these tools are launched in highly permissive or fully automatic modes. Read the safety notes before using them on anything important.

## What Is Here

- [`opencode`](/root/dangerous-ai/opencode): OpenCode wrapper
- [`codex`](/root/dangerous-ai/codex): OpenAI Codex CLI wrapper
- [`claude`](/root/dangerous-ai/claude): Claude Code wrapper
- [`gemini`](/root/dangerous-ai/gemini): Gemini CLI wrapper
- [`aider`](/root/dangerous-ai/aider): aider wrapper
- [`goose`](/root/dangerous-ai/goose): Goose wrapper
- [`kiro`](/root/dangerous-ai/kiro): Kiro CLI wrapper
- [`amp`](/root/dangerous-ai/amp): Amp CLI wrapper
- [`llm`](/root/dangerous-ai/llm): Simon Willison's `llm` wrapper
- [`copilot`](/root/dangerous-ai/copilot): GitHub Copilot CLI wrapper
- [`setup-opencode-local-provider.sh`](/root/dangerous-ai/setup-opencode-local-provider.sh): helper for provisioning a remote OpenCode install against a local OpenAI-compatible endpoint
- [`_common.sh`](/root/dangerous-ai/_common.sh): shared helper code used by the wrappers

## Common Behavior

Most wrappers do some combination of:

- prepend common user-local bin directories to `PATH`
- resolve the real binary while avoiding recursion back into the wrapper script
- auto-install the tool if missing
- forward remaining arguments to the underlying CLI

The shared helper in [`_common.sh`](/root/dangerous-ai/_common.sh) centralizes:

- PATH setup
- shell hash refresh after install
- binary resolution
- npm-based installs
- `uv` bootstrapping for Python tool installs

## Installation Strategy

There is no single install strategy for all tools.

- npm-based CLIs:
  - `opencode`
  - `codex`
  - `claude`
  - `copilot`
  - `gemini`
- curl/official installer based:
  - `amp`
  - `goose`
  - `kiro`
- Python-based:
  - `aider`
  - `llm`

Important detail:

- [`aider`](/root/dangerous-ai/aider) uses `uv tool install --python 3.12 aider-chat` instead of raw `pip install`.
  This avoids the Debian/Ubuntu PEP 668 problem and also works around Python 3.13 incompatibilities in stale package indexes.
- [`llm`](/root/dangerous-ai/llm) installs into a private virtualenv instead of touching the system Python.

## Supported Flags

These wrappers are similar, not identical.

### OpenAI/Ollama-style `--server`

Custom erver registration is implemented for:

- [`opencode`](/root/dangerous-ai/opencode)
- [`aider`](/root/dangerous-ai/aider)
- [`goose`](/root/dangerous-ai/goose)
- [`llm`](/root/dangerous-ai/llm)

which will probe:

- `http://HOST:PORT/v1/models`
- or Ollama-style `http://HOST:PORT/api/tags`

and then update the tool's config in the format that tool actually uses.

### Simple endpoint override

`--api-url` or `--server` only as a direct endpoint override for the current run:

- [`codex`](/root/dangerous-ai/codex)
- [`claude`](/root/dangerous-ai/claude)

### Model selection only

These support model selection but do not currently expose a documented custom inference server:

- [`gemini`](/root/dangerous-ai/gemini)
- [`kiro`](/root/dangerous-ai/kiro)
- [`amp`](/root/dangerous-ai/amp)
- [`copilot`](/root/dangerous-ai/copilot)

## Examples

Run OpenCode:

```bash
./opencode
```

Run Codex against a custom endpoint:

```bash
./codex --server llm2:80 --model gpt-5
```

Add a local server to OpenCode and launch it:

```bash
./opencode --server llm2:80
```

Add a local server to aider:

```bash
./aider --server llm2:80
```

Run Goose against a one-off OpenAI-compatible endpoint:

```bash
./goose --api-url http://llm2:80/v1 --model qwen2.5-coder
```

Set Kiro's default model before launch:

```bash
./kiro --model claude-3.7-sonnet
```

## License

This repository is GPL-3.0-or-later. See [`LICENSE`](/root/dangerous-ai/LICENSE).
