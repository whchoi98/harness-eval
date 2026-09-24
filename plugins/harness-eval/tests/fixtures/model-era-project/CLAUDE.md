# Model-Era Fixture

Regression fixture for the `model-config` and `agent-format` static-analysis checks
(both in the `correctness` category). Every file is test data, not configuration to copy.

`model-config` reads only YAML frontmatter `model:` / `effort:` lines and settings keys,
never markdown bodies. For skills it reads only `.claude/skills/<name>/SKILL.md`, the one
file Claude Code loads as the skill. Expected results:

| File | Content | Expected |
| ---- | ------- | -------- |
| `.claude/agents/retired.md` | `model: claude-3-5-sonnet-20241022` | FAIL (retired generation; beats the snapshot rule) |
| `.claude/agents/retired41.md` | `model: claude-opus-4-1` | FAIL (retired-model table) |
| `.claude/agents/deprecated.md` | `model: claude-sonnet-4-0` | WARN (deprecated) |
| `.claude/agents/snapshot.md` | quoted dated ID with a trailing `#` comment | WARN (dated snapshot; quotes and comment stripped) |
| `.claude/agents/typo.md` | `model: claude-sonnet-4.5` | WARN (unrecognized Claude model ID) |
| `.claude/agents/typo55.md` | `model: claude-opus-55` (a mistyped `claude-opus-5-5`) | WARN (unrecognized Claude model ID) |
| `.claude/agents/unreleased.md` | `model: claude-sonnet-4-7`, well formed but never released | WARN (unrecognized Claude model ID) |
| `.claude/agents/inherit.md` | `model: inherit`, `effort: turbo` | WARN (invalid effort) |
| `.claude/agents/pinned.md` | `model: claude-opus-5-5`, `effort: low`; body mentions a retired ID | not flagged |
| `.claude/agents/fable.md` | `model: fable[1m]`, `effort: 3` | not flagged |
| `.claude/skills/summarize/SKILL.md` | `model: sonnet`, `effort: max` | not flagged |
| `.claude/skills/summarize/agent-template.md` | supporting file whose frontmatter pins a retired ID | not read |
| `.claude/commands/ship.md` | `model: gpt-4o` | WARN (not an alias or claude-* ID) |
| `.claude/settings.json` | `alwaysThinkingEnabled: false`, `env.MAX_THINKING_TOKENS`, `env.CLAUDE_CODE_DISABLE_THINKING: "1"` (reported because `model` is `opus`, an always-thinking model), `env.CLAUDE_CODE_EFFORT_LEVEL: "maximum"` (invalid), deprecated `env` model; `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING: "0"` (off, so not reported); valid `model`, `effortLevel`, `env` model | one WARN for the file |

The 10 valid values are reported as a single aggregated `model-config` PASS.

`agent-format`: `.claude/agents/reviewer.yml` and `.claude/agents/triage.json` each produce a
WARN (Claude Code loads only `.md` agents). The `model:` inside `reviewer.yml` is not read by
`model-config`.

Correctness category: 6 PASS, 10 WARN, 2 FAIL, score 6.1. Safety and completeness results
are out of scope for this fixture. It is NOT part of the maturity ladder.

`settings.local.json`, plugin roots (`.claude-plugin/plugin.json`, `plugins/*/`), CRLF
frontmatter, every served model ID, a valid `CLAUDE_CODE_EFFORT_LEVEL`, and thinking caps
under a model that accepts disabled thinking (including the Bedrock and Vertex spellings
of Opus 5) are covered by temporary fixtures inside `tests/test-static-analysis.sh`:
`*.local.json` is gitignored, a plugin manifest here would change what this fixture
measures, and this settings file can pin only one model.
