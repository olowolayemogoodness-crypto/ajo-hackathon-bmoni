# Ajo Local Demo Circle Rules

- **Version:** `ajo-demo-rules-1.0.0`
- **Status:** Approved for the local synthetic demo only
- **Effective only when:** The backend explicitly enables local/demo mode and synthetic data
- **Not:** Production rules, legal terms, or authorization for real-money operations

## 1. Demo boundary

This demonstration uses synthetic circles, member names, obligations, and financial records. It moves no real money and does not connect to BMONI or another payment provider. Every simulated contribution and payout settlement is labelled `simulated` and is created only by an explicitly configured server-side demo operator.

The authenticated Firebase identity is used only by the backend to identify the caller. The backend derives current circle membership and permissions from persisted records. Client state and assistant explanations do not establish membership, payment, balance, or payout eligibility.

## 2. Membership and invitation

Circles are invite-only. A member must authenticate, inspect this exact rules version, explicitly accept it, and pass backend invitation, capacity, and duplicate-membership checks before joining.

Invitations expire seven days after creation and are single-use by default. An invitation is consumed only when acceptance and membership activation commit successfully. An active member count includes the organizer; pending invitations do not count toward capacity.

Leaving or revocation immediately removes circle access. Membership changes do not delete or settle financial records. Rejoining requires a new valid invitation and fresh acceptance. This demo uses one stable membership record per user/circle and preserves lifecycle events.

## 3. Contribution schedule and obligations

The demo supports weekly contributions only. The organizer selects the first due date before activation. Each due time is 09:00 in `Africa/Lagos`; the backend persists the corresponding UTC instant and a 24-hour grace deadline.

Exactly at the grace deadline is within grace. An unpaid obligation becomes overdue only after that instant. Payment timing is determined only from the recorded simulated event time in this local demo; this does not establish a production provider-timestamp policy.

Amounts use integer kobo. Each member has one obligation for the single demo period. Partial contributions are allowed and apply only to that member's obligation. A partial amount leaves the remainder outstanding and does not satisfy full-funding eligibility. Cross-obligation allocation is not allowed. Contributions cannot exceed the remaining obligation; an attempted excess is rejected and does not create a financial event.

## 4. One-period payout

Before activation, the organizer selects one active non-organizer member as the recipient for the single demo payout period. Activation locks that recipient and order for the period.

The backend calculates eligibility from persisted obligations and contribution events. Every required obligation must be fully funded before the payout is eligible. A missing or partial contribution keeps the payout ineligible; no client or timer can mark it eligible or settled.

The active organizer may approve an eligible payout only when they are not its recipient. Approval records the actor and moves the payout to processing; approval is not settlement. The explicitly configured demo operator must perform a separate simulated settlement action. Only that action records `settled`, with a distinct simulated payout event.

This first demo selects a non-organizer recipient, so it does not exercise co-approver appointment. It does not remove the requirement for an accepted non-recipient co-approver when a future approved flow has an organizer as recipient.

## 5. Records and unresolved production policy

Contribution and payout history is recorded as append-only simulated events. Repeated idempotency keys cannot create duplicate contribution credit. Failed transactions leave neither a financial event nor a partial balance change.

This demo rules version does not define live-provider reconciliation, real-money refunds, production dispute escalation, privacy/data-retention terms, fees, or a full payout rotation. Those remain outside the local synthetic demonstration and require separate approval before production use.