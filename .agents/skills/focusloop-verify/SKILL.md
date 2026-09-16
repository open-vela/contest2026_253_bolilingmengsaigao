---
name: focusloop-verify
description: Validate the FocusLoop openvela contest project before review or submission. Use when checking QuickApp tests and builds, shell scripts, generated RPK artifacts, reproducible ai_agent patches, credential leakage, documentation wording, or final submission readiness.
---

# FocusLoop Verify

Run the deterministic verification script from the repository root. On Windows,
use PowerShell directly; the Bash entry point delegates to it when running under
WSL:

```bash
bash .Codex/skills/focusloop-verify/scripts/verify_focusloop.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .Codex/skills/focusloop-verify/scripts/verify_focusloop.ps1
```

## Workflow

1. Preserve the working tree. Do not reset, clean, upload, or push.
2. Run the bundled script and capture every failed check.
3. Fix failures in the smallest owning module.
4. Run the script again until it exits successfully.
5. Report the test count, RPK path and size, audit result, and any device-only checks that remain.

Treat Goldfish compilation, voice runtime, and `service.health` runtime as separate evidence. Never describe compilation alone as an end-to-end runtime pass.

Do not stage or upload `logs/` without explicit approval from the repository owner.
