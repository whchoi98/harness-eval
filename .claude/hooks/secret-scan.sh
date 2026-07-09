#!/bin/bash
# Scan staged files for secrets.
# Wired as a Claude Code PreToolUse hook (matcher: Bash) in .claude/settings.json:
# it inspects the currently git-staged files on every Bash tool call.
# Exit 2 to BLOCK the tool call when secrets are found (Claude Code treats
# only exit code 2 as a block; the block reason is emitted on stderr).

SECRETS_FOUND=0

# Patterns to detect (PCRE syntax; see grep -P detection below)
PATTERNS=(
    'AKIA[0-9A-Z]{16}'                          # AWS Access Key ID
    'aws_secret_access_key\s*[=:]\s*[A-Za-z0-9/+=]{40}' # AWS Secret Key (context-aware, no lookbehind)
    'sk-[A-Za-z0-9]{20}T3BlbkFJ[A-Za-z0-9]{20}' # OpenAI API Key
    'sk-ant-[A-Za-z0-9-]{90,}'                   # Anthropic API Key
    'ghp_[A-Za-z0-9]{36}'                        # GitHub Personal Access Token
    'gho_[A-Za-z0-9]{36}'                        # GitHub OAuth Token
    'github_pat_[A-Za-z0-9_]{82}'                # GitHub Fine-grained PAT
    'xoxb-[0-9]+-[A-Za-z0-9]+'                   # Slack Bot Token
    'xoxp-[0-9]+-[A-Za-z0-9]+'                   # Slack User Token
    'sk_live_[A-Za-z0-9]{24,}'                   # Stripe Secret Key
    'rk_live_[A-Za-z0-9]{24,}'                   # Stripe Restricted Key
    'AIza[A-Za-z0-9_-]{35}'                      # Google API Key
    'ya29\.[A-Za-z0-9_-]{50,}'                   # Google OAuth Token
    'DefaultEndpointsProtocol=https;Account'     # Azure Connection String
    'password\s*[:=]\s*["\x27][^"\x27]{8,}'      # Password assignments
    'secret\s*[:=]\s*["\x27][^"\x27]{8,}'        # Secret assignments
    'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}'   # API key assignments
)

# Files to skip. These are matched against BOTH the full staged path and the
# basename, so bare names (e.g. 'secret-scan.sh') skip the file wherever it
# lives. The scanner's own pattern definitions and its test corpus legitimately
# contain secret-shaped strings, so they are excluded here (as any credential
# scanner excludes its own fixtures).
SKIP_PATTERNS=(
    '.env.example'
    'secret-scan.sh'
    'test-secret-patterns.sh'
    'secret-samples.txt'
    'false-positives.txt'
    '*.md'
    'package-lock.json'
    'yarn.lock'
)

# Determine whether grep supports PCRE (-P). GNU grep on Linux does; BSD/macOS
# grep does not. Fall back to -E (ERE) best-effort and warn so the security
# check never fails silently.
GREP_FLAG="-P"
if ! echo "x" | grep -qP "x" 2>/dev/null; then
    GREP_FLAG="-E"
    echo "[secret-scan] warning: grep -P (PCRE) unavailable; using -E fallback. Some patterns may be relaxed." >&2
fi

scan_file() {
    local file="$1" regex="$2" err rc
    err=$(grep -q "$GREP_FLAG" -e "$regex" "$file" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        return 0            # match
    elif [ "$rc" -ge 2 ]; then
        # rc>=2 means grep error (e.g. pattern failed to compile) — surface it,
        # do not treat a broken pattern as "no secret".
        echo "[secret-scan] warning: pattern failed on $file: ${regex:0:40} (${err})" >&2
    fi
    return 1                # no match / error
}

# Iterate staged files NUL-delimited to survive spaces/newlines in names.
# Use process substitution (not a pipe) so SECRETS_FOUND survives the loop.
while IFS= read -r -d '' file; do
    # Skip excluded patterns (match full path or basename)
    skip=false
    base="${file##*/}"
    for pattern in "${SKIP_PATTERNS[@]}"; do
        # SC2053: glob matching on $pattern is intentional (e.g. '*.md', 'yarn.lock').
        # shellcheck disable=SC2053
        [[ "$file" == $pattern || "$base" == $pattern ]] && skip=true && break
    done
    $skip && continue
    [ ! -f "$file" ] && continue

    for regex in "${PATTERNS[@]}"; do
        if scan_file "$file" "$regex"; then
            echo "[secret-scan] Potential secret found in $file (pattern: ${regex:0:30}...)" >&2
            SECRETS_FOUND=1
        fi
    done
done < <(git diff --cached --name-only -z --diff-filter=ACM 2>/dev/null)

if [ "$SECRETS_FOUND" -eq 1 ]; then
    {
        echo ""
        echo "[secret-scan] BLOCKED: Potential secrets detected in staged files."
        echo "[secret-scan] Review the files above and remove secrets before committing."
        echo "[secret-scan] Use .env files for secrets and .env.example for templates."
    } >&2
    exit 2
fi

exit 0
