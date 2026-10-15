# Ajo Circle Participation Rules

- **Proposed version:** `ajo-circle-rules-1.0.0`
- **Status:** Draft pending explicit approval; not authoritative
- **Scope:** Membership, participation, contributions, payouts, disputes, privacy, and circle governance

## 1. Membership and eligibility

Participation in an Ajo circle requires authentication, a valid invitation where required, explicit acceptance of the circle's current approved rules, and successful backend validation.

Membership is subject to the circle's configured capacity and eligibility requirements. Previous membership does not guarantee automatic re-entry after leaving or revocation.

Members must keep their account and participation information accurate.

## 2. Contributions and financial records

Contribution amounts, schedules, due dates, grace periods, confirmed payments, outstanding obligations, and payout eligibility are determined by the authoritative backend records and approved circle configuration.

Amounts are represented internally in integer kobo. A payment is not confirmed merely because a member reports making it, a client displays success, or a request times out.

Historical financial records must not be silently deleted or overwritten. Corrections and reversals must be recorded as linked, auditable events.

Members must not assume that leaving a circle cancels an existing financial obligation.

## 3. Payment and payout safety

Payouts are subject to the circle's approved payout order, applicable eligibility requirements, required approvals, and verified financial state.

A payout may be held when required contributions, approvals, reconciliation, or other release conditions remain unresolved.

No member or organizer may bypass backend release conditions, impersonate another member, or treat an uncertain provider result as proof that a transfer succeeded.

## 4. Organizer responsibilities and accountability

Organizers administer membership and circle settings only within their authorized permissions.

Organizer actions affecting membership, rules, schedules, approvals, and other protected operations are subject to backend authorization and audit requirements.

An organizer must not approve their own payout where independent approval is required. Conflicted disputes must follow the circle's approved independent-review procedure.

The final active organizer must not leave or be removed without an authorized succession or circle-closure procedure.

## 5. Leaving, removal, and rejoining

Members may leave their circle through the approved backend process, subject to applicable governance and financial safeguards.

Authorized organizers may revoke another member's membership only through the permitted, audited procedure.

Rejoining requires the applicable invitation, authentication, fresh acceptance of the current rules, and successful eligibility and capacity checks. Previous membership does not automatically restore access or organizer privileges.

Membership changes must not erase financial history or settle outstanding obligations automatically.

## 6. Disputes and corrections

Members may raise disputes through the supported process.

Disputes must be reviewed by an authorized, non-conflicted reviewer. Where the ordinary reviewer is conflicted, the approved independent-review or escalation procedure applies.

Accepted corrections must preserve the original financial record and create linked corrective or reversal records. Any movement of money must be separately authorized and verified.

## 7. Privacy and access

Members may access information they are authorized to see, including their own relevant financial history and obligations.

Membership does not grant access to another member's private banking information, authentication credentials, or otherwise restricted personal data.

The backend, not the client interface or AI assistant, determines authorization. AI-generated explanations do not override authoritative financial records or permissions.

## 8. Rules changes and acceptance

Each circle must reference an approved, immutable rules version.

Accepting a version means accepting the exact content identified by that version. Earlier acceptance records must be preserved.

New members must accept the current version. Existing members must reaccept material changes according to the approved reacceptance policy. A rules update must not silently imply consent.

Members who must reaccept should retain access to the rules and to relevant historical financial, dispute, and reconciliation information.

## 9. Prohibited conduct

Members must not attempt to bypass access controls, falsify payment evidence, manipulate payout order, misuse another person's account, or interfere with financial records.

Suspected errors, unauthorized activity, or disputed transactions should be reported through the supported process.

## 10. Acknowledgment

By accepting this rules version, the member acknowledges that they have been given access to the exact version identified by the acceptance record and agree to participate subject to these rules and the circle's valid, approved configuration.

**Important:** These rules do not replace the specific contribution schedule, payout order, fee disclosures, privacy notice, dispute procedure, or other terms that must be explicitly approved and presented where applicable. They must not be used to introduce undisclosed fees or new financial obligations.

## Approval required before publication

This draft is not an authoritative rules document. Before publishing proposed version `ajo-circle-rules-1.0.0`, the Ajo project must review the text against the approved partial-payment and late-payment policies, payout approval and alternate-approver requirements, independent dispute-reviewer authority, privacy/data-retention/legal requirements, and affected actions for material changes.

The project must appoint a rules publisher and record approval. After approval, commit an immutable copy under `docs/architecture/circle-rules/`, record its content digest and approval evidence, and configure circles explicitly. Do not seed or use the proposed version as an approved runtime default.