# Security Policy

## Supported versions

harness-eval is pre-1.0. Security fixes are applied to the latest released version and the
default branch only.

| Version | Supported |
| ------- | --------- |
| latest `0.x` | ✅ |
| older `0.x`  | ❌ (please upgrade) |

## Reporting a vulnerability

Please report suspected vulnerabilities **privately**. Do not open a public issue for a
security problem.

- Preferred: open a GitHub private security advisory
  (`Security` → `Report a vulnerability`) on `whchoi98/harness-eval`.
- Alternatively, email the maintainer: whchoi98@gmail.com.

Include a description, affected files/versions, reproduction steps, and impact. We aim to
acknowledge within a few business days and to coordinate a fix and disclosure timeline with
you.

## Security model and trust boundaries

harness-eval is a Bash plugin that inspects other projects. Understand these boundaries
before running it:

### It executes shell code
The plugin, its scripts, and the development-time hooks under `.claude/hooks/` are Bash. Only
install the plugin from a source you trust, and review changes to hooks and scripts.

### Evaluating untrusted projects
- **Quick mode** and static analysis only *read* the target project's files; they do not
  execute target code.
- **Standard / Full modes** may perform *dynamic* analysis that runs code belonging to the
  evaluated project (for example, invoking the project's own hooks or test scripts). Treat
  this as running untrusted code: only run dynamic analysis on projects you trust, prefer the
  static-only path when evaluating unknown code, and expect an explicit confirmation gate
  before any target code is executed.

### Output artifacts can leak data into VCS
Evaluation runs write results into the target project under `.harness-eval/` (`latest.json`,
history, and `reports/`). Reports may embed scanned file paths and excerpts of findings.
These paths are **gitignored** (`.harness-eval/`) so they are not committed by accident — do
not force-add them, and do not paste report contents into public issues without review.

### Consumers of `latest.json`
`badge.sh` reads `.harness-eval/latest.json` to render a badge. Because that file is
generated output, values flowing from it are handled as data (not interpolated into shell/awk
program text). Keep it gitignored and do not hand-edit it with untrusted content.

## The bundled secret scanner

The development hook `.claude/hooks/secret-scan.sh` is wired as a `PreToolUse` hook and scans
git-staged files for credential-shaped strings (AWS/GCP/GitHub/Slack/Stripe/Azure/etc.). When
a likely secret is found it **exits 2 to block the tool call** and prints the reason on
stderr. It is a best-effort guard, not a guarantee:

- It relies on PCRE (`grep -P`); on platforms without it the scanner falls back to a relaxed
  mode and warns on stderr rather than failing silently.
- It intentionally skips `*.md`, `.env.example`, lockfiles, and itself.

Never rely on it as your only control: keep secrets out of the repository, use `.env` files
(with `.env.example` templates), and rotate any credential that was ever committed.

## Hardening the harness itself

The repository's own `.claude/settings.json` ships a `deny` list blocking destructive Bash
patterns (`rm -rf`, `git push --force`, `git reset --hard`, `eval`, …). If you fork or extend
the plugin, keep those denies and add your own rather than removing them.
