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

**Decision:** Approve a separate demo-only rules version for local synthetic demo use. It does not approve the unapproved production-oriented [`CIRCLE_RULES.md`](CIRCLE_RULES.md), create production rules, or authorize live-money behavior.

The approved demo rules are [ajo-demo-rules-1.0.0.md](circle-rules/ajo-demo-rules-1.0.0.md), version `ajo-demo-rules-1.0.0`. They apply only in explicitly enabled local/demo mode and use synthetic data/no real money.

Do not use `rules_v1` or proposed `ajo-circle-rules-1.0.0` as an approved version.

### 2. Simulated operator

The financial policy requires an out-of-band `demo_operator` permission scoped to synthetic circles.

- **Decision:** Use a server-side Firebase UID allowlist, local/demo-environment-only. It is disabled by default; an empty allowlist authorizes no simulated operations. Startup/configuration must fail closed outside local/test synthetic mode.
- No actual UID is assigned in source or shared here. The demo operator must be configured locally by the team; do not provide credentials or tokens.

The client must not grant itself this permission, and organizer status alone is not sufficient. The operator should be able to simulate a contribution and a payout settlement, each recorded as a distinct labelled event.

### 3. First demo schedule

- **Decision:** Weekly only, due at 09:00 `Africa/Lagos` time, with the approved 24-hour grace period.
- The organizer selects the first due date before activation; no hidden first-date default is used.
- Biweekly/monthly schedules and calendar-month semantics are deferred.

### 4. Payout order and demo approval

The payout-order lock point remains open for the production circle lifecycle. For the synthetic demo, the organizer configures the single period's recipient before activation and it becomes immutable after activation.

- **Decision:** One payout period with a non-organizer recipient. This allows the organizer to demonstrate approval without self-approval. Full recipient rotation is deferred.
- Co-approver appointment remains pending because the demo recipient is not the organizer. Do not fabricate an appointment or silently promote an account.

If the organizer is a recipient in a full rotation, the demo must demonstrate the accepted co-approver appointment/acceptance path before approval; do not bypass it.

### 5. Demo data and execution boundary

The first end-to-end flow runs only against a local API and PostgreSQL, with synthetic circle/member names, obligations, contributions, and payout records. The authenticated Firebase UID is used only for server-side identity mapping. No bank details or live provider calls are used.

- **Decision:** Local API + PostgreSQL. Real participant data is not permitted; use synthetic names and records only.

This decision does not replace the still-required privacy notice/data-retention approval before broader use.

## Proposed observable acceptance flow

The first vertical slice should demonstrate: authenticated organizer creates a capacity-bounded circle and weekly schedule; an invited synthetic member accepts the demo rules; the backend creates one period's obligations; an explicitly configured demo operator records idempotent simulated contributions; backend reports collected amount, shortfall, and payout eligibility; a non-conflicted organizer approves an eligible payout; the demo operator explicitly records simulated settlement; Flutter displays backend facts and the assistant explains them without deciding them.

Invitation defaults and live-provider behavior remain as already decided or gated; this questionnaire does not authorize real-money operations.