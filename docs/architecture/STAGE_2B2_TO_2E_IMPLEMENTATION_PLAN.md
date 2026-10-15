# Ajo Backend: Stage 2B.2 Through 2E Implementation Plan

- **Status:** Draft for review
- **Baseline:** Stage 2B.1 PostgreSQL verification, commit `a570c19`
- **Verified environment:** PostgreSQL 17.10; backend suite 19 passed; Alembic revision `20261015_0002`
- **Scope:** Membership lifecycle through contribution schedules, ledger, payment orchestration, and payout controls

## 1. Purpose and guardrails

Plan the full backend programme once, then implement it as independently reviewable milestones and commits. The backend and PostgreSQL remain authoritative for identity mapping, membership, schedules, obligations, confirmed money, ledger, and payouts. AI may explain authorized backend results; it cannot establish payment, alter balances, select payout order, or release a payout.

- Keep Firebase identity verification and persisted, server-side authorization as the only source of caller identity and circle permissions.
- Keep all monetary values in integer kobo and all persisted instants in UTC. Interpret configured schedule times in `Africa/Lagos`.
- Use PostgreSQL constraints and transactions for invariants that can race. SQLite remains useful for fast tests, not as evidence for concurrency or migration gates.
- Preserve the Flutter demo until its API contract and cutover are separately approved.
- Keep simulation explicit, synthetic, and disabled by default. Provider failure must never result in simulated success.
- Do not call BMONI, deploy, or enable real-money collection or payouts under this plan. Provider work requires official documentation and separate authorization; real-money transfers are outside the approved hackathon MVP.
- Do not amend completed checkpoint commits without an evidence-backed correction.

## 2. Baseline and policy authority

The current implementation has Firebase token verification, internal user mapping, session membership summaries, circle-scoped reads, active-membership checks, organizer role checks, and PostgreSQL migration/concurrency coverage. The membership table has one row per `(circle_id, user_id)` and status values `active`, `inactive`, and `revoked`. It does not yet persist invitations, accepted rule versions, or membership audit history.

The Stage 2B.1 checkpoint establishes only the behaviors exercised by its tests. It does not certify future financial workflows.

Policy sources, in order of authority:

1. [`STAGE_1_ARCHITECTURE_DECISIONS.md`](STAGE_1_ARCHITECTURE_DECISIONS.md): approved architecture and reported MVP policy; also lists feature-specific open decisions.
2. [`FINANCIAL_INVARIANTS.md`](FINANCIAL_INVARIANTS.md): approved financial policy baseline; implementation details and several schema decisions remain gated.
3. [`API_CONTRACT_V1.md`](API_CONTRACT_V1.md): explicitly a draft/proposal. Route shapes and transition details require owning-team review before implementation.
4. [`STAGE_2_IMPLEMENTATION_PLAN.md`](STAGE_2_IMPLEMENTATION_PLAN.md): stage gates, ownership, compatibility, and verification requirements.

Do not upgrade a proposal in the API contract into an approved product decision by implementing it. Where a policy is open, record the decision and owner before coding the dependent behavior.

## 3. Programme sequence

| Milestone | Scope | Required exit gate |
|---|---|---|
| 2B.2 | Invitations, rule acceptance, membership activation/revocation, audit | Approved lifecycle policy; authorization and invitation concurrency tests pass on PostgreSQL |
| 2C | Circle lifecycle, contribution schedule, periods, eligible-member snapshots, payout-order policy | Approved transition/order rules; time boundaries, idempotent generation, and authorization pass on PostgreSQL |
| 2D | Obligations, allocations, append-only ledger events, reversals, reconciliation | Financial invariants reconcile; concurrency and injected transaction failures pass on PostgreSQL without a live provider |
| 2E.1 | Payment intents, reservations, idempotency, explicit simulation, provider-event reconciliation boundary | Retry, concurrency, late-event, and failure behavior pass; real provider remains disabled |
| 2E.2 | Payout eligibility, approvals, holds, durable dispatch, settlement/reconciliation | Approval, reversal races, outbox durability, and unknown outcomes pass; real payouts remain disabled |
| Final gate | Integrated negative scenarios, full tests, migrations, and documentation | All relevant PostgreSQL, failure-injection, static, and compatibility gates pass |

Each milestone may be split into smaller commits. Prefer a migration/model commit, domain behavior commit, and focused test commit when that separation improves review. Do not combine unrelated stages to reduce commit count.

## 4. Stage 2B.2: Membership and invitation lifecycle

The detailed accepted policy is recorded in [`STAGE_2B2_MEMBERSHIP_DECISIONS.md`](STAGE_2B2_MEMBERSHIP_DECISIONS.md). The criteria below summarize that decision; implementation must not replace it with guessed defaults.

### Approved criteria

- Joining is invitation-only; public joining is not introduced.
- A verified Firebase identity maps to the internal user. Never trust a request-supplied user ID, role, or organizer flag.
- A valid invitation permits immediate admission after authentication, explicit acceptance of the current circle-rules version, and backend validation; a second organizer approval is not required.
- Invitation TTL is 7 days from creation; invitations are single-use by default. Explicit multi-use invitations use a configured maximum. Expiry is exclusive at `expires_at`; consume use only on committed acceptance.
- Every circle has a configured positive `max_members`; missing/null is invalid, never unlimited. Active members count toward capacity; pending invitations do not. PostgreSQL serializes acceptance and capacity changes.
- Validate invitation-circle association, validity, expiry, revocation, usage, capacity, duplicate membership, and current rules version on the server.
- Preserve one stable membership row per user/circle and append-only lifecycle events for distinct tenures. Rejoin requires a fresh invitation and rules acceptance; returning members default to `member`, never inherited `organizer`.
- Active organizers may revoke other members with a non-empty bounded reason. Members may leave their own circle with an optional reason. Every transition and its audit event are atomic; the final active organizer is protected until an eligible successor is explicitly promoted or the circle is formally closed.
- Membership and invitation-use changes commit atomically. Concurrent accepts cannot exceed the approved usage or capacity limit or create duplicate memberships.
- Every protected request checks current persisted active membership. A revoked/inactive member loses access on the next request and receives the existing non-disclosing response.
- Revocation does not delete financial history or audit evidence, settle obligations, or erase pending financial state.
- Never log raw invitation secrets or return them from list/inspection endpoints.

### Acceptance tests

- Reject invalid, expired, revoked, exhausted, wrong-circle, rules-version-mismatched, and duplicate invitations.
- Require explicit rule acceptance and derive the joining user only from verified identity.
- Race accepts for the final invitation use and final capacity slot; enforce the limit exactly once on PostgreSQL.
- Deny invitation creation/revocation to callers without the approved authority; audit privileged actions.
- Verify revocation immediately blocks circle reads and does not erase membership history or financial records.
- Exercise self-leave, organizer revocation, explicit rejoining after leave/revocation, role non-restoration, and concurrent final-organizer protection.

### Remaining release gates before invitation acceptance

- The revised proposed draft is [`CIRCLE_RULES.md`](CIRCLE_RULES.md), with proposed ID `ajo-circle-rules-1.0.0`; neither text nor ID is approved. Explicitly appoint a project-level publisher and independent reviewer, identify approved privacy/data-retention documents, and record governance approval. Do not create an immutable published copy, seed a runtime value, or enable acceptance before approval is recorded.
- Rules updates are classified by the authorized publisher as material or non-material. New members always accept the current version; material changes require reacceptance for recorded affected actions; non-material changes do not. Reacceptance pending preserves read-only access to rules, own financial history, and relevant disputes/reconciliation; existing financial state is not changed.
- Confirm final route and error semantics with API/mobile owners before declaring the proposed API contract implemented.

Invitation TTL/usage, mandatory capacity, membership authority, self-leave, organizer continuity, stable membership identity, rejoin, and audit policy are decided in [`STAGE_2B2_MEMBERSHIP_DECISIONS.md`](STAGE_2B2_MEMBERSHIP_DECISIONS.md). Membership implementation may proceed with invitation acceptance disabled or failing closed until the rules-content gate is resolved.

## 5. Stage 2C: Circle lifecycle and schedules

### Scope

Define and persist an explicit circle state machine; controlled configuration and activation; contribution schedule versions; period generation; eligible-member snapshots; due instants and grace deadlines; and payout-order policy. Keep transition rules in domain logic, not arbitrary status-update routes.

### Acceptance criteria

- Product approves the legal circle transitions, pause/abort behavior, readiness rules, and transition actors before implementation.
- Persist schedule local-time policy and derived UTC due/grace instants. Apply the approved 24-hour grace policy; exactly at the grace deadline is within grace.
- Generate periods and one obligation per eligible member deterministically and idempotently; database uniqueness prevents duplicates.
- Snapshot which memberships are eligible for each period. Later membership changes do not silently rewrite existing obligations.
- Resolve payout-order lock point and audited amendment rules before allowing order changes.
- PostgreSQL tests cover transition rejection, schedule boundaries, duplicate generation, membership changes, and concurrent generation.

## 6. Stage 2D: Ledger and contribution obligations

### Scope

Implement contribution obligations, explicit-obligation allocations, immutable financial events, linked correction/reversal events, derived balances, and reconciliation cases. Keep payment-provider operations out of this milestone.

### Approved financial criteria

- Use integer kobo; a payment intent is not a ledger entry and a UI/provider callback alone is not proof of settlement.
- Only verified evidence or a separately authorized synthetic simulation event may increase confirmed contributions.
- Partial payments are supported. Credit only verified amounts to the explicit obligation; the remainder stays outstanding and does not make the payout eligible.
- Do not allocate across obligations. An event above its intent is held for review. Excess caused by a concurrent reduction in outstanding amount is recorded as unapplied/review-required; do not auto-carry or refund it.
- Use a trustworthy provider success timestamp for on-time/late classification. Verified amount with untrusted/missing time may be credited as timing-unverified, but cannot be classified as timely or late.
- Preserve original history. Corrections and reversals are new linked records; ambiguous or inconsistent outcomes remain visible for reconciliation.

### Acceptance criteria

- Enforce unique obligations and allocation bounds in PostgreSQL, not only in service validation.
- Concurrent allocations cannot exceed an obligation; transaction failure leaves no partial event/allocation/audit result.
- Duplicate evidence cannot create duplicate ledger effects. Reversal preserves original records and is itself idempotent.
- Test partials, concurrent allocations, excess/unapplied value, late or timing-unverified events, reversal, and reconciliation outcomes.
- Reconcile obligation totals, allocations, ledger entries, reversals, and outstanding amounts from authoritative records.

## 7. Stage 2E.1: Payment orchestration

### Scope

Add provider-neutral payment intent and reservation handling, persistent idempotency, event normalization, and reconciliation boundaries. Keep provider-specific behavior in an adapter. Implement only the approved synthetic simulation path until provider documentation is reviewed.

### Acceptance criteria

- In one transaction create the intent, reservation, audit evidence, and any provider outbox command.
- Available amount equals expected less confirmed allocations and both active and release-pending reservations. Concurrent intents cannot over-reserve.
- Confirmation atomically deduplicates the provider event, validates it against persisted intent data, allocates funds, updates states, and records audit evidence.
- Duplicate, stale, conflicting, invalid-signature, mismatched, and out-of-order events cannot duplicate or silently alter financial effects.
- A late success after reservation release is retained as unapplied funds with a reconciliation case; never drop, double-credit, auto-carry, or automatically refund it.
- Provider timeout/unknown outcomes remain unresolved. Simulation stays disabled by default, explicitly labelled, scoped to synthetic data and authorized operators, and never activates as provider fallback.
- Do not implement BMONI requests or signature assumptions without official documentation and separate authorization.

## 8. Stage 2E.2: Payout authorization and dispatch

### Scope

Implement authoritative eligibility, approval and co-approver acceptance, holds, durable outbox dispatch, settlement evidence, and reconciliation for uncertain provider outcomes.

### Approved criteria and release gates

- Recompute eligibility transactionally at approval and immediately before dispatch; missing required contributions or unresolved blocking review keeps the payout held/ineligible.
- Organizer cannot approve a payout where they are the recipient. A non-recipient active co-approver must be appointed and accept. Appointment changes are locked while an affected payout is awaiting approval or processing.
- Payout order is immutable after its product-approved lock point; that point and amendment procedure are still open decisions.
- Commit approval, unique unresolved attempt, stable reference, and outbox command atomically. Call the provider outside the database transaction.
- Reversal/dispute before dispatch authorization cancels the unsent attempt; after authorization, treat the provider operation as in flight and reconcile it.
- A worker crash or timeout after dispatch authorization leaves one unresolved `outcome_unknown` attempt. Never blindly create or submit a second transfer; replay the same provider key only with documented provider idempotency guarantees.
- Only verified settlement evidence can mark a real payout settled. Simulation is explicitly synthetic. No real payout execution is enabled by this plan.
- PostgreSQL failure-injection tests cover approval races, reversals, worker crashes, ambiguous outcomes, retry safety, and audit completeness.

## 9. Cross-stage verification and commit gates

For each implementation slice:

1. Confirm a clean worktree, expected branch, and known starting commit.
2. Read the owning contract, decision, models, routes, migrations, and nearby tests.
3. Implement the smallest coherent unit; add migrations and focused PostgreSQL tests for schema or concurrency behavior.
4. Run focused tests, the relevant PostgreSQL gate, the full backend suite, Ruff lint/format, compilation/import checks, Alembic history/upgrade checks, and `git diff --check` as applicable.
5. Review scope and secrets; commit only intended files with a milestone-scoped message.
6. Report commit, test results, PostgreSQL version/revision, skipped checks, blockers, and worktree state. Do not push or deploy without separate authorization.

The final negative suite must include invitation expiry/revocation/concurrency, revoked-member access, reservation/ledger concurrency, duplicate payment events, invalid provider evidence, partial payments, reversal, missing-contribution payout hold, payout-order authorization, recipient self-approval, dispute conflict, uncertain dispatch, simulation isolation, and unauthorized AI-data access. Use PostgreSQL for database-backed concurrency and transaction claims.

## 10. Open decisions and owners

Resolve these with the product/API owners before implementing the dependent feature; do not invent defaults:

| Decision | Blocks |
|---|---|
| Initial immutable circle-rules document/version and authorized publishing workflow | 2B.2 invitation acceptance and circle activation |
| Whether rules updates require existing members to reaccept, and which actions require it | Rules update workflow and protected actions |
| Circle lifecycle transitions and readiness requirements | 2C activation/pause/abort |
| Payout-order lock point and amendment procedure | 2C schedule/order; 2E.2 payout |
| Revised-schedule and payout uniqueness keys | 2C/2D schema freeze |
| Independent dispute-reviewer assignment and refund escalation | Disputed payout/reversal operations |
| Official BMONI capabilities and webhook/idempotency contract | Any live provider integration |
| Deployment target and production secret/monitoring controls | Deployment only; does not block local domain work |

## 11. Completion criteria

Stages 2B.2 through 2E are complete only when membership is enforceable and auditable; circle schedules and obligations are deterministic; ledger/allocation totals reconcile; payment events are idempotent and safely reconciled; payout approval and dispatch survive races and uncertain outcomes; required PostgreSQL and failure-injection tests pass; and remaining policy/provider limitations are explicit. Real-money collection and payout remain disabled unless separately approved after provider and operational gates.