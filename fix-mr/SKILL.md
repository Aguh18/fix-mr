---
name: fix-mr
description: Auto-fix issues from a closed GitLab MR review. Reads reviewer comments, validates findings against codebase, fixes valid issues, pushes, and posts summary. Trigger: `/fix-mr <MR_URL>`
---

# fix-mr — Automated MR Review Fix

Takes a GitLab MR link (closed), reads reviewer comments, analyzes each finding, fixes valid issues, pushes, and posts a summary comment.

## Usage

```
/fix-mr https://gitlab.com/<org>/<repo>/-/merge_requests/<ID>
```

## Workflow

### Step 1: Parse MR Link
Extract from URL:
- `GL_REPO` = `<org>/<repo>` (URL-decoded)
- `MR_ID` = the number after `/merge_requests/`

### Step 2: Fetch MR Metadata + Comments
```bash
glab mr view $MR_ID
glab mr view $MR_ID --comments
```

Parse from output:
- `reviewers:` line → reviewer username
- `source_branch:` line → current branch
- `author:` line → MR author
- Comment blocks → each finding

### Step 3: Analyze Findings
For each finding:
1. **Identify the category** — Code Fix, Test Fix, Security Fix, Database Fix, Documentation Fix, Performance Fix
2. **Locate the file** — search codebase for mentioned file paths
3. **Read the current code** — check if issue still exists
4. **Determine validity:**
   - ✅ **Already fixed** → skip
   - ❌ **Still valid** → fix it
   - ⏳ **Manual task** → note as requiring manual verification

### Step 4: Fix Valid Issues

**Code fixes:**
- Read the file at the mentioned line
- Apply the minimum fix
- Verify with `go build ./...` after each fix

**Test fixes:**
- Add test to appropriate `*_test.go` file
- Use existing patterns (stubs, integration helpers, etc.)

**Database fixes:**
- If migration not yet merged → edit existing migration
- If migration already merged → create new migration with `date -u +"%Y%m%d%H%M%S"`

**Documentation fixes:**
- Update swagger annotations, README, or inline docs

### Step 5: Verify
```bash
go build ./...
go vet ./...
go test ./... -count=1 -timeout 60s
```

### Step 6: Commit + Push
```bash
git add -A
git commit -m "fix(<module>): resolve <N> reviewer findings

<list each fix>

Co-Authored-By: Claude Code <noreply@anthropic.com>"
git push origin <branch>
```

### Step 7: Post Summary Comment + Reopen
```bash
glab mr note create $MR_ID --message "<summary>"
glab mr reopen $MR_ID
```

Summary format:
```markdown
Hi @<reviewer>, here's the status of all items from the review:

| # | Issue | Status | File:Line |
|---|-------|--------|-----------|
| 1 | <finding> | ✅ Fixed / ⏳ Manual / ❌ Not valid | `<file>:<line>` — <what was done> |

**Migration test result:** <result if applicable>

Items marked ⏳ require manual verification in a staging environment.
```

## Important Rules

1. **Never modify already-merged migrations** — create new ones instead
2. **Check branch state first** — `git branch --show-current` and `git status --short`
3. **Read before editing** — always `Read` or `cat` the file before editing
4. **Verify reviewer name** — check `glab mr view` output, don't guess
5. **One build check after all fixes** — not after each individual fix
6. **Keep fixes minimal** — YAGNI, fix what's asked, nothing more

## Error Handling

- If `glab` is not installed → `brew install glab` then `! glab auth login --web`
- If `TEST_DATABASE_DSN` not set → integration tests skipped automatically
- If migration has timestamp collision → rename with new unique timestamp
- If build fails after fix → read error, fix, re-verify
