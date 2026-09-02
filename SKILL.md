---
name: fix-mr
description: Automated MR review fix workflow with 3 subcommands: review (analyze), fix (apply), reopen (post & reopen). Trigger: `/fix-mr review|fix|reopen <MR_URL>`
---

# fix-mr — Automated MR Review Fix Workflow

3-phase workflow for fixing GitLab MR review findings.

---

## `/fix-mr review <MR_URL>`

Read-only analysis. No code changes.

### Steps

1. **Parse URL** → extract `MR_ID` from `/-/merge_requests/<ID>`

2. **Fetch metadata:**
```bash
glab mr view $MR_ID
glab mr view $MR_ID --comments
```

3. **Parse from output:**
- `reviewers:` → reviewer username
- `author:` → MR author
- `source_branch:` → branch name
- Comment blocks → list of findings

4. **For each finding:**
- Read mentioned file paths in the codebase
- Check if issue still exists
- Classify: ✅ Already fixed / ❌ Still valid / ⏳ Manual task

5. **Output:** Present findings as a numbered table to the user

```markdown
| # | Finding | Status |
|---|---------|--------|
| 1 | <short description of finding> | ❌ Needs fix |
| 2 | <short description of finding> | ✅ Already fixed |
| 3 | <short description of finding> | ⏳ Manual |
```

**Status types:**
- `❌ Needs fix` — code change required, can be auto-fixed
- `✅ Already fixed` — issue no longer exists in codebase
- `⏳ Manual` — requires human verification (e.g., load tests, EXPLAIN ANALYZE)

---

## `/fix-mr fix <MR_URL>`

Apply fixes. Commit but do NOT push.

### Steps

1. Run the same analysis as `review` step 1-4

2. For each ❌ **Needs fix** item, apply the fix:

**Code fixes:**
- Read the file, apply minimum change
- Error handling pattern: catch DB constraint violation → map to domain error
- Authorization pattern: add scope check for specific user roles

**Test fixes:**
- Add tests following project's existing test patterns and conventions

**Database fixes:**
- Migration not merged → edit existing `.up.sql`
- Migration already merged → new migration: `date -u +"%Y%m%d%H%M%S"` + unique name
- Never edit already-deployed migrations

**Documentation fixes:**
- Update `@Summary`, `@Description`, `@Param`, `@Failure` annotations

3. Verify:
```bash
# Run project's standard build and test commands
# Examples (adjust to project's stack):
# Go: go build ./... && go test ./...
# Node: npm run build && npm test
# Python: python -m pytest
```

4. Commit:
```bash
git add -A
git commit -m "fix(<module>): resolve <N> reviewer findings

<bullet list of each fix>

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

**Do NOT push.** Tell user: `Ready. Run /fix-mr reopen <MR_URL> when you want to push and post.`

---

## `/fix-mr reopen <MR_URL>`

Push, post summary, reopen.

### Steps

1. **Push:**
```bash
git push origin <current_branch>
```

2. **Post summary comment** to MR:
```bash
glab mr note create $MR_ID --message "<summary>"
```

Summary template:
```
Hi @<reviewer>, here's the status of all items from the review:

| # | Issue | Status | File:Line |
|---|-------|--------|-----------|
| 1 | <finding> | ✅ Fixed / ⏳ Manual / ❌ Not valid | `<file>:<line>` — <what was done> |

**Migration test result:** <if applicable>

Items marked ⏳ require manual verification in staging.
```

3. **Reopen MR:**
```bash
glab mr reopen $MR_ID
```

---
