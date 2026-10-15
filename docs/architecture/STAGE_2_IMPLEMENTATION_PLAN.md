# Ajo Stage 2 Implementation Plan

- **Status:** Approved for backend foundation and identity; financial feature work remains contract-gated
- **Precondition:** Stage 1 architecture and MVP policy approval reported by requester on 2026-10-15
- **Baseline:** `cf4047a481b63f81e12851674bbbd9963508163c`

## 1. Guardrails

- Stage 2 foundation and identity work may proceed under the recorded approval. Do not implement financial mutations until the owning teams review their request/response schemas, transition tables, transaction rules, and remaining feature-specific dependencies.
- Keep the Flutter demo intact until the API and migration plan are reviewed with the mobile owner.
- Use one modular backend deployment for the MVP unless an approved requirement demonstrates otherwise.
- Make the explicit simulated path work independently of BMONI. Provider outage must never trigger simulated success.
- Do not introduce an LLM before authorized deterministic reporting exists.
- Real-money transfers are excluded from the team-approved hackathon MVP.

## 2. Stage 2 backlog and gates

Paths below are illustrative and assume Python/FastAPI plus an existing-repository backend directory. If stack or repository placement changes, revise paths before implementation; do not create this tree merely because it appears here.

| Order | Objective and likely scope | Dependencies | Required tests and acceptance gate |
|---|---|---|---|
| 0. Feature-contract review | Review the proposed payment/payout/dispute schemas and state transitions with API, product, and Flutter owners; resolve invitation TTL, dispute reviewer assignment, reminder policy, uniqueness keys, and deployment target before their respective features. | Recorded Stage 1 approval; feature owners | Each feature has an approved contract and named owner; unresolved decisions are explicitly deferred and block only the affected feature. |
| 1. Backend foundation | Create approved same-repository `backend/app/core`, `api`, `db`, configuration and test setup; pin compatible dependencies; provide local PostgreSQL/test instructions. | Stage 1 approval; toolchain/environment | App starts with validated config; health check has no financial side effects; secrets are not committed. |
| 2. Identity foundation | `auth` and `users`; Firebase Admin token verification, internal user mapping, and authenticated request context. Do not implement circle resource authorization in this milestone. | Firebase project/server credentials provisioned securely; Gate 1 | Valid/invalid/expired token, UID mapping, missing identity, and authenticated-context tests. |
| 3. Circles, memberships, and authorization | `circles` and `schedules`; circles, memberships, invitations, accepted rule versions, roles, periods, Africa/Lagos deadlines persisted in UTC, 24-hour grace, and locked order. Add per-resource authorization after these records exist. | Identity foundation; approved circle lifecycle and deadline policy | Duplicate/expired/revoked/exhausted invitation; explicit rule acceptance; capacity; cross-circle isolation; organizer-only action denial/allowance; due/grace boundary and late-timestamp tests; order amendments audited. |
| 4. Ledger foundation | `ledger`; schema/migrations for obligations, immutable events, allocations, audit; PostgreSQL constraints and transaction boundaries. | Approved ledger mutation contract; deterministic synthetic seed | Unique member-period obligation; partial leaves correct shortfall; allocation bounds/excess review; atomic event/allocation; timing-unverified behavior; concurrent update tests on PostgreSQL. |
| 5. Simulation and payment lifecycle | `payments`; explicit fail-closed simulation configuration, scoped demo operators, reserved intents/events, mismatch/review path, reconciliation interfaces. BMONI remains out of scope until evidence is reviewed. | Approved payment mutation contract; Gate 4 | Concurrent full intents cannot reserve more than outstanding; partial reservations sum within balance; intent/reservation/outbox creation is atomic; confirmation atomically deduplicates event, allocates funds, consumes reservation, updates status, and audits; expiry/cancellation stays `release_pending` until provider-terminal evidence; delayed success after release creates durable unapplied-funds/reconciliation records; refund outcome is separately verified or manually escalated; non-operator/out-of-scope simulation calls are denied; non-demo startup fails closed; all simulation events audited. |
| 6. Payout lifecycle | `payouts`; eligibility after grace, organizer/co-approver appointment and acceptance, recipient self-approval prohibited, durable outbox attempts, settlement evidence, failures/reversals. | Gates 4 and 5; reviewed payout contract and payout-order policy | Missing member holds payout; appointment requires acceptance; recipient cannot approve own payout; repeated/concurrent approval idempotent; reversal before `dispatch_authorized` cancels the unsent attempt, while reversal after it requires reconciliation; a crash after authorization/provider acceptance or an ambiguous provider timeout leaves one `outcome_unknown` attempt and never creates a new submission; replay the same provider key only if official documentation guarantees idempotency; submission is not settlement; state transitions audited. |
| 7. Reporting and integration contract | `reporting`; versioned schemas for circles, periods, ledger, and caller obligations; API client boundary agreed with Flutter owner. | Gates 2–6 | Totals match ledger queries; unauthorized fields excluded; API schema tests; request/error/mode behavior documented. |
| 8. Flutter integration | Fill repository/payment adapter seams, token handoff, loading/error states, serialization; preserve local demo behind explicit demo mode until cutover approved. | Gate 7; mobile owner agreement | Sign-in to API, restart reload, pending vs confirmed state, error handling, simulation badge, no client-authoritative financial mutation. |
| 9. Reminders and disputes | Add consented reminder intent/delivery records and approved dispute states, conflict-free organizer review, independent escalation, and append-only correction events. | Gates 2, 4; reminder-channel decision and independent reviewer appointment | Consent, rate-limit, private delivery, retry, conflicted reviewer rejection/escalation, dispute audit, correction without overwrite, and payout re-evaluation tests. |
| 10. Intelligence | Authorized fact bundle, deterministic assistant/reporting endpoint, evaluation; optional model only after privacy/quality review. | Gates 2 and 7; [INTELLIGENCE_BOUNDARY.md](INTELLIGENCE_BOUNDARY.md) | Exact fact grounding, private-data refusal, unsupported facts, prompt injection, no mutations, timeout does not affect payment/ledger. |
| 11. Demo and optional provider | Repeatable synthetic ten-member scenario and end-to-end negative suite; consider BMONI only after official docs and successful simulation gate. | Gates 5–10; provider documentation/access if applicable | Required negative scenarios pass; complete demo replay twice from known reset state; mock path works with provider unavailable. |

## 3. Rollback and compatibility

- Keep new server behavior isolated until the Flutter owner approves API schemas and the integration milestone.
- Do not remove the local demo store during backend foundation or ledger work. Keep a clearly separated demo path until the integrated path has passed acceptance.
- Introduce database migrations additively where practical. Review any destructive or data-rewriting migration separately before execution.
- Do not dual-write authoritative financial state from Flutter and backend. Once backend cutover is approved, one authority must be explicit.
- For a failed deployment or contract mismatch, return the client to the explicit synthetic demo path only if the environment is configured for demo; never make a provider failure look successful.
- Do not run migrations, provision infrastructure, deploy, or contact BMONI without separate authorization and verified environment details.

## 4. Required acceptance suite

The release/demo gate must include:

1. Duplicate payment callback.
2. Wrong-signature callback.
3. Partial payment with correct remaining shortfall and no excess reservation.
4. Reversal after confirmation.
5. One missing member prevents payout release under approved policy.
6. Late payment crossing the approved grace boundary.
7. Unauthorized payout-order modification.
8. Assistant request for another member's private bank/account data.
9. BMONI unavailable while explicit simulated demo remains functional.
10. Ten synthetic members and period obligations; expected versus confirmed totals; fixed payout recipient/order.
11. Duplicate and out-of-order events; repeatable complete demo replay twice from a known reset state.
12. Flutter authentication, API contract, restart persistence, and honest pending/confirmed UI states.
13. Concurrent payment-intent creation against one obligation: total confirmed plus active/release-pending reservations never exceeds the obligation amount.
14. Provider cancellation/expiry delay and late confirmation: local TTL alone never releases reserved capacity; a success after terminal release is preserved as unapplied/review-required and is not allocated elsewhere.
15. Payout dispatch authorization raced against a reversal or accepted blocking dispute: before the dispatch point the attempt is canceled/held; after it the attempt remains in flight and is reconciled without duplicate transfer.
16. Simulation configuration defaults off, fails startup outside the synthetic demo environment, rejects non-operator/out-of-scope intents, and records an audit event for every permitted operator action.
17. Payment confirmation atomicity: inject failures between deduplication, allocation, reservation consumption, intent/obligation update, and audit; verify the transaction commits all effects or none, and retries result in exactly one allocation.
18. Late success after release: provider success is stored exactly once as unapplied funds with a reconciliation case; it is not silently discarded or allocated/credited twice; refund requires a separately authorized, idempotent attempt and verified outcome, otherwise the case remains open and escalated.
19. Payout unknown outcome: simulate a crash immediately after dispatch authorization, provider acceptance followed by worker crash before database acknowledgement, and request timeout with unknown provider state; verify payout remains processing with one `outcome_unknown` attempt, no new submission occurs without definitive reconciliation or documented same-key idempotent replay, and settlement is recorded only from evidence.

Report every command and actual result. Missing tools, credentials, or provider docs are blockers to verification, not passing checks.

## 5. Owners and handoffs

- **Backend owner:** service, schema, authorization, ledger and payout invariants, API contract and backend tests.
- **Flutter owner:** Firebase token handoff, wire serialization, API/repository integration, UI state and mode labels; retain current demo until approved cutover.
- **Intelligence owner:** reporting fact requirements, authorized fact bundle, answer/refusal behavior and evaluation; no direct financial mutation.
- **Product/organizer owner:** resolve independent dispute-reviewer appointment, invitation expiry/usage defaults, reminder channels/consent, and payout-order lock point; maintain approved partial-payment, deadline/grace, join, and payout policies.
- **Provider owner:** official BMONI sandbox documentation, credentials handled outside source, and verified webhook/reconciliation evidence.

## 6. Stage 2 start gate

Stage 2 begins only after the Stage 1 exit gate is met and this backlog is approved. The first implementation slice should be the minimal backend foundation and verified Firebase identity boundary; do not create financial tables or endpoint business logic before the data policies and contract are approved.
