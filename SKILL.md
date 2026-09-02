---
name: fix-mr
description: Automated MR review fix workflow with 3 subcommands: review (analyze), fix (apply), reopen (post & reopen). Trigger: `/fix-mr review|fix|reopen <MR_URL>`
---

# fix-mr — Automated MR Review Fix Workflow

3-phase workflow for fixing GitLab MR review findings.

## Subcommands

```
/fix-mr review <MR_URL>   → Read comments, extract issues, show validity analysis
/fix-mr fix <MR_URL>      → Apply valid fixes, commit, do NOT push
/fix-mr reopen <MR_URL>   → Push, post summary comment, reopen MR
```

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
- `reviewers:` → reviewer username (e.g. `farizasandaira`)
- `author:` → MR author
- `source_branch:` → branch name
- Comment blocks → list of findings

4. **For each finding:**
- Read mentioned file paths in the codebase
- Check if issue still exists
- Classify: ✅ Already fixed / ❌ Still valid / ⏳ Manual task

5. **Output:** Present findings as a table to the user

```
| # | Finding | Status | Reason |
|---|---------|--------|--------|
| 1 | <description> | ✅ Already fixed / ❌ Needs fix / ⏳ Manual | <file:line> |
```

---

## `/fix-mr fix <MR_URL>`

Apply fixes. Commit but do NOT push.

### Steps

1. Run the same analysis as `review` step 1-4

2. For each ❌ **Needs fix** item, apply the fix:

**Code fixes:**
- Read the file, apply minimum change
- `isMerchantIdentifierConstraint` pattern: catch pg constraint → map to domain error
- `IsMerchantScoped()` pattern: add scope check for MERCHANT_USER

**Test fixes:**
- Add to existing `*_test.go` following file patterns (stubs for unit, `testdb.Pool` for integration)

**Database fixes:**
- Migration not merged → edit existing `.up.sql`
- Migration already merged → new migration: `date -u +"%Y%m%d%H%M%S"` + unique name
- Never edit already-deployed migrations

**Documentation fixes:**
- Update `@Summary`, `@Description`, `@Param`, `@Failure` annotations

3. Verify:
```bash
go build ./...
go vet ./...
go test ./... -count=1 -timeout 60s
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

## Rules

1. **Verify reviewer name** from `glab mr view` output — never guess
2. **Never modify already-merged migrations**
3. **Read before editing** — always Read/cat the file first
4. **Keep fixes minimal** — fix what's asked, nothing more
5. **fix never pushes** — only reopen pushes
6. **Use `ptr()` for string pointers, `ptrFloat()` for float pointers** — don't use `new()` for non-zero values

## Error Handling

- `glab` not installed → `brew install glab` then `! glab auth login --web`
- `TEST_DATABASE_DSN` not set → integration tests auto-skip via `t.Skip`
- Migration timestamp collision → `date -u +"%Y%m%d%H%M%S"` for new timestamp
- Build fails → read error, fix, re-verify before moving on
