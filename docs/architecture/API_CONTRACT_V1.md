# Ajo API Contract v1 (Draft)

- **Status:** Draft contract; identity, circle-read, and membership lifecycle routes have backend implementations, while remaining endpoints are proposals pending API/mobile review
- **Depends on:** Approval of `STAGE_1_ARCHITECTURE_DECISIONS.md`
- **Audience:** Backend, Flutter, intelligence, and QA owners

## 1. Contract rules

- Prefix proposed API paths with `/v1`.
- Use JSON and stable opaque identifiers.
- Authenticate with `Authorization: Bearer <Firebase ID token>`; verify the token on every protected request.
- Derive caller identity and permissions from verified token plus persisted records. Never authorize based on a body-supplied `userId`, `memberId`, role, or `isOrganizer` flag.
- Represent money as integer kobo. Reject fractional or floating-point financial inputs.
- Serialize instants as RFC 3339 UTC. The policy timezone used to calculate deadlines remains a product decision.
- Return explicit documented enum values. Unknown financial states must not be treated as success.
- Add a request ID to responses and logs. Do not put tokens, bank data, or unnecessary provider payloads in logs.
- Use persistent idempotency for any mutation that can create a financial effect or duplicate side effect.
- Require an `Idempotency-Key` header for retry-sensitive mutations. Scope keys to authenticated actor and operation; persist the request/result association. Reuse with a different request body returns `409 idempotency_conflict`.
- Return the operating mode (`simulated` or `sandbox`) where the client needs to label payment behavior.

## 2. Error envelope

Proposed shape:

```json
{
  "error": {
    "code": "machine_readable_code",
    "message": "Safe user-facing summary",
    "details": {},
    "requestId": "req_opaque"
  }
}
```

The contract must document at least:

| HTTP status | Meaning | Example codes |
|---|---|---|
| `400` | Malformed request or invalid field | `invalid_request`, `invalid_amount` |
| `401` | Missing, invalid, expired, or rejected authentication | `unauthenticated`, `invalid_token` |
| `403` | Authenticated caller lacks permission | `forbidden`, `circle_access_denied` |
| `404` | Resource does not exist or is not safely disclosable | `not_found` |
| `409` | State or idempotency conflict | `state_conflict`, `idempotency_conflict` |
| `422` | Valid shape but product rule is not satisfied | `business_rule_failed` |
| `429` | Rate limit exceeded | `rate_limited` |
| `503` | Temporary service/provider unavailability | `temporarily_unavailable`, `provider_unavailable` |

Do not expose stack traces, token validation details, private member facts, or secrets in error bodies.

## 3. Shared wire types (proposed)

### Identifiers and time

- API IDs are opaque strings. A client must not infer ownership or sequence from an ID.
- `createdAt`, `updatedAt`, `dueAt`, `confirmedAt`, and similar instants are RFC 3339 UTC strings.
- Circle schedule dates are interpreted in `Africa/Lagos`; persist the corresponding UTC instants. Include `graceDeadlineAt` for the explicit end of the grace period.
- Team-approved MVP policy: grace is 24 hours after `dueAt`. An unpaid obligation becomes `overdue` only after `graceDeadlineAt`; a contribution is late only when verified provider transaction-success time is after that instant. Exactly at the grace deadline is within grace.
- Use a trustworthy provider transaction-success timestamp for payment timing. Do not use device time, initiation time, or webhook arrival time. If success, amount, and reference are verified but the timestamp is absent/untrustworthy, credit the amount with timing `unverified`; do not classify on-time/late. Any lateness-dependent decision waits for reconciliation.

### Money

```json
{
  "amountKobo": 500000,
  "currency": "NGN"
}
```

`amountKobo` is a non-negative integer. API and database code must reject decimal numbers, `NaN`, and overflow. Currency is explicit where an amount crosses a payment/provider boundary.

### Proposed obligation states

`upcoming`, `awaiting_payment`, `paid`, `partially_paid`, `overdue`, `under_review`.

The current Flutter enum uses camelCase equivalents. Serialization mapping must be explicit. The backend computes status from persisted obligations, payment evidence, `dueAt`, `graceDeadlineAt`, and policy; clients cannot PATCH a status. The team-approved MVP supports partial payments: confirmed amounts may be credited against an explicit obligation; the remainder stays open and does not satisfy payout eligibility.

### Proposed payout states

`scheduled`, `eligible`, `awaiting_approval`, `processing`, `settled`, `held`, `failed`, `reversed`.

Use `held` as the single public payout hold state; `on_hold` is not a separate API enum. Permitted transitions and evidence are specified below and require backend/product/Flutter contract review before payout implementation.

Team-approved MVP approval policy: the organizer may approve an eligible payout but cannot approve when they are its intended recipient. The organizer appoints one active non-recipient member as co-approver, and that member must accept. Appointment changes are locked while an affected payout is awaiting approval or processing. Approval is audited/idempotent and does not itself prove settlement.

### Payment intent states

The current client has `submitted`, `confirmed`, and `failed`. The API distinguishes pending provider confirmation from confirmed. Proposed API values are `pending`, `confirmed`, `failed`, `review_required`, and `cancelled` only where supported by the selected provider/mode. A nonterminal state must never be mapped to `confirmed`.

### Operating mode

Proposed values: `simulated`, `sandbox`. This describes the selected operation path, not whether a payment is confirmed.

## 4. Authentication and session lifecycle

1. Flutter signs in with Firebase as it does today.
2. Flutter obtains a current Firebase ID token from the signed-in Firebase user and sends it as a bearer token.
3. The backend verifies signature, issuer, audience/project, expiry, and the approved revocation policy using the official Firebase Admin verification flow.
4. The backend resolves the verified Firebase UID to an internal Ajo user ID. Account provisioning/update policy must be explicit and must not permit client-selected UID mapping.
5. Every resource operation authorizes the resolved internal user against persisted membership and role records.

Firebase token verification is not a substitute for per-resource authorization. Do not trust `userId`, member ID, circle role, or organizer status from Flutter request bodies.

## 5. Initial read/session and membership endpoints

This contract remains a draft. Routes with backend implementations are identified below; other entries remain proposals and still require API/mobile review.

| Method and path | Auth | Purpose and contract |
|---|---|---|
| `POST /v1/session` | Firebase bearer token required | Verify identity, resolve or safely provision internal user, return profile and membership summary. Request body is empty in the initial proposal. Must not accept a UID as proof of identity. |
| `GET /v1/me` | Required | Return authenticated user's profile and authorized active membership summary. |
| `GET /v1/circles?membership=active` | Required | Return only circles where caller has active membership. |
| `GET /v1/circles/{circleId}` | Required | Return circle details only after membership authorization. |
| `GET /v1/circles/{circleId}/periods` | Required | Return periods visible to an authorized member. |
| `GET /v1/circles/{circleId}/periods/{periodNumber}/ledger` | Required | Return authorized period and shared ledger facts; exclude private payment-account data. |
| `GET /v1/contributions/mine?status=open` | Required | Return only the caller's outstanding obligations across authorized circles. |
| `POST /v1/circles/{circleId}/memberships` | Required | Accept a valid invitation and rules version; activate membership only after backend checks. |
| `POST /v1/circles/{circleId}/memberships/{membershipId}/revoke` | Required | Active organizer revokes another active member with a required reason. Implemented; response and retry behavior below. |
| `POST /v1/circles/{circleId}/memberships/me/leave` | Required | Active member leaves their own circle; reason is optional. Implemented; response and retry behavior below. |
| `POST /v1/circles/{circleId}/memberships/{membershipId}/promote-organizer` | Required | Active organizer promotes an active member. Implemented; response below. |
| `POST /v1/assistant/queries` | Required; later stage | Deferred until authorized reporting exists. Request and response below are proposals. |
| `POST /v1/webhooks/bmoni` | Provider-authenticated; conditional | Deferred pending official provider docs and verified signature/replay requirements. Not a user-authenticated route. |

### Implemented membership lifecycle responses and conflicts

The three membership lifecycle routes return `200` with:

```json
{
  "membershipId": "mbr_opaque",
  "circleId": "cir_opaque",
  "status": "active",
  "role": "member",
  "eventId": "evt_opaque",
  "requestId": "req_opaque"
}
```

For leave, `status` is `inactive`; for revocation, it is `revoked`; for promotion, `role` is `organizer`. Revocation requires a non-empty reason of at most 500 characters. Leave accepts an optional reason of at most 500 characters. Promotion has no request body.

All operations derive the actor from the verified identity and current persisted membership. A non-organizer attempting revocation or promotion receives `403`. A missing/non-disclosable circle or target receives `404`. Attempts to leave/revoke an already inactive or revoked membership, revoke oneself, leave as the final active organizer, or promote an existing organizer receive `409 state_conflict`. A rejected retry creates no additional lifecycle event. A failed audit write returns `503` and rolls back the membership change. Promotion and later departure are separate transactions; each committed state must retain at least one active organizer.

The request body carries the invitation and rules acceptance described above; membership is not active until the backend completes those checks.

`POST /v1/circles/{circleId}/memberships` request:

```json
{
  "invitationCode": "opaque_invitation_value",
  "acceptedRulesVersion": "rules_v1"
}
```

The backend derives the user from the verified token and validates invitation authenticity, expiry, revocation, usage, circle capacity, duplicate membership, and the current rules version. Response proposal (`201`):

```json
{
  "membershipId": "mbr_opaque",
  "circleId": "cir_opaque",
  "status": "active",
  "acceptedRulesVersion": "rules_v1",
  "joinedAt": "2026-10-15T12:00:00Z",
  "requestId": "req_opaque"
}
```

Requester-approved MVP join policy: a valid invitation admits an authenticated user immediately after explicit rule acceptance and backend validation; organizer approval is not required. Expired, revoked, exhausted, duplicate, or capacity-violating invitations are rejected. Membership becomes active only after backend processing. Invitation expiry and usage-limit values remain to be approved before invitation implementation.

## 6. Financial mutation contracts (proposed)

These contracts are now specified for review before their implementation. All authenticated mutations require a Firebase bearer token, per-resource authorization, and an `Idempotency-Key` header. Responses include `requestId`. Repeating a key with the same authenticated actor, operation, and request body returns the original result; reusing it with a different body returns `409 idempotency_conflict`.

### Create a payment intent

`POST /v1/circles/{circleId}/obligations/{obligationId}/payment-intents`

Request:

```json
{
  "amountKobo": 250000,
  "currency": "NGN"
}
```

The backend derives the member from the authenticated user and verifies active membership and ownership of the obligation. `amountKobo` must be a positive integer no greater than the currently unreserved outstanding amount. Each intent is bound to one obligation; no client-supplied member ID or payout/status field is accepted.

Creation runs in one database transaction that locks the obligation (or uses an equivalent serializable constraint), calculates `availableKobo = expectedKobo - confirmedAllocatedKobo - reservedKobo`, where `reservedKobo` sums both `active` and `release_pending` reservations, rejects an amount above `availableKobo`, and inserts the intent, reservation, audit event, and any provider-command/outbox record atomically. A uniqueness/locking rule serializes concurrent intent creation so confirmed allocations plus active/release-pending reservations never exceed the obligation amount. Dispatch any provider command outside the transaction with a stable provider idempotency/reference key. Provider-specific guarantees require official documentation. A retry uses the same intent and provider key, never a new collection.

Response proposal (`201`):

```json
{
  "id": "pi_opaque",
  "obligationId": "obl_opaque",
  "requestedKobo": 250000,
  "currency": "NGN",
  "status": "pending",
  "mode": "simulated",
  "reservation": {
    "status": "active",
    "reservedKobo": 250000,
    "expiresAt": "2026-10-15T12:15:00Z"
  },
  "availableKobo": 250000,
  "createdAt": "2026-10-15T12:00:00Z",
  "requestId": "req_opaque"
}
```

The intent is not a confirmed contribution. Recheck outstanding amount under transaction/locking when applying a later event because other confirmed payments can race.

#### Atomic confirmation and allocation

After signature/authenticity checks, process a successful provider event or authorized simulation in one database transaction with a consistent lock order: obligation, intent/reservation, then event/allocation records. Enforce unique provider event identity and at most one successful collection/allocation per intent for the MVP. In that transaction, deduplicate the event, revalidate intent/reference/currency/amount and reservation state, insert the immutable payment event and allocation, update the intent and reservation to `confirmed`, recalculate the obligation, and insert audit evidence. These writes commit or roll back together. A duplicate event or concurrent callback returns the prior outcome; it cannot create a second allocation. If a provider requires multiple successful captures per intent, define that separately before implementation.

For a verified event that cannot safely be allocated because it is mismatched or unreserved, persist the event and a review case without inserting an obligation allocation. Do not partially commit event-processing steps.

### Simulated confirmation

`POST /v1/demo/payment-intents/{intentId}/confirm`

This route is registered only when an explicit, validated demo configuration is active; simulation is disabled by default. Startup must fail closed if simulation is enabled in a production/non-demo environment or the configured data source is not marked synthetic. Configuration is server-owned and cannot be enabled by request parameters. Outside demo mode, the route is absent or returns a non-disclosing `404`.

The caller must have a verified Firebase identity mapped to an active `demo_operator` permission. That permission is provisioned out-of-band and scoped to the approved synthetic demo tenant/circles; it cannot be self-assigned or supplied in a request body. The operator may confirm only pending `simulated` intents tied to synthetic members in that scope. The endpoint is idempotent, labels resulting facts `simulated`, and records operator, intent, circle, amount, time, and request ID in an audit event. Provider outage never invokes it automatically. No BMONI client endpoint may mark an intent confirmed.

Request body: empty. Response proposal:

```json
{
  "intentId": "pi_opaque",
  "status": "confirmed",
  "eventId": "evt_opaque",
  "creditedKobo": 250000,
  "currency": "NGN",
  "confirmedAt": "2026-10-15T12:00:00Z",
  "timingStatus": "verified",
  "obligation": {
    "id": "obl_opaque",
    "confirmedKobo": 250000,
    "outstandingKobo": 250000,
    "status": "partially_paid"
  },
  "mode": "simulated",
  "requestId": "req_opaque"
}
```

### Simulated reversal

`POST /v1/demo/transactions/{transactionId}/reversals`

Request:

```json
{
  "reason": "Synthetic demo reversal"
}
```

This route is available only under the same fail-closed demo configuration and `demo_operator` scope as simulated confirmation. It requires an `Idempotency-Key` and a synthetic transaction in that operator's approved scope. It creates a new linked reversal event, never edits or deletes the original transaction. The response returns reversal event ID, original transaction ID, reversed amount in integer kobo, resulting obligation state, `mode: simulated`, and request ID. A repeated key returns the same reversal; a second distinct reversal of an already fully reversed transaction is rejected with `409 state_conflict`. Every action is audited.

Response proposal:

```json
{
  "reversalEventId": "evt_reverse_opaque",
  "originalTransactionId": "txn_opaque",
  "reversedKobo": 250000,
  "obligation": {
    "id": "obl_opaque",
    "confirmedKobo": 0,
    "outstandingKobo": 500000,
    "status": "overdue"
  },
  "mode": "simulated",
  "requestId": "req_opaque"
}
```

### Payout approval

`POST /v1/circles/{circleId}/payouts/{payoutId}/approvals`

Request:

```json
{
  "decision": "approve"
}
```

In one database transaction, lock the payout and all obligations, allocations, reversals, and blocking review records that determine its eligibility. Recompute eligibility from those locked authoritative records; do not trust the previously stored `eligible` or `awaiting_approval` status. If eligibility no longer holds, transition the payout to `held` and return a state conflict without approving or enqueueing processing. Otherwise verify that the actor is the organizer or accepted co-approver and is not the intended recipient, record actor/time, and atomically create a unique payout attempt and outbox command. A uniqueness constraint permits at most one unresolved attempt per payout. The response's `processing` state means a durable attempt was queued; it is not evidence that the provider accepted or settled it.

The worker claims the outbox command and, in a database transaction, locks the same eligibility records, recomputes eligibility, and records a unique attempt ID plus stable merchant reference before releasing the transaction and making the external call. If a reversal/dispute commits before this dispatch authorization, cancel the unsent command and hold the payout. The database transaction cannot make the provider call atomic: if the call times out, the worker crashes after sending, or the outcome is otherwise uncertain, keep the attempt unresolved and payout `processing`; do not create or send a new attempt. Reconcile by querying the provider using the same reference/idempotency key where supported. Only retry with the same provider key if official provider documentation guarantees idempotent replay; otherwise require definitive provider status or manual reconciliation before another submission. A reversal after dispatch authorization cannot be assumed to cancel an in-flight transfer; mark the attempt for reconciliation and do not issue a duplicate transfer. Response proposal:

```json
{
  "payoutId": "pay_opaque",
  "status": "processing",
  "approvedBy": "usr_opaque",
  "mode": "simulated",
  "requestId": "req_opaque"
}
```

Approval is not settlement proof. Only verified provider settlement evidence or an explicit demo simulation event can produce `settled`.

### Appoint and accept a co-approver

- `POST /v1/circles/{circleId}/approver-appointments` (organizer only), request `{ "memberId": "mbr_opaque" }`.
- `POST /v1/circles/{circleId}/approver-appointments/{appointmentId}/accept` (the appointed member only), empty request body.

The appointee must be an active circle member other than the organizer. Appointment is not active until accepted. Only one active co-approver is allowed per circle. Appointment/replacement is not permitted while a payout it could approve is awaiting approval or processing. Response proposal:

```json
{
  "appointmentId": "ap_opaque",
  "memberId": "mbr_opaque",
  "status": "pending",
  "createdAt": "2026-10-15T12:00:00Z",
  "requestId": "req_opaque"
}
```

Acceptance returns the same shape with `status: active` and `acceptedAt`. This appointment is approval authority only; it does not confer dispute-review authority.

### Create and decide a dispute

- `POST /v1/circles/{circleId}/disputes`, by an authorized circle member, request:

```json
{
  "subjectType": "contribution",
  "subjectId": "obl_opaque",
  "category": "payment_record",
  "description": "The recorded amount does not match my receipt",
  "evidenceReferences": ["ev_opaque"]
}
```

  Response proposal: `{ "disputeId": "dsp_opaque", "status": "open", "createdAt": "2026-10-15T12:00:00Z", "requestId": "req_opaque" }`. Evidence references must be authorized resources; do not accept raw bank credentials or arbitrary claims as proof.
- `POST /v1/disputes/{disputeId}/decisions`, by an authorized non-conflicted reviewer, request `{ "decision": "accepted|rejected|escalated", "reason": "...", "evidenceReferences": [] }`.

  An accepted financial correction is generated by the backend as a linked immutable correction/reversal event in the same transaction as the decision/audit record. The caller cannot supply replacement balances or overwrite historical event fields. Internal correction does not assert provider refund/reversal.

  Response proposal: `{ "disputeId": "dsp_opaque", "status": "accepted", "decisionId": "dec_opaque", "correctionEventId": "evt_opaque", "decidedAt": "2026-10-15T12:00:00Z", "requestId": "req_opaque" }`. `correctionEventId` is absent when the decision does not require a financial correction.

If the organizer is conflicted, the case is escalated and remains unresolved until an independent authorized reviewer is assigned. That reviewer-assignment mechanism remains a feature-specific dependency.

### BMONI event intake

`POST /v1/webhooks/bmoni` remains conditional. Do not define provider-specific headers, payloads, signature algorithms, or response codes until official documentation is reviewed. The implementation must authenticate the raw request before financial mutation, durably deduplicate provider event IDs, and return a replay-safe response. Invalid signature causes no mutation. A valid event with mismatched amount/reference/member/intent is retained for review, not credited.

## 7. Permitted state transitions (proposed)

### Payment reservation

| Current | Allowed next | Condition |
|---|---|---|
| `active` | `confirmed` | Verified provider success or authorized simulation; reservation is consumed atomically into its allocation |
| `active` | `release_pending` | Local expiry or cancellation requested while the provider may still collect; keep the amount reserved |
| `active` | `cancelled` | Verified provider failure or simulation terminal event confirms no collection occurred |
| `release_pending` | `expired` or `cancelled` | Provider terminal/cancellation evidence or simulation terminal event confirms no later collection can occur |
| `release_pending` | `confirmed` | Verified delayed success arrives while reservation is still held; consume reservation atomically into its allocation |
| `confirmed`, `expired`, `cancelled` | none | Terminal reservation; a later reversal is a new linked event |

Only `active` and `release_pending` reservations reduce available balance. A local TTL expiring is not proof of provider cancellation. If a late success arrives after a reservation was terminally released, preserve the verified provider event and amount but leave it unapplied and under review; do not consume another intent's reservation, auto-carry it to another obligation, or imply a refund.

#### Late success after reservation release

The handler durably deduplicates the provider event and creates an `unapplied_funds` record plus a reconciliation case linked to the terminal intent, provider reference, amount, and evidence. Do not reopen the reservation, allocate the amount to the obligation, count it as a contribution, or apply it to another member/period. This records the verified receipt without double-crediting the ledger or silently discarding the collection.

An authorized payment-operations reviewer must reconcile the provider transaction and record a decision. If the charge is valid but cannot be allocated, a refund is a separate provider operation with its own authorization, idempotency key, attempt record, and verified refund evidence; an internal ledger correction does not prove a refund. If refund capability or outcome is unavailable/uncertain, keep the unapplied amount and case open, escalate for manual resolution, and do not submit another refund attempt without reconciliation. Approve the reviewer role and provider-specific refund path before enabling collection.

### Payment intent

| Current | Allowed next | Condition |
|---|---|---|
| `pending` | `confirmed` | Verified provider success or authorized simulated event; amount and reference checks pass |
| `pending` | `failed` | Verified provider failure or explicit simulation failure |
| `pending` | `review_required` | Provider mismatch, ambiguous result, or reconciliation required |
| `pending` | `cancellation_pending` | Cancellation or expiry requested while provider collection may still complete |
| `cancellation_pending` | `cancelled` or `expired` | Provider terminal/cancellation evidence or simulation terminal event; release reservation atomically |
| `cancellation_pending` | `confirmed` or `review_required` | Delayed success arrives; apply only while reservation remains held, otherwise keep unapplied for review |
| `review_required` | `confirmed` or `failed` | Authorized reconciliation with evidence and audit |
| `confirmed`, `failed`, `cancelled`, `expired` | none | Terminal; a later correction/reversal is a new linked event, not an intent rewrite |

Reservation and payment-intent states are distinct but coordinated. Confirmation consumes the reservation and creates its allocation atomically. If an event is ambiguous, the payment intent moves to `review_required` while the reservation remains `active` or `release_pending` and continues to reduce available balance. A local timeout alone must not release funds while a provider can still collect.

Duplicate event delivery returns its prior processing result and creates no second financial effect. An event amount greater than the intent is held wholly for review. If a matching verified intent races with another payment and its obligation's remaining amount has fallen, allocate at most the locked remainder and record excess as unapplied/review-required; no automatic carry-forward or refund.

If provider evidence verifies success and amount but has no trustworthy transaction timestamp, credit the verified amount and set timing to `unverified`. Do not mark on-time or late. Rules that depend on lateness wait for reconciliation; amount-only payout eligibility may use the verified amount. Device time, initiation time, and webhook arrival time are not substitutes.

### Obligation

The public obligation state is derived, not directly mutated by an API request:

| Derived state | Condition |
|---|---|
| `upcoming` | Period is not yet open for contribution |
| `awaiting_payment` | Period is open, no confirmed amount exists, and grace deadline has not passed |
| `partially_paid` | Some but not all amount is confirmed, and grace deadline has not passed |
| `paid` | Required amount is fully allocated from verified confirmed events |
| `overdue` | Outstanding amount remains after grace deadline, including a partial payment |
| `under_review` | An unresolved dispute or payment-evidence review affects this obligation; confirmed amount remains separately visible |

Pending intent alone does not increase confirmed amount or clear a shortfall. An unresolved review is cleared only by its authorized resolution; then status is recomputed from records and time. Exactly at the grace deadline is within grace; after it, outstanding obligations are overdue.

### Payout

Use `held` as the single public hold status; `on_hold` is not a separate state. Proposed transitions:

| Current | Allowed next | Condition |
|---|---|---|
| `scheduled` | `eligible` | All required obligations are fully funded with verified allocations and no blocking review exists |
| `scheduled` | `held` | Grace has passed with a shortfall, or a blocking dispute/reconciliation prevents eligibility |
| `held` | `eligible` | Shortfall/review is resolved and eligibility is recomputed successfully |
| `eligible` | `awaiting_approval` | Eligibility snapshot is committed and approval is required |
| `eligible` | `held` | Reversal, accepted dispute, or other blocking fact invalidates eligibility before approval/submission |
| `awaiting_approval` | `processing` | Authorized non-recipient organizer/co-approver approves; eligibility rechecked transactionally |
| `awaiting_approval` | `held` | Eligibility is lost or a blocking review is opened before approval |
| `processing` | `settled` | Verified provider settlement or explicit authorized demo settlement evidence |
| `processing` | `failed` | Verified provider failure; no settlement evidence exists |
| `processing` | `held` | A queued payout attempt has not yet been submitted to the provider and a final eligibility check fails; cancel the unsent attempt atomically |
| `settled` | `reversed` | Verified provider reversal or explicit authorized simulated reversal event |

Eligibility is revalidated transactionally at approval and again immediately before provider submission. Lock the payout and all rows used to derive eligibility, or use an equivalent version/serialization mechanism. A reversal/dispute that commits first forces `held`; approval cannot race past it. If the provider request has already been sent, later invalidation requires reconciliation and must not trigger a duplicate attempt. A failed payout is terminal in the initial contract; any retry requires a separately reviewed payout-attempt contract and verified evidence that no settlement occurred. An ambiguous provider timeout leaves the payout `processing` pending reconciliation. A payout recipient cannot approve their own payout. Approval/processing does not itself establish settlement.

The durable payout-attempt record has these proposed states: `queued`, `dispatch_authorized`, `provider_pending`, `outcome_unknown`, `settled`, `failed`, and `cancelled_unsent`. The worker moves `queued` to `dispatch_authorized` in the same transaction as the final locked eligibility check. That commit is the dispatch authorization point: a reversal/dispute committed before it cancels the unsent attempt and holds the payout; one committed after it is treated as racing an in-flight provider operation and requires reconciliation. `outcome_unknown` is entered after timeout, connection loss, or a crash where it is not provable whether the request reached the provider. It cannot be reset to `queued` or retried with a new key. Resolve it through provider lookup/reconciliation; replay the same key only if official provider documentation guarantees idempotency. Without that guarantee, require manual reconciliation before any further submission.

### Dispute

| Current | Allowed next | Condition |
|---|---|---|
| `open` | `under_review` | Eligible non-conflicted reviewer accepts assignment |
| `under_review` | `accepted`, `rejected`, `escalated` | Authorized reviewer records reason, time, and evidence references |
| `escalated` | `under_review` | Independent authorized reviewer accepts assignment |
| terminal decision | none | New evidence requires a new linked dispute; historical decision is not overwritten |

Accepted corrections are append-only and idempotent. If the dispute could affect payout correctness, the affected payout remains `held` until a fresh eligibility evaluation.

## 8. Initial read/session response examples

Example session response proposal:

```json
{
  "user": {
    "id": "usr_opaque",
    "displayName": "Tolu Adebayo"
  },
  "memberships": [],
  "requestId": "req_opaque"
}
```

Example obligation response proposal:

```json
{
  "id": "obl_opaque",
  "circleId": "cir_opaque",
  "periodId": "per_opaque",
  "amountKobo": 500000,
  "confirmedKobo": 0,
  "outstandingKobo": 500000,
  "status": "overdue",
  "dueAt": "2026-10-14T11:00:00Z",
  "graceDeadlineAt": "2026-10-15T11:00:00Z"
}
```

The example represents a noon Africa/Lagos due time and the approved 24-hour grace interval. It is illustrative, not a demo fixture.

## 9. Assistant contract proposal (later stage)

Request:

```json
{
  "circleId": "cir_opaque",
  "question": "Why is the current payout held?",
  "language": "en"
}
```

The caller identity comes only from authenticated request context, not the body. Proposed response:

```json
{
  "answer": "The payout is held because ...",
  "factsAsOf": "2026-10-15T12:00:00Z",
  "sources": ["per_opaque", "payout_opaque"],
  "capabilities": {
    "canMoveMoney": false
  }
}
```

Supported languages, source identifier exposure, unsupported-question behavior, and the use of any model provider require review. The reporting layer must authorize and calculate facts before answer generation.

## 10. Contracts required before later features

Before their implementation stage, write request/response schemas and authorization rules for circle creation/joining, rule acceptance, payment intent creation, simulated confirmation, BMONI event handling, payout approval, reminders, disputes, reliability history, and profile edits. Define pagination and filtering for any list that can grow.

For disputes, use wire states `open`, `under_review`, `accepted`, `rejected`, and `escalated`. A non-conflicted organizer may review; a conflicted organizer requires an independent authorized reviewer. Accepted disputes create a linked append-only correction/reversal record, never overwrite history, and do not imply a provider refund. The independent reviewer appointment mechanism remains an implementation dependency.

## 11. Flutter integration implications

- Preserve the current local demo until a separately approved integration milestone.
- Introduce explicit serialization for integer-kobo values, UTC instants, and enum conversions.
- Do not expose demo IDs (`me`, `m1`) as API IDs.
- UI actions must distinguish pending submission from confirmed payment and show simulation/sandbox mode.
- Define safe behavior for unknown enum values and API failures before connecting screens.
