# Skills Module

## Role
User-facing evaluation entry points. Each skill defines an evaluation mode that Claude follows when invoked.

## Key Files
- `quick/SKILL.md` — Fast checklist evaluation (< 30 seconds; `/harness-eval:quick` runs it at `effort: low`)
- `standard/SKILL.md` — Static + dynamic analysis evaluation (`--static-only` skips only the dynamic phase)
- `full/SKILL.md` — Multi-agent orchestrator for comprehensive evaluation
- `compare/SKILL.md` — Comparative analysis between two saved evaluations (`/harness-eval:compare` runs it at `effort: low`)

## Rules
- Skills use `skills/<name>/SKILL.md` directory convention (auto-discovered by Claude Code)
- Not registered in plugin.json — discovered automatically from directory structure
- Each skill states its outcome, the script and agent contracts it depends on, and how the result is verified; use numbered steps where order matters (script invocation, agent dispatch phases, report writing)
- Quick/Standard invoke scripts directly; Full dispatches subagents with the Agent tool (`Task` is its legacy alias and still works in `allowed-tools`) and leaves model and effort to each agent's frontmatter
- Full hands script output and the collector artifact between phases as files under the target's `.harness-eval/run/`, passed by absolute path, because a subagent returns only its final message. The three evaluator results are relayed to the synthesizer inline and verbatim, since the synthesizer parses their `## Scores` tables. The synthesizer is the only component that saves Full history and writes the Full report files on the normal path; when the collector fails, the Full skill saves the Standard checklist score and writes the `full-fallback` reports itself
- Full tells the user in one line what each of Phases 1-3 runs when it starts and in one line what it produced when it ends, failure markers and fallbacks included, because a Full run spends minutes on scripts and subagents the user cannot see. Phase 4, the presentation, needs no such lines
- Full Step 1.1 and Standard Phase 3 create `.harness-eval/.gitignore` containing `*` when there is none, so git ignores the evaluation files; an existing `.gitignore` or a symlink by that name is left untouched (`history.sh save` follows the same rule). Quick and Compare do not create it; Compare works from saved history, and a save creates it
- No skill runs `badge.sh`; the README badge changes only through the opt-in Stop hook (`hooks/CLAUDE.md`) or when the user runs it
- `${CLAUDE_PLUGIN_ROOT}` is substituted only in content Claude Code loads as a command, skill, or agent. When a command reads a SKILL.md with the Read tool the variable stays literal, so the command tells the model the real path to use in the commands it runs and in any command it shows the user
- All evaluation skills generate bilingual reports (English + Korean) as separate files
- Reports are saved to `.harness-eval/reports/` in the target project:
  - Standard: `{id}-standard-{en|ko}.md`, where `{id}` (`eval-{date}-{NNN}`) comes from the history save that runs before the report is written
  - Full: `{id}-full-{en|ko}.md`, written by the synthesizer; the collector-failure fallback writes `{id}-full-fallback-{en|ko}.md`
  - Compare: `{current.id}-compare-{en|ko}.md`
  - Quick: `eval-{date}-{NNN}-quick-{en|ko}.md`. Quick runs are not saved to history, so `{NNN}` is a per-day Quick report counter, not a history ID
  - When a history save fails, the name uses `unsaved` in place of `{NNN}`: `eval-{date}-unsaved-{mode}-{en|ko}.md` (`unsaved-full-fallback` for the fallback)
  - A name that can repeat (an `unsaved` name, or a Compare report run again without a new evaluation) may already exist, and the Write tool refuses to overwrite a file it has not read, so the component that writes it reads the existing file first: the skill for Standard, Compare, and the Full fallback, and the synthesizer for Full's `unsaved-full` names

## Command/Skill coexistence
The `quick`, `standard`, `full`, and `compare` skills intentionally share their names with
same-named slash commands under `commands/` (both surface as `harness-eval:quick`, etc.).
For a shared name Claude Code shows the **command's** `description` and hides the skill's, so
routing text (when to use this mode, when not to) must be in `commands/<mode>.md`. The command
is a thin wrapper that reads this directory's `SKILL.md` by path and follows it; the skill holds
the evaluation steps. Keep the two in sync: if you rename or repurpose a mode, or change
`effort`, update both the `commands/<mode>.md` wrapper and this skill so they do not diverge.
The skill-side `effort` does not apply on the plugin's entry points: each command reads
SKILL.md with the Read tool, so only the command's `effort` counts, and the `/harness-eval`
router (no `effort`) runs every mode at the session effort. Keep the skill value only as a
record of intent.
Do NOT place a `CLAUDE.md` (or any non-component `.md`) under `commands/` or `agents/` — those
directories are auto-discovered and a stray `.md` registers as a broken command/agent. Module
notes for those directories live in the plugin-root `CLAUDE.md` instead.
