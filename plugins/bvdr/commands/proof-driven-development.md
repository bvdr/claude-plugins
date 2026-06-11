---
description: A disciplined workflow for ambiguous, high-stakes tasks — assess, post proof-tagged assumptions, lock a testable goal, plan as TDD, build via subagents with two-stage review, prove with a live end-to-end run, and flag gaps honestly. Use when starting a vague ticket or a feature that touches auth, identity, money, or data integrity; when the user says "do an assessment", "list assumptions with proof", "set a goal/criteria", "prove it works", or "reproduce that way of working".
---

# Proof-Driven Development

A repeatable shape for turning a vague, high-blast-radius request into shipped, proven work.
Core stance: **never assert without evidence, never decide without the user, never claim done without proof.**

## When to use (calibrate first)

Trigger = **ambiguity × blast-radius**. Run the full weight only when the ask is underspecified
AND touches auth, identity, money, data integrity, or multiple systems. For a localized,
well-specified change, skip to Phase 6 (change + verify). Don't ceremony-tax a typo fix.

Announce the shape, then work the phases in order.

## Phase 1 — Ground in reality

Read the actual code, ticket, and prior memory before theorizing. Dispatch parallel `Explore`
agents for breadth. Pull the ticket/source of truth directly (API, not assumptions). Output a
short assessment that states the *central challenge* and the *blast radius* — not a feature summary.

## Phase 2 — Proof-tagged assumptions (the highest-leverage step)

Post assumptions split into **task-related / logic / codebase**, as a table:

```
# | assumption | TRUE / TBD | note (proof or default)
```

- Tag each `TRUE` only with proof: a `file:line`, a query result, or a ticket fact.
- Tag genuine product choices `TBD` with a recommended default in the note.
- Resolve the `TBD` rows with the user via `AskUserQuestion` — verify facts yourself, escalate
  only decisions. This isolates the few real choices from the many things you can just check.

## Phase 3 — Lock a testable GOAL

Convert the confirmed assumptions into a **definition of done = pass/fail criteria, each paired
with how it will be PROVEN** (which automated test, live check, or artifact). Number them. Get
explicit sign-off ("lock the goal"). Treat later scope additions as *new* goals, not edits to
the locked one.

## Phase 4 — Plan as TDD

Write an implementation plan of bite-sized tasks with **real code, no placeholders** (use
`superpowers:writing-plans` if available). Each task: failing test → minimal code → green →
commit. Map every goal criterion to a task before starting.

## Phase 5 — Build via subagents, two-stage review

Execute with `superpowers:subagent-driven-development` (or one fresh subagent per task). Per task:
1. **Implement** (TDD).
2. **Spec-compliance review** — "did it build the right thing, nothing more/less?"
3. **Code-quality review** — "is it well-built?" (only after spec review passes).
4. Apply fixes, then commit. One atomic commit per task.

Keep the user's working tree clean: feature branch off the base; never commit their unrelated WIP.

## Phase 6 — Prove in layers (the part that finds real bugs)

1. **Unit/feature tests** prove the logic.
2. **One live end-to-end run against the real stack** proves your assumptions about the world —
   this is where integration/config/environment bugs surface that unit tests never see.
3. **Front-load the environment**: before the E2E, sanity-check the basics (can it log in? can it
   send mail? are migrations applied? is test data seeded?). Most E2E thrash is a flaky stack, not
   the feature.
4. Capture human-facing proof: screenshots, a captioned demo recording, an architecture diagram.

**When something fails: instrument to root cause before editing.** Capture console/network logs,
query the DB, curl the endpoint. Diagnosis-by-evidence converges; diagnosis-by-guessing oscillates.
Confirm the diagnosis *before* changing production code — a wrong theory edits the wrong file.
Prefer root-cause fixes that improve the product (e.g. make an endpoint idempotent) over test hacks.

## Phase 7 — Finish honestly

End with three explicit lists, evidence attached:
- **Verified ✅** — what passed, with the command/output.
- **Flagged ⚠️** — what's partial, not-done, or environment-only, *with proof* (e.g. "0 rows in
  ClickHouse" beats "analytics might not be wired"). No silent gaps.
- **Not touched** — the user's WIP, out-of-scope items.

Then commit sequentially and open a draft PR with the proof attached (diagram/screenshots inline,
videos linked). For multi-repo work, open one PR per repo and cross-link them.

## Guardrails (lessons that cost time when ignored)

- "Flaky-but-green" is a yellow flag, not green — name the flakiness and its cause.
- Verified-and-flagged beats assumed-and-green. Run the command; quote the output.
- A diagnosis you didn't instrument is a guess. Don't edit production code on a guess.
- Scope creep is silent — re-lock the goal when the ask grows.

## Kickoff prompt (hand this to the user to reuse)

```
We're working on: <task / ticket link>.
1. Assess it grounded in the actual codebase/ticket — don't guess.
2. Post assumptions split into task / logic / codebase, as a table:
   # | assumption | TRUE/TBD | note. Back every TRUE with proof (file:line or a fact).
   Flag TBDs for me to decide — don't assume product choices.
3. After I confirm, lock a GOAL: pass/fail criteria AND how you'll PROVE each.
4. Turn it into a TDD plan (real code, no placeholders).
5. Build subagent-driven: implement → "right thing?" → "well-built?" → fix → commit.
   Feature branch off <base>.
6. Prove in layers: unit tests, then ONE live end-to-end run. Instrument failures to
   root cause before editing.
7. Finish with: verified ✅ / flagged ⚠️ (with evidence) / not-touched. Then draft PR with proof.
```
