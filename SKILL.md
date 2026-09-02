---
name: fix-mr
description: Review, fix, verify, and reopen GitLab merge requests safely.
version: 2.0.0
author: "[@farizasandaira](https://github.com/farizasandaira), [@Aguh18](https://github.com/Aguh18)"
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [gitlab, merge-request, code-review, testing, security, performance]
    related_skills: []
---

# fix-mr — Merge Request Review and Fix Workflow

Use this skill to turn GitLab MR findings into verified, minimal code changes. It has three explicit phases: `review` is read-only, `fix` changes code and commits locally but never pushes, and `reopen` is the only phase allowed to publish or change MR state. The workflow is evidence-first: never invent requirements, test results, identities, or completion states.

## When to Use

- `/fix-mr review <MR_URL>` to inspect and classify review findings.
- `/fix-mr fix <MR_URL>` to implement still-valid findings and run local gates.
- `/fix-mr reopen <MR_URL>` after the user explicitly wants the verified branch published.

Do not use this skill to merge an MR, bypass a failed gate, rewrite unrelated code, or infer acceptance criteria from Jira, Figma, or an MR description when the user did not provide them.

## Safety Contract

1. Treat the user's task and the reviewer's concrete comments as the mandate. Repository docs and MR metadata are evidence, not new requirements.
2. Read before editing. Trace each finding to the current symbol, call sites, tests, and configuration.
3. Make the smallest complete fix. Do not refactor unrelated code or silently change public behavior.
4. Never expose secrets. Do not read `.env` or credential files unless the user explicitly asks; redact DSNs, tokens, passwords, and private URLs from output and comments.
5. Never modify an already-deployed migration. Add a forward migration when schema history is already shared.
6. `review` never writes. `fix` never pushes or posts. `reopen` may push/post/reopen only after preflight and explicit invocation.
7. A test failure is a blocker, not an informational result. Never use `|| true`, output pipes that mask exit status, skipped tests, or fabricated evidence.
8. Do not auto-retry a failed external operation. Preserve the error and stop at the human gate.

## Commands

```
/fix-mr review <MR_URL>   Read comments and produce a finding ledger; no writes
/fix-mr fix <MR_URL>      Apply valid fixes, verify, and commit locally; no push
/fix-mr reopen <MR_URL>   Verify branch, push, post evidence, and reopen the MR
```

## Prerequisites

- A Git worktree on the MR source branch, with a clean or explicitly understood starting state.
- `glab` authenticated to the correct GitLab host for MR reads and writes.
- The repository's actual build, lint, test, migration, and benchmark commands. Discover them from manifests, Makefiles, CI files, and neighboring code; never assume Go merely because an example uses Go.
- Native project dependencies for applicable integration tests. Do not use Docker, Podman, or another container as a substitute for the project's native verification path.

Check tools through `terminal`, and use `read_file`, `search_files`, and `patch`/`write_file` for repository work. Before any external write, verify the current MR and branch again.

## Evidence Model

Maintain a finding ledger for every reviewer item. Each row must contain:

```
ID | source/comment | finding | classification | evidence | file:symbol | action | verification
```

Allowed classifications:

- `ALREADY_FIXED`: current code and tests prove the issue is gone.
- `NEEDS_FIX`: the issue remains and is within the requested code scope.
- `INVALID_OR_NOT_APPLICABLE`: explain the concrete contradiction; do not dismiss a finding by opinion.
- `MANUAL_REQUIRED`: requires staging, production-like infrastructure, credentials, or a reviewer decision unavailable locally.
- `BLOCKED`: required evidence or dependency is unavailable; do not call it PASS.

Keep the ledger under `.reviewer/` if an artifact is needed. Never include credentials in it. A finding is not complete until its verification field contains a real command, input, and outcome.

## `/fix-mr review <MR_URL>`

Read-only analysis. Do not edit files, commit, push, comment, or reopen.

### Procedure

1. Parse and validate the GitLab URL. Extract host, project path, and MR IID; reject malformed or ambiguous URLs.
2. Capture local context with `terminal`: current branch, worktree status, remotes, target branch, and commits that differ from the target. If the worktree has uncommitted changes, record them and do not overwrite them.
3. Fetch MR metadata and all review discussions with `terminal(command="glab mr view ...")`. Record author, source/target branches, reviewers, approvals, pipeline state, and comment IDs. Resolve usernames from output; never guess mentions.
4. Read the diff and every referenced file. Search each finding's symbol and usages. Check whether the finding is already fixed by the current branch, fixed only in an uncommitted change, still valid, invalid, or manual.
5. Inspect nearby tests and project conventions. For security, data, or public API findings, trace the complete path: request/input → validation → handler/service → persistence/external call → response/event.
6. Run only safe read-only checks needed to classify findings. Do not claim a test passed unless it actually ran.
7. Write or display the ledger and a scope statement: changed files, behavioral versus cosmetic impact, affected API/auth/schema/role surfaces, and whether a full verification pass is warranted.

### Review output

Report every finding, including already-fixed and manual items. Include exact file/symbol evidence, not only a paraphrase. End with one of:

- `READY_FOR_FIX`: at least one `NEEDS_FIX`, no blocker to local editing.
- `NO_CODE_FIX_REQUIRED`: all items are already fixed or invalid, with evidence.
- `MANUAL_GATE`: local work may be complete but external verification remains.
- `BLOCKED`: missing access, ambiguous mandate, or unsafe state.

## `/fix-mr fix <MR_URL>`

Apply only `NEEDS_FIX` findings from a fresh review. Never blindly trust a previous chat summary or stale ledger.

### Procedure

1. Repeat review steps 1–5 and compare the ledger with the current MR discussions. Stop if the MR, source branch, or finding set changed materially.
2. Check scope before editing: count changed files, identify pollution/unrelated commits, and note prior-cycle findings. A scope concern is reported separately; do not hide it by changing unrelated files.
3. Plan each fix as `finding → root cause → minimal change → regression test → verification command`. Prefer existing constants, validators, helpers, repository patterns, and error types. Do not create speculative abstractions.
4. Implement fixes one logical group at a time. For code, preserve contracts and error semantics. For authorization, verify authentication, role, tenant/merchant/organization scope, and sibling filters. For concurrency, test duplicate and simultaneous mutation behavior. For queries, verify projection, distinctness, ordering, pagination, indexes, and actual emitted SQL where relevant.
5. Add regression tests before or alongside the fix. Cover the reported case, the nearest boundary, and an abuse/negative case for security-sensitive behavior. Use deterministic fixtures and initialize dependencies such as loggers explicitly.
6. For migrations, determine whether the migration is deployed/shared from repository history and branch target. Edit only an unmerged migration; otherwise create a new forward migration and test upgrade behavior. Never drop unrelated databases or data.
7. Update every applicable contract artifact for changed behavior: API contract, API draft/spec, role/permission matrix, Swagger/OpenAPI annotations, generated clients, and user-facing documentation. Mark an artifact not applicable only with a concrete reason.
8. Run focused tests first, then the complete project suite. Also run the repository's build, lint, format, static analysis, and vet/type checks when applicable. Run real native integration cases for persistence, authz, integration, or user-facing changes. Use no exit-code masking.
9. For performance-sensitive changes, run the smallest real reproduction first, then the relevant benchmark/load/smoke test. Record latency/throughput inputs, dataset size, environment, and result. Do not invent SLOs; use user- or repository-defined targets, otherwise report measurements without declaring an SLA pass.
10. Run a security pass over changed paths: authn/authz and BOLA/IDOR, injection, validation, secrets, unsafe deserialization, SSRF/file access, rate limits, dependency changes, logging, and error disclosure. Exercise real negative cases where applicable.
11. When a relevant suite first fails, run the same command against the MR target baseline in an isolated worktree. Classify the failure as `BASELINE`, `BRANCH_SPECIFIC`, or `INDETERMINATE`, preserving both exit statuses. Branch-specific failures remain blockers.
12. Review the final diff for accidental files, generated artifacts, secrets, formatting drift, and unmet findings. Commit only after all applicable local gates pass and the ledger is updated.

### Commit rules

Use the repository's commit convention and include the finding IDs or concise fixes. Do not amend or rewrite existing history unless the user explicitly requests it. Before committing, confirm every modified file is intentional. After committing, verify the commit exists and the worktree state; do not push.

### Fix output

Report changed files, finding statuses, exact verification commands and outcomes, commit hash, remaining manual gates, and the literal next step:

`Ready. Run /fix-mr reopen <MR_URL> only when you want to push, post the verified summary, and reopen the MR.`

A failed gate must end as `FIX: BLOCKED` or `FIX: FAIL`, with root cause and the smallest next action. Never report PASS with skipped or unverified mandatory tests.

## `/fix-mr reopen <MR_URL>`

This is an external-write phase. The command itself is the user's request to publish, but it does not waive verification gates.

### Preflight (must pass)

1. Re-read MR metadata, discussions, source/target branches, and pipeline state. Confirm the current branch is the MR source branch and the local HEAD contains the fix commit.
2. Confirm the worktree has no unintended changes, the finding ledger is current, all applicable tests pass, and no unresolved `NEEDS_FIX` or `BLOCKED` item is being represented as fixed.
3. Resolve the actual reviewer and author usernames from fresh `glab` output. Do not guess or use display names as handles. Build one canonical comment body and derive any variants from it.
4. Show the user the final publication summary and ask for exact lowercase confirmation before posting:

```
All external review steps are complete. Type yes to continue with GitLab comments and reopen.
```

Only exact lowercase `yes` authorizes the GitLab writes in this invocation. If not confirmed, stop without side effects.

### Write sequence

Execute strictly in order and stop on the first failure:

1. Push the current source branch. Verify the push result and remote HEAD.
2. Re-read the MR and verify the new commit is present.
3. Post one evidence-based summary comment with the resolved reviewer mention and all finding statuses. Include real tests, security checks, performance results, documentation checks, verification files, and manual follow-ups. Do not include secrets or signatures.
4. Re-read the MR discussions and verify the comment exists with the expected body.
5. Reopen the MR only if it is currently closed and the user requested reopening. If it is already open, record that no reopen was needed.
6. Re-read the MR and verify the final state (`opened`) and source commit. A successful CLI response without state verification is not completion.

Never merge the MR or transition Jira in this skill. Those are separate, explicitly requested workflows. Never close an MR automatically on a failed review.

### Comment template

```
@<resolved_reviewer>

Result Review — <MR_URL>

Branch: <source_branch>
Commit: <verified_commit_sha>

List Of Testing By Reviewer
* QA: <PASS/FAIL/MANUAL> — <command, inputs, and outcome>
* Security: <PASS/FAIL/MANUAL> — <checks and real negative cases>
* Performance: <PASS/FAIL/MANUAL/N/A> — <measurement and environment>
* Contract/docs: <PASS/FAIL/N/A> — <artifacts and reason>

Verification File
* <verified artifact path, or N/A with reason>

Verdict
* <Pass / Fail / Manual Gate>

Need To Be Fix
- <finding ID and file:symbol> — <remaining corrective action>
```

Omit `Need To Be Fix` only when no unresolved findings exist. Do not claim `Pass` if any mandatory test, artifact, or security check is unverified.

## Required Review Matrix

For each applicable category, record `PASS`, `FAIL`, `N/A (reason)`, or `MANUAL` and evidence:

| Category | Minimum checks |
|---|---|
| Functional | happy path, schema/types, status codes, invalid input, boundaries, state transitions |
| Auth and security | invalid/expired auth where relevant, 401/403, RBAC, BOLA/IDOR, injection, sanitization, rate limits |
| Data integrity | transactions, duplicate/idempotent requests, race or double mutation, locking, rollback |
| Performance/reliability | smoke, query/index behavior, latency, throughput, load/stress/soak when risk warrants |
| Integration | timeout/downstream failure, retry behavior, cache consistency, webhook/event duplication |
| Resilience | timeout, backoff, circuit breaking, graceful degradation, error disclosure |
| Documentation | API Contract, API Draft/OpenAPI, Role Matrix, migration/runbook impact |

For each changed endpoint, cover happy path, invalid input (`400`/`422` as appropriate), unauthenticated (`401`), unauthorized/BOLA (`403`), concurrency, latency, and throttling when applicable. Use `N/A` only when the user task makes a category genuinely inapplicable; `UNVERIFIED` is not an acceptable final state.

## Project Pattern Hooks

When applicable, preserve established patterns rather than copying these literally:

- Database constraint errors should map to the project's domain error type at the repository/service boundary.
- Scope helpers such as `IsMerchantScoped()` must be checked with complete fixture state; a row alone does not prove fresh-install permission provisioning.
- When applying one scope filter, clear conflicting sibling filters first so a stale user/organization filter cannot narrow or bypass the intended result.
- Use project pointer helpers for non-zero values instead of `new()` when that is the repository convention.
- For Go projects with a shared local PostgreSQL instance, prefer `go test ./... -p 1 -count=1` when parallel tests share state.

These hooks are reminders to inspect the repository, not permission to invent symbols or APIs.

## Artifacts and Cleanup

Use `.reviewer/` only for temporary ledgers and evidence. Keep it untracked or add it only when the repository explicitly expects review artifacts. Before final reporting, remove scratch files, credentials, dumps, binaries, and temporary databases. Verify cleanup with `terminal`; never delete unrelated project files or databases. If cleanup fails, report `CLEANUP: FAIL` and list exact remaining paths.

## Failure Handling

- Missing `glab` or authentication: stop and report the exact command failure; do not install or authenticate silently.
- Ambiguous MR URL, branch mismatch, dirty worktree, or changed discussions: stop for user direction.
- Missing native dependency/database: report `MANUAL_REQUIRED`; do not substitute a mocked or containerized result.
- Test/build/lint/security/performance failure: classify root cause, preserve evidence, fix or stop. No auto-retry loop.
- GitLab push/comment/reopen failure: stop immediately, verify actual remote/MR state, and do not repeat the write blindly.

## Verification Checklist

- [ ] URL, project, MR IID, source branch, target branch, author, reviewer, and commit SHAs resolved from live output.
- [ ] Every reviewer comment has a ledger row and a justified classification.
- [ ] Scope, pollution, and prior-cycle findings were checked.
- [ ] Changed paths were traced end-to-end and the simplest sound approach was assessed.
- [ ] Functional, security, data-integrity, performance, integration, resilience, and documentation checks were run or marked N/A with a task-based reason.
- [ ] Full applicable test suite, build, lint, and static checks pass; no skipped mandatory case.
- [ ] Baseline comparison was run for the first relevant failure.
- [ ] Final diff contains only intentional changes and no secrets.
- [ ] `fix` did not push; `reopen` alone performed external writes.
- [ ] Human confirmation was exact lowercase `yes` before comment/reopen.
- [ ] Every external write was followed by live state verification.
- [ ] Temporary review artifacts and scratch data were cleaned and verified.
