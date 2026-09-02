# 🔧 fix-mr for Claude Code

Automated MR review fix workflow — analyze comments, fix issues, push, and reopen. One skill, three commands.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Skills-blue)
![Version](https://img.shields.io/badge/Version-1.0.0-green)

## How It Works

![Workflow Diagram](docs/diagrams/workflow.svg)

![Sequence Diagram](docs/diagrams/sequence.svg)

**3-phase workflow:**

| Phase | Command | What Happens |
|-------|---------|-------------|
| 📖 Review | `/fix-mr review <MR_URL>` | Read MR comments, extract issues, classify valid/invalid/manual |
| 🔨 Fix | `/fix-mr fix <MR_URL>` | Apply fixes, run build + tests, commit (no push) |
| 🚀 Reopen | `/fix-mr reopen <MR_URL>` | Push, post summary comment to MR, reopen |

## Commands

### `/fix-mr review <MR_URL>`

Read-only analysis. No code changes.

```bash
# Parses GitLab MR comments
# Classifies each finding:
#   ✅ Already fixed → skip
#   ❌ Still valid   → needs fix
#   ⏳ Manual task   → requires staging env

# Output: table of findings with status + file:line
```

### `/fix-mr fix <MR_URL>`

Apply valid fixes and commit.

```bash
# Reads the review analysis
# For each valid finding:
#   - Code fix: minimum change at file:line
#   - Test fix: add tests following project conventions
#   - DB fix: edit unmerged migration or create new one
#   - Doc fix: update annotations
#
# After all fixes:
#   build → test → git commit
# Does NOT push — run /fix-mr reopen when ready
```

### `/fix-mr reopen <MR_URL>`

Push, comment, and reopen.

```bash
# 1. git push origin <branch>
# 2. glab mr note create <ID> --message "<summary table>"
# 3. glab mr reopen <ID>
```

## Install

### One-Command (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Aguh18/fix-mr/main/install.sh | bash
```

### Clone & Install

```bash
git clone https://github.com/Aguh18/fix-mr.git
cd fix-mr
./install.sh
```

### Manual

Copy `fix-mr/SKILL.md` to your project's `.claude/skills/fix-mr/` directory:

```bash
mkdir -p .claude/skills/fix-mr
cp SKILL.md .claude/skills/fix-mr/
```

Or globally:

```bash
mkdir -p ~/.claude/skills/fix-mr
cp SKILL.md ~/.claude/skills/fix-mr/
```

## Requirements

| Tool | Purpose | Install |
|------|---------|---------|
| [glab](https://gitlab.com/gitlab-org/cli) | GitLab CLI for MR operations | `brew install glab` |
| [gh](https://cli.github.com) | GitHub CLI (for repo setup only) | `brew install gh` |

### Auth

```bash
# GitLab (required for MR read/write)
glab auth login --web

# GitHub (optional, for repo management)
gh auth login
```

## Workflow Diagram

![Sequence Diagram](docs/diagrams/sequence.svg)

## Example Session

```
You:  /fix-mr review https://gitlab.com/your-org/your-repo/-/merge_requests/123

Claude: Found 5 items from @reviewer:
        | # | Finding                  | Status    |
        |---|--------------------------|-----------|
        | 1 | Missing input validation | ❌ Needs fix |
        | 2 | Null pointer check       | ✅ Already fixed |
        | 3 | Unit test coverage       | ✅ Already fixed |
        | 4 | DB query optimization    | ❌ Needs fix |
        | 5 | Error message clarity    | ❌ Needs fix |

You:  /fix-mr fix https://gitlab.com/your-org/your-repo/-/merge_requests/123

Claude: [applies 2 fixes, runs tests, commits]
        Ready. Run /fix-mr reopen when done.

You:  /fix-mr reopen https://gitlab.com/your-org/your-repo/-/merge_requests/123

Claude: [pushes, posts summary, reopens MR]
        Done. MR #123 reopened.
```

## License

MIT License — see [LICENSE](LICENSE)

---

> Made with ❤️ for developers who want faster MR review cycles
