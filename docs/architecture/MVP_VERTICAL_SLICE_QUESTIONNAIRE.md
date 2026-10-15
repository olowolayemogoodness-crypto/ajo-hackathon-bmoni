# Ajo MVP Vertical Slice: Decision Questionnaire

- **Purpose:** Resolve only the product decisions needed to build a demonstrable synthetic circle cycle.
- **Scope:** Local/demo behavior; this does not approve production rules, live payments, deployment, or compliance posture.
- **How to answer:** Add answers below each question or reply with the question numbers and decisions. Proposed options are not approved until explicitly accepted.

## Already approved; not reopened here

- Firebase identity is verified server-side; active persisted membership authorizes circle access.
- Money uses integer kobo. Partial contributions apply only to one explicit obligation; the remainder remains due and does not satisfy full payout eligibility.
- Schedule interpretation uses `Africa/Lagos`, UTC instants, and a 24-hour grace period. Exactly at the grace deadline is within grace.
- Invitations default to a 7-day TTL and one successful use; capacity is mandatory and concurrency-safe.
- Simulated money must be synthetic, explicitly labelled, authorized, and incapable of falling back from provider failure. Real-money collection and payout are out of hackathon scope.
- An organizer cannot approve their own payout. A non-recipient co-approver must be appointed and accept when the organizer is the recipient.

## Decisions needed

### 1. Demo-only rules

May the MVP use a separate, explicitly demo-only rules document and version, distinct from the unapproved [`CIRCLE_RULES.md`](CIRCLE_RULES.md)? It would state that the demo uses synthetic circle/payment data and no real money; describe the approved invitation, contribution, grace, payout eligibility, and approval behavior; and avoid making production/legal claims.

- Decision: `APPROVE AS A DEMO-ONLY DRAFT / REVISE / DO NOT USE`
- Required edits or exact approved text:
- May the approved demo version be accepted only in local/demo mode? `YES / NO`
- Approver and version identifier, once approved:

Do not use `rules_v1` or proposed `ajo-circle-rules-1.0.0` as an approved version.

### 2. Simulated operator

The financial policy requires an out-of-band `demo_operator` permission scoped to synthetic circles. Which local/demo-only provisioning mechanism should the backend use?

- Proposed: explicitly configured Firebase UID allowlist in server environment; disabled by default and rejected outside the configured local/demo environment.
- Decision or alternative:
- Which test identity/account should receive this permission? Do not provide credentials or tokens.

The client must not grant itself this permission, and organizer status alone is not sufficient. The operator should be able to simulate a contribution and a payout settlement, each recorded as a distinct labelled event.

### 3. First demo schedule

- Proposed first slice: weekly contributions only, with configured due date/time in `Africa/Lagos` and the approved 24-hour grace period.
- Enable now: `WEEKLY ONLY / WEEKLY + BIWEEKLY / OTHER`
- Due time in `Africa/Lagos`:
- If monthly is needed, confirm calendar-month behavior rather than a fixed 30-day interval:

### 4. Payout order and demo approval

The payout-order lock point remains open. For the demo, may the organizer configure an explicit recipient order before activation, with the order immutable after activation? This is a demo-scoped rule, not a production policy decision.

- Decision: `APPROVE / REVISE`
- First demo payout recipient should be a non-organizer so organizer approval can be shown without self-approval:
- Should the first demonstrable cycle be one period or the full recipient rotation? `ONE PERIOD / FULL ROTATION`

If the organizer is a recipient in a full rotation, the demo must demonstrate the accepted co-approver appointment/acceptance path before approval; do not bypass it.

### 5. Demo data and execution boundary

Can the first end-to-end flow run only in a local/demo environment with synthetic member names, circles, obligations, contributions, and payout records, using the authenticated Firebase UID only for server-side identity mapping? No bank details or live provider calls are needed.

- Decision: `APPROVE / REVISE`
- Where will the demo run first: `LOCAL EMULATOR / LOCAL API + POSTGRES / OTHER`?
- Any real participant data permitted? `NO / SPECIFY AND APPROVE`

This decision does not replace the still-required privacy notice/data-retention approval before broader use.

## Proposed observable acceptance flow

After the decisions above are recorded, the first vertical slice should demonstrate: authenticated organizer creates a capacity-bounded circle and schedule; an invited synthetic member accepts the approved demo rules; the backend creates member obligations; authorized demo operation records idempotent simulated contributions; backend reports collected amount, shortfall, and payout eligibility; a non-conflicted organizer approves an eligible payout; an authorized simulated settlement records a distinct simulated event; Flutter displays those backend facts and the assistant explains them without deciding them.

Invitation defaults and live-provider behavior remain as already decided or gated; this questionnaire does not authorize real-money operations.