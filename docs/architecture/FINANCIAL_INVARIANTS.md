# Ajo Financial Invariants (Approved Policy Baseline)

- **Status:** Team-approved MVP policy baseline; implementation details remain gated for contract review
- **Authority proposal:** Backend domain services plus PostgreSQL transactions and constraints
- **Implementation status:** Not implemented by these documents

## 1. Purpose

These invariants define conditions a Stage 2+ implementation must preserve across retries, concurrency, provider failure, and audit. The deadline, partial-payment, payout approval, join, dispute, timestamp-unavailable, and overpayment policy baseline was approved by the team as reported by the requester on 2026-10-15. The API mutation schemas still require owning-team review before those mutations are implemented.

## 2. Identity and relational integrity

1. Every financial record references persisted circle, period, member, and user records with foreign keys.
2. There is at most one obligation for `(circle_id, period_id, member_id)`.
3. There is at most one payout record for the approved payout unit (one per circle/period); schedule revision/version keying must be resolved before migration design.
4. Provider event identifiers are unique within the provider/account namespace.
5. Idempotency keys are unique within an explicitly defined actor/operation scope and have a durable result or replay-safe response.
6. API IDs cannot be used to bypass membership and role authorization.

## 3. Payment and ledger integrity

7. Payment submission or intent creation is not payment confirmation.
8. Only verified provider evidence, or a deliberately authorized simulated event in an explicitly configured synthetic-demo environment, may increase confirmed contribution totals.
9. Pending, failed, canceled, duplicate, or financially unverified/mismatched events do not increase confirmed balances. A verified successful amount with only an untrusted/missing transaction timestamp is credited and separately marked `timingUnverified`; it is not classified as on-time or late.
10. Before applying an event, validate its provider/account, reference, currency, amount, intended member, intended circle/period/obligation, and allowed provider status against persisted intent data.
11. Duplicate callbacks and idempotent retries cannot create a second event effect or allocation.
12. Concurrent callbacks and user operations cannot over-allocate an obligation or apply an invalid state transition.
13. Each confirmed contribution and allocation is traceable to immutable evidence. Correcting history adds a new correction/reversal event; it does not overwrite the original event.
14. Confirmed totals reconcile to the append-only contribution and reversal/allocation records under the accounting policy approved by product.
15. Amounts are integer kobo. Provider amount units must be normalized and checked explicitly at the adapter boundary.
16. Mismatches or ambiguous provider outcomes enter a review/reconciliation path; they never silently become success.

## 4. Obligation and schedule integrity

17. An obligation has a deterministic relationship to its circle, period, member, amount, and due instant.
18. Obligation status is derived from authoritative events, allocations, the approved deadline/grace policy, and dispute/review state. Clients cannot set it directly.
19. Allocated `confirmedKobo` cannot exceed the obligation amount. A verified event that matches its intent but exceeds the remaining amount after a concurrent payment is allocated only up to the locked remainder; excess is recorded as unapplied and reviewed, never carried forward or refunded automatically.
20. Outstanding amount is derived as expected amount less valid confirmed allocations, subject to any approved reversal/adjustment model.
21. Payment timing uses the provider's verified transaction-success timestamp. Do not substitute client time, initiation time, or webhook arrival. If amount and success are verified but transaction time is not, credit the amount with `timingUnverified`; do not classify on-time/late, and defer any lateness-dependent decision until reconciliation.
22. Use `Africa/Lagos` for schedule dates and explicit due times, persist instants in UTC, and set a 24-hour grace deadline. Exactly at the grace deadline is within grace; a payment after it is late and an unpaid obligation becomes overdue after it.
23. Permit partial payments. Credit only verified confirmed amounts to the explicitly identified obligation; leave the remainder outstanding and do not count it as fully funded for payout eligibility. An intent amount cannot exceed current outstanding amount.
24. Cross-obligation allocation is prohibited. An event exceeding its intent is held wholly for review. If a matching verified event exceeds the remaining obligation due to a concurrent allocation, cap the allocation at the locked remainder and record the excess as unapplied for review. Do not infer on-time/late when timing is unverified.

## 5. Payout integrity

25. Payout eligibility is computed from authoritative, confirmed allocations and approved release conditions.
26. A missing required contribution keeps payout ineligible; the system may evaluate a hold after the approved grace deadline. A partial contribution does not satisfy a full contribution requirement.
27. The payout recipient and order are locked at a lifecycle point approved by product. Changes require authorized, auditable amendments; reliability indicators and assistant output cannot change the order.
28. Only the organizer may approve, and not when they are the recipient. The organizer appoints one active non-recipient member as co-approver; the member must accept. Appointment changes are locked while an affected payout is awaiting approval or processing.
29. Repeated or concurrent approvals cannot initiate duplicate payout effects.
30. A submitted provider request is not settlement proof. `settled` requires approved settlement evidence; simulated settlement must remain explicitly synthetic.
31. Failed, reversed, held, and review-required payout outcomes must be represented without erasing prior events.
32. A payout cannot move to settled while required release conditions remain unsatisfied.

## 6. Transaction and audit integrity

33. A financial state change, its event/allocation records, idempotency result, and corresponding audit evidence commit atomically where they share a database transaction.
34. Use database uniqueness, foreign keys, checks, and transaction isolation/locking for race-sensitive rules; application validation alone is insufficient.
35. Audit records identify actor, action, target, time, and safe before/after evidence for sensitive changes. Do not log bearer tokens, secrets, or unnecessary private payment data.
36. Historical financial events are append-only. Administrative correction is a new auditable event with a reason and actor.
37. Reconciliation is repeatable and idempotent; unresolved differences remain visible for review rather than being silently overwritten.

## 7. Operating modes

### Simulation

- Must be explicitly configured and limited to synthetic demo identities/data.
- Must be visibly labelled as simulated/no real money in API and UI.
- Uses deterministic, auditable events that exercise the same ledger rules as provider-confirmed events where appropriate.
- A provider outage must not activate simulation implicitly.
- Demo controls must not be exposed in a production-configured environment.

### BMONI sandbox

- Remains conditional until official documentation establishes authentication, amount units, supported collection/payout flows, statuses, reference/event guarantees, signature verification, retries, and reconciliation behavior.
- Secrets stay server-side.
- An undocumented response or unavailable provider cannot confirm payment or settle payout.

## 8. State-transition contract

Proposed contribution states: `upcoming`, `awaiting_payment`, `partially_paid`, `paid`, `overdue`, `under_review`.

Proposed payout states: `scheduled`, `eligible`, `awaiting_approval`, `processing`, `settled`, `held`, `failed`, `reversed`.

The API contract contains the proposed permitted transitions, actors, and evidence for payment intents, obligations, payouts, and disputes. The API owners must review those tables before implementing a financial mutation. `held` is the single payout hold status; `on_hold` is not a separate enum. Database transaction boundaries, event evidence, idempotency, and rejection behavior remain required implementation details.

The approved dispute policy uses states `open`, `under_review`, `accepted`, `rejected`, and `escalated`. A non-conflicted organizer may review and resolve; an organizer who is a party or payout beneficiary must not review that dispute. An independent authorized reviewer is required, and reviewer assignment remains open. Accepted disputes create linked append-only correction/reversal events with reviewer, reason, timestamp, and evidence references. An internal correction is not evidence of a provider refund. A dispute that could affect payout correctness holds the affected payout until eligibility is re-evaluated.

## 9. Decisions that block schema/rule freeze

- Cross-obligation allocation, overpayment, and unverifiable-timestamp handling.
- Circle/period/payout uniqueness keys, especially for multiple circles and schedule revisions.
- Appointment rules for an independent dispute reviewer when the organizer is conflicted.
- Payout-order lock point and audited amendment policy.
- Invitation expiry and usage-limit defaults.
- Reminder channels and consent.
- Dispute correction record schema and reviewer authority provisioning.
- Provider capabilities and webhook guarantees, if BMONI is in scope.

The policy baseline is team-approved as reported by the requester on 2026-10-15. Independent dispute-reviewer assignment, invitation TTL/usage defaults, reminder consent/channels, uniqueness keys for revised schedules, and provider-specific guarantees remain feature-specific open decisions.

## 10. Required invariant tests

At minimum, later implementation must test duplicate provider events; repeated idempotency key; wrong signature; amount/currency/reference/member mismatch; partial-payment shortfall; reversal; out-of-order event; concurrent callback; missing member/payout hold after grace; payment before due, exactly at due, during grace, exactly at grace deadline, and after grace; delayed webhook arrival; missing/untrustworthy provider transaction time; unauthorized/self payout approval; unauthorized payout-order modification; settlement without release evidence; dispute correction without history overwrite; and reconciliation after provider timeout. PostgreSQL-backed tests are required for uniqueness, concurrency, and transaction guarantees.
