# Ajo Circle Participation Rules

- **Proposed version:** `ajo-circle-rules-1.0.0`
- **Status:** Draft pending explicit approval; not authoritative
- **Scope:** Membership, participation, contributions, payouts, disputes, privacy, and circle governance
- **Publication:** No immutable copy exists. Do not configure this version on a circle or use it for acceptance.

## 1. Membership and eligibility

Participation in an Ajo circle requires authentication, a valid invitation, explicit acceptance of the circle's current approved rules, and successful backend validation. A valid invitation permits admission after those checks; a second organizer approval is not required.

Each circle has an explicitly configured positive member capacity. Active members, including the organizer, count toward it; pending invitations do not. An invitation cannot be accepted when the circle is full.

Invitations expire seven days after creation and are single-use by default. An organizer may issue a multi-use invitation only with an explicit maximum-use count. A use is consumed only when acceptance and membership activation commit successfully. Expired, revoked, exhausted, or otherwise invalid invitations cannot be used.

Previous membership does not guarantee automatic re-entry after leaving or revocation. Rejoining requires a fresh valid invitation, authentication, acceptance of the current rules, and current eligibility/capacity checks. Rejoining does not automatically restore organizer privileges.

Members must keep their account and participation information accurate.

## 2. Contributions and financial records

Contribution amounts, schedules, due dates, grace periods, confirmed payments, outstanding obligations, and payout eligibility are determined by authoritative backend records and approved circle configuration. A client or AI explanation cannot set or override those facts.

Amounts are represented as integer kobo. Partial contributions are permitted and credited only after verified confirmation to the explicit obligation. The remaining amount stays outstanding; a partial contribution does not satisfy full-funding requirements for payout eligibility. Contributions are not automatically allocated across obligations.

Schedule times use `Africa/Lagos` policy time and are persisted as UTC instants. Each obligation has an explicit due instant and a 24-hour grace period. Exactly at the grace deadline is within grace; a payment is late, or an unpaid obligation becomes overdue, only after that deadline.

Use a trustworthy provider transaction-success timestamp to classify timeliness. Do not substitute device time, payment initiation, or webhook arrival. If amount and success are verified but transaction time is missing or untrusted, the amount may be credited as timing-unverified; it must not be classified on-time or late, and lateness-dependent decisions wait for reconciliation.

A payment is not confirmed merely because a member reports making it, a client displays success, or a request times out. Provider or reconciliation evidence must be verified by the backend. A verified event that cannot be safely allocated remains unapplied and under review; it is not discarded, double-credited, automatically carried forward, or automatically refunded.

A payment intent cannot exceed the unreserved outstanding amount of its one explicit obligation. An event that exceeds its intent is held wholly for review. If a verified event matches the intent but concurrent payments have reduced the obligation's remaining amount, only the locked remainder may be allocated; the excess remains unapplied for review. Active and release-pending reservations both count against available amount. Local expiry alone does not release a reservation while the provider may still collect. A verified success after final release is recorded once as unapplied funds for reconciliation.

Historical financial records must not be silently deleted or overwritten. Corrections and reversals must be recorded as linked, auditable events.

Members must not assume that leaving a circle cancels an existing financial obligation.

## 3. Payment and payout safety

Payouts are subject to the circle's approved payout order, applicable eligibility requirements, required approvals, and verified financial state. A missing required contribution, unresolved reconciliation, or other failed release condition prevents payout eligibility or keeps the payout held.

A non-recipient organizer may approve an eligible payout. An organizer who is the intended recipient cannot approve it; the organizer must appoint one active non-recipient co-approver, who must accept the appointment. Appointment changes are locked while an affected payout is awaiting approval or processing. Approval is audited and is not evidence of settlement.

The exact lifecycle point at which payout order becomes immutable and the authorized amendment procedure are not yet approved. Until they are, the backend must not permit payout-order changes through an ordinary update operation.

Only verified settlement evidence may mark a real payout settled. A timeout or uncertain provider outcome is unresolved, not proof of success or failure, and must not trigger a blind duplicate transfer. Real-money transfers are outside the approved hackathon MVP. Any synthetic simulation must be explicitly authorized, clearly labelled, and isolated from real-provider behavior; provider failure never enables simulation.

No member or organizer may bypass backend release conditions, impersonate another member, or treat an uncertain provider result as proof that a transfer succeeded.

## 4. Organizer responsibilities and accountability

Organizers administer membership and circle settings only within their authorized permissions. They may revoke another active member only through the authorized process and with a non-empty reason; they cannot revoke themselves through that operation. An active member may leave their own circle, with an optional reason.

Membership transitions and audit events are committed atomically. Revocation or departure immediately removes active circle access but does not erase obligations, contributions, reversals, disputes, payouts, or audit history, and does not automatically settle or cancel financial state.

Organizer actions affecting membership, rules, schedules, approvals, and other protected operations are subject to backend authorization and audit requirements. A circle organizer cannot publish global Ajo rules or classify global rule changes.

The final active organizer must not leave or be removed until an eligible active member has been explicitly promoted to organizer, or the circle is closed through a separate authorized workflow. Organizer privileges are never transferred implicitly.

An organizer cannot approve their own payout. Conflicted disputes must follow the approved independent-review procedure; the independent-reviewer appointment policy remains unresolved.

## 5. Leaving, removal, and rejoining

Members may leave their circle through the approved backend process. A final active organizer cannot leave while the circle remains operational unless another eligible active member has first been explicitly promoted.

An active organizer may revoke another active member with a required reason. Every successful revocation or voluntary departure is audited with actor, affected membership, action, previous/resulting state, timestamp, request ID, and applicable reason.

Rejoining after leaving or revocation requires a new valid invitation and fresh acceptance of the current rules. The stable membership record may be reactivated only in the successful acceptance transaction; append-only events preserve each prior tenure. A revoked member cannot directly reactivate, and a returning member re-enters as an ordinary member.

Membership changes must not erase financial history, settle outstanding obligations, or cancel pending financial operations automatically. Apply the relevant financial reconciliation and payout-hold policies.

## 6. Disputes and corrections

Members may raise disputes through the supported process. A non-conflicted organizer may review and resolve a dispute.

If the organizer is a party to the dispute or a beneficiary of the affected payout, an independent authorized reviewer is required. Reviewer appointment and authority remain unresolved; until resolved, a conflicted dispute must remain open/escalated and an affected payout must remain held where correctness requires it.

Accepted corrections preserve the original financial record and create linked append-only corrective or reversal records. An internal dispute decision is not proof of a provider refund. Any movement of money must be separately authorized and verified.

## 7. Privacy and access

Members may access information they are authorized to see, including their own relevant financial history, obligations, disputes, and reconciliation information.

Membership does not grant access to another member's private banking information, authentication credentials, or otherwise restricted personal data.

The backend, not the client interface or AI assistant, determines authorization. AI-generated explanations do not override authoritative financial records or permissions.

This draft is not a privacy notice and does not define data retention, legal basis, or all personal-data handling. No separate approved privacy notice or data-retention document exists in the repository. Before publication, create and approve `docs/policies/PRIVACY_NOTICE.md` and `docs/policies/DATA_RETENTION_POLICY.md` through product and appropriate legal review, then link their approved versions here. Do not invent legal conclusions or retention periods in this draft.

## 8. Rules changes and acceptance

Each circle must reference an approved, immutable rules version. The version is stored per circle and controlled by the backend; clients cannot create or select an authoritative version by supplying a string.

Accepting a version means accepting the exact content identified by that version. Earlier acceptance records must be preserved.

New members must accept the current version. A project-level rules publisher proposes each update's `MATERIAL` or `NON_MATERIAL` classification, rationale, and affected actions; a distinct authorized reviewer approves the exact content digest and classification. Non-material changes do not force existing members to reaccept. Material changes require affected members to accept the new version before the recorded protected participation actions, such as invitation activity, initiating contribution periods, changing participation settings, or requesting a payout where acceptance is required.

Members who must reaccept retain access to sign in, review and accept the rules, view their own historical contributions and obligations, and access relevant dispute/reconciliation information. Default to read-only circle access while acceptance is pending. A rules update does not change existing financial obligations or transactions.

## 9. Prohibited conduct

Members must not attempt to bypass access controls, falsify payment evidence, manipulate payout order, misuse another person's account, or interfere with financial records.

Suspected errors, unauthorized activity, or disputed transactions should be reported through the supported process.

## 10. Acknowledgment

By accepting this rules version, the member acknowledges that they have been given access to the exact version identified by the acceptance record and agree to participate subject to these rules and the circle's valid, approved configuration.

**Important:** These rules do not replace the specific contribution schedule, payout order, fee disclosures, privacy notice, dispute procedure, or other terms that must be explicitly approved and presented where applicable. They must not be used to introduce undisclosed fees or new financial obligations.

## Approval required before publication

This draft is not an authoritative rules document. Before publishing proposed version `ajo-circle-rules-1.0.0`, the Ajo project must resolve the independent dispute-reviewer appointment, create and approve the privacy notice and data-retention policy through product/legal review, resolve the payout-order lock point and amendment policy, and verify that actual fee disclosures, circle schedules, and payout order are presented separately where applicable.

The project owner, as project governance authority, must explicitly appoint a project-level `rules_publisher` and a distinct independent `rules_reviewer`; neither role is inherited from circle organizer status. Record each appointee's verified account ID, permission, appointing authority, appointment timestamp, and scope/expiry. Record publication approval against the exact version ID and content digest, with publisher, reviewer, materiality classification, rationale, affected actions, decision, and UTC timestamps. Any content/classification change invalidates prior approval and requires review again.

After explicit two-person approval, commit an immutable copy under `docs/architecture/circle-rules/` and configure circles explicitly. The proposed privacy/retention paths are not present yet. No immutable rules copy, authoritative version ID, publisher, or reviewer is currently approved/appointed. Do not seed or use the proposed version as an approved runtime default.