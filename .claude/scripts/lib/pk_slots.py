"""pk_slots — extract reviewer-consumed slot blocks from PROJECT-KNOWLEDGE.md.

Reviewer agents (plan-reviewer, code-reviewer) reference a fixed set of named
slots from PROJECT-KNOWLEDGE.md. inject-review-context.sh historically injected
a blind ``pk_content[:4096]`` byte prefix into the SubagentStart additionalContext,
carrying ~1.1 KB of dead frontmatter / H1 / HTML-comment plus arbitrary non-slot
prose between slots. ``extract_pk_slots`` returns only the consumed slot blocks
(the ``- SLOT:`` line plus its indented continuation — YAML block scalars and
slot-owned trailing ``#`` comments), in source order.

Contract-neutral: PK is reviewer reference data injected as additionalContext.
It is NOT a field in any of the 4 handoff payloads, not part of the VERDICT /
VERDICT_JSON envelope, and not an input to the canonical issue ID
sha256(category|location|problem)[:8]. Changing WHICH PK bytes are injected
changes no hashed byte and no contract shape.

See .claude/workflow-audit-2026-05-30.md (backlog #4) for provenance.
"""
import re

# Slots referenced by plan-reviewer.md / code-reviewer.md. Keep in sync with
# those agents' slot citations (audit #4: code-reviewer.md L36/L69/L70/L145/
# L147/L152/L169/L170, plan-reviewer.md L34/L81/L83).
CONSUMED_SLOTS = (
    "LAYER_RULE", "ERROR_WRAP", "LINT_CMD", "TEST_CMD", "VERIFY_CMD",
    "DOMAIN_PROHIBIT", "GENERATED_PATTERN", "MOCK_PATTERN",
    "ARCHITECTURE_STYLE", "SOURCE_GLOB", "LANG_EXT", "DEPENDENCY_FILE",
)

# A slot is a YAML list item: optional indent, '-', spaces, NAME, ':'.
_SLOT_RE = re.compile(r"^(\s*)-\s+([A-Z][A-Z0-9_]*)\s*:(.*)$")


def _indent(line):
    # Space-only indentation: counts leading spaces. Safe because YAML forbids
    # tabs in indentation, so a spec-valid PROJECT-KNOWLEDGE.md never tab-indents
    # a slot continuation (CR-001). A tab-led line would read as indent 0 and end
    # the block; acceptable since the fallback path keeps the full content.
    return len(line) - len(line.lstrip(" "))


def extract_pk_slots(pk_text, consumed_slots=CONSUMED_SLOTS):
    """Return the consumed-slot blocks from ``pk_text`` as a single string.

    Each block = the ``- SLOT:`` line plus every following line that is blank or
    indented deeper than the slot's list marker (captures multi-line YAML block
    scalars and slot-owned trailing ``#`` comments), with trailing blank lines
    trimmed. Blocks are emitted in source order. Non-consumed slots and the
    file's dead prefix (frontmatter, H1, HTML comments) are excluded.

    Returns "" if no consumed slot is found — the caller treats that as a signal
    to fall back to the legacy capped prefix (unexpected PK shape).
    """
    wanted = set(consumed_slots)
    lines = pk_text.splitlines()
    n = len(lines)
    out = []
    i = 0
    while i < n:
        m = _SLOT_RE.match(lines[i])
        if m and m.group(2) in wanted:
            base = _indent(lines[i])  # column of the '-' marker
            block = [lines[i]]
            j = i + 1
            while j < n:
                ln = lines[j]
                if ln.strip() == "" or _indent(ln) > base:
                    block.append(ln)
                    j += 1
                else:
                    break
            while block and block[-1].strip() == "":
                block.pop()
            out.append("\n".join(block))
            i = j
            continue
        i += 1
    return "\n".join(out)
