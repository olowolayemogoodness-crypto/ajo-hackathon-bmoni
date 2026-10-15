# Ajo API Contract v1 (Draft)

- **Status:** Proposed contract; no routes currently exist in the inspected repository
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

## 5. Initial read/session endpoint proposals

These routes are proposed only; they are not implemented.

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
| `POST /v1/assistant/queries` | Required; later stage | Deferred until authorized reporting exists. Request and response below are proposals. |
| `POST /v1/webhooks/bmoni` | Provider-authenticated; conditional | Deferred pending official provider docs and verified signature/replay requirements. Not a user-authenticated route. |

Requester-approved MVP join policy: a valid invitation admits an authenticated user immediately after explicit rule acceptance and backend validation; organizer approval is not required. Expired, revoked, exhausted, duplicate, or capacity-violating invitations are rejected. Membership becomes active only after backend processing. Invitation expiry and usage-limit values remain to be approved before invitation implementation.

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

The backend derives the member from the authenticated user and verifies active membership and ownership of the obligation. `amountKobo` must be a positive integer no greater than current outstanding amount. Each intent is bound to one obligation; no client-supplied member ID or payout/status field is accepted.

Response proposal (`201`):

```json
{
  "id": "pi_opaque",
  "obligationId": "obl_opaque",
  "requestedKobo": 250000,
  "currency": "NGN",
  "status": "pending",
  "mode": "simulated",
  "createdAt": "2026-10-15T12:00:00Z",
  "requestId": "req_opaque"
}
```

The intent is not a confirmed contribution. Recheck outstanding amount under transaction/locking when applying a later event because other confirmed payments can race.

### Simulated confirmation

`POST /v1/demo/payment-intents/{intentId}/confirm`

This route exists only in explicit demo configuration with synthetic identities/data. It must be disabled in non-demo environments, authorized as a demo action, idempotent, and labelled `simulated`. It exercises the same amount, allocation, and ledger transaction rules. Provider outage never invokes it automatically. No BMONI client endpoint may mark an intent confirmed.

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

This route is disabled outside explicit demo configuration and requires demo-operator authorization plus an `Idempotency-Key`. It creates a new linked reversal event, never edits or deletes the original transaction. The response returns reversal event ID, original transaction ID, reversed amount in integer kobo, resulting obligation state, `mode: simulated`, and request ID. A repeated key returns the same reversal; a second distinct reversal of an already fully reversed transaction is rejected with `409 state_conflict`.

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

The backend verifies that the payout is awaiting approval and still eligible, then verifies that the actor is the organizer or the accepted co-approver appointed for the circle and is not the intended recipient. Approval records actor/time and is atomic with the state transition. Response proposal:

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

### Payment intent

| Current | Allowed next | Condition |
|---|---|---|
| `pending` | `confirmed` | Verified provider success or authorized simulated event; amount and reference checks pass |
| `pending` | `failed` | Verified provider failure or explicit simulation failure |
| `pending` | `review_required` | Provider mismatch, ambiguous result, or reconciliation required |
| `pending` | `cancelled` | Only if the selected provider/mode supports verified cancellation |
| `review_required` | `confirmed` or `failed` | Authorized reconciliation with evidence and audit |
| `confirmed`, `failed`, `cancelled` | none | Terminal; a later correction/reversal is a new linked event, not an intent rewrite |

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
| `awaiting_approval` | `processing` | Authorized non-recipient organizer/co-approver approves; eligibility rechecked transactionally |
| `awaiting_approval` | `held` | Eligibility is lost or a blocking review is opened before approval |
| `processing` | `settled` | Verified provider settlement or explicit authorized demo settlement evidence |
| `processing` | `failed` | Verified provider failure; no settlement evidence exists |
| `settled` | `reversed` | Verified provider reversal or explicit authorized simulated reversal event |

No other transition is permitted. A failed payout is terminal in the initial contract; any retry requires a separately reviewed payout-attempt contract and verified evidence that no settlement occurred. An ambiguous provider timeout leaves the payout `processing` pending reconciliation; it must not trigger a duplicate attempt. A payout recipient cannot approve their own payout. Approval/processing does not itself establish settlement.

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
