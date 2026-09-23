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
- **Standard mode** performs *dynamic* analysis that runs code belonging to the evaluated
  project (its own hooks and test scripts). Treat this as running untrusted code: only run
  dynamic analysis on projects you trust, prefer the static-only path (`--static-only`) when
  evaluating unknown code, and expect an explicit confirmation gate before any target code
  is executed. The gate is the evaluation prompt asking you in chat, not a permission
  prompt, because the command pre-approves Bash (see below).
- **Full mode** does not run the target's hooks or tests. Its agents read the target's
  files, and those files may contain text written to steer an AI agent; every agent prompt
  treats target content as data to evaluate, not as instructions.

### Full-mode agent permissions
The five Full-mode subagents get the smallest tool set their job needs:

| Agent | Tools | Writes |
| ----- | ----- | ------ |
| collector | Read, Glob, Grep, Bash, Write | its inventory, `.harness-eval/run/artifact.md`, in the target project |
| safety-, completeness-, design-evaluator | Read, Glob, Grep | nothing (read-only) |
| synthesizer | Read, Bash, Write | `.harness-eval/run/record.json`, history (via `history.sh`), and `.harness-eval/reports/` in the target project |

The three evaluators stay read-only because they read untrusted target content in depth, so
a prompt injection in a target file cannot make them write files or run commands. The
collector and synthesizer do hold Bash. A subagent's `tools` list grants whole tools (it
cannot limit Bash to particular commands), so the limits are in their prompts. The
collector keeps Bash read-only apart from creating its output directory. The synthesizer
is told to run only `jq` (on `static.json` and on the `history.sh list` output), `cat` of
`.harness-eval/run/record.json`, `date -u`, `mkdir -p .harness-eval/reports`, and the
plugin's own `aggregate.sh` (its output redirected to `.harness-eval/run/record.json`) and
`history.sh`, and to write only under `.harness-eval/`. Your session's permission rules and
deny list are the enforcement layer; they apply to subagents too.

Every harness-eval command, including `/harness-eval:full` and `/harness-eval:standard`,
lists `Bash` in `allowed-tools`, which pre-approves every Bash command the orchestrator runs
while the command is active, even in a session that normally prompts. This matters most in
Full and Standard, where the orchestrator reads evaluator findings or script results that
quote the target's files. Claude Code still asks before a write that resolves outside the
project, including through a symlink. For an untrusted repository, prefer Quick or
`/harness-eval:standard --static-only`, and review the project before running Full.

### Output artifacts can leak data into VCS
Evaluation runs write results into the target project under `.harness-eval/`:
`latest.json`, `history.json`, `reports/` (one file per language), and `run/` (intermediate
files: script output, the collector's inventory, the scoring record), which each run
rewrites. Reports and the inventory may embed scanned file paths and excerpts of findings.
The collector lists every settings `env` key but quotes the value only for model, provider,
effort, thinking, and output-limit settings, and it replaces credential-shaped strings
elsewhere in the settings with `<redacted>`. The evaluators and the synthesizer are told to
cite a credential or other secret value by `file:line` and write `<redacted>` in its place.
That is a prompt instruction, not a filter, and findings can still quote other project
files, so review reports before sharing them.

The Full and Standard run-directory step and `history.sh save` write
`.harness-eval/.gitignore` (containing `*`) when the directory has none, so git ignores
everything under `.harness-eval/`. They leave an existing `.gitignore` there (or a symlink by
that name) unchanged. Quick writes only its reports and does not create the file, so a
project that has only had Quick runs has no such rule. Do not force-add these files, and do
not paste report contents into public issues without review.

`history.sh save` refuses to write (exit 2) when `.harness-eval/`, `history.json`, or
`latest.json` is a symlink or the wrong kind of file, and it writes each file through a
temporary file and a rename, so a repository cannot redirect these writes outside the
project. The temporary file takes the permissions of the file it replaces, so a
`history.json` or `latest.json` you have restricted (for example with `chmod 600`) stays
restricted after the next save.

### Consumers of `latest.json`
`badge.sh` reads `.harness-eval/latest.json` to render a badge. Because that file is
generated output, values flowing from it are handled as data (not interpolated into shell/awk
program text). Keep it gitignored and do not hand-edit it with untrusted content.

### README badge
`badge.sh` rewrites (or creates) the target project's `README.md`, so no evaluation mode runs
it. The plugin's Stop hook, which runs at the end of every Claude response, runs it only
after you opt in (`HARNESS_EVAL_AUTO_BADGE=1`, or `{"autoBadge": true}` in a
`.harness-eval/config.json` that git does not track), and only once per saved evaluation: a
`latest.json` newer than the hook's `.harness-eval/.badge-seen` marker and less than a day
old. Without opt-in it changes no file other than that marker (it writes a one-line note to
the hook's stderr, which Claude Code does not show for a successful hook).

Files committed to the evaluated repository do not trigger the hook or grant the opt-in. The
hook ignores a `.harness-eval/`, `latest.json`, `config.json`, or `.badge-seen` that is a
symlink, as well as a `latest.json` tracked by git, and it does not accept a git-tracked
`config.json` as an opt-in. Outside a git checkout (an unpacked archive, for example) the
tracked-file checks cannot apply, so remove a `.harness-eval/` directory that came with such
a project. `badge.sh` refuses a symlinked or non-regular `README.md` (exit 2) and rewrites
the file through a temporary file in the project, so it never writes through a link.

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
