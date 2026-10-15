# Stage 2B.2 Membership and Invitation Decisions

- **Status:** Approved for Stage 2B.2 based on requester decisions on 2026-10-15
- **Scope:** Invitation, capacity, membership lifecycle, organizer continuity, and rules acceptance
- **Authority:** Supplements the approved baseline in [`STAGE_1_ARCHITECTURE_DECISIONS.md`](STAGE_1_ARCHITECTURE_DECISIONS.md) for Stage 2B.2 only

## Invitation policy

- Invitation TTL is 7 days (168 hours) from creation. Expire at or after `expires_at`, evaluated using the backend UTC clock.
- Invitations are single-use by default. An organizer may explicitly request a configured positive maximum-use count when the API supports it; do not make multi-use the default.
- Consume a use only in the same committed transaction as successful membership creation/reactivation and lifecycle-event creation. Failed or rolled-back acceptance does not consume a use.
- Enforce usage limits with PostgreSQL concurrency control. Reject expired, revoked, exhausted, wrong-circle, ineligible, and duplicate active-member acceptance.
- Generate a high-entropy token, store only a secure hash where feasible, return the raw token only at creation, and never log it. An authorized organizer may revoke an invitation before expiry.

## Circle capacity

- Each circle has an explicit positive integer `max_members` that includes the organizer and every active member. Missing or null capacity is invalid, not unlimited.
- A circle cannot be created/activated for invitation use without valid capacity. Invitation acceptance rejects when active membership count has reached capacity.
- Pending invitations do not count as members. Only active memberships consume capacity; inactive and revoked memberships do not.
- Only an authorized active organizer may change capacity. Reject reductions below current active-member count and audit successful changes.
- Serialize capacity changes and membership acceptance in PostgreSQL so concurrent operations cannot exceed capacity.

## Membership lifecycle and audit

- Preserve one stable membership row per `(circle_id, user_id)`. A returning member must receive a fresh valid invitation, authenticate, accept the current rules version, and pass all current checks. Reactivation is part of that successful acceptance transaction; it is never a direct self-service status change.
- Preserve every tenure in append-only lifecycle events. Events include stable event, circle, membership, and user IDs; UTC time; actor; action; previous/resulting status; relevant invitation and accepted rules version; request/correlation ID; and required reason.
- Organizer status is not inherited on rejoin. Returning members rejoin as ordinary members and require a separate authorized promotion to become organizers.
- An active organizer may revoke another active member with a non-empty bounded reason. Organizers cannot use the revoke operation on themselves.
- An active member may leave their own circle without approval; a reason is optional. Members cannot revoke, suspend, or modify another member.
- Preserve financial obligations, contributions, reversals, disputes, payouts, and audit history on departure/revocation. Membership changes do not settle, cancel, erase, or reverse financial state.
- Commit membership transitions and audit events atomically. Repeated requests must be idempotent or return a safe conflict without contradictory history.

## Organizer continuity

- The final active organizer cannot leave or be revoked while the circle remains operational.
- Before departure or revocation, an eligible active member must be explicitly promoted to organizer. Never transfer organizer privileges implicitly.
- Promotion/transfer and subsequent departure/revocation are separately authorized, audited, and transactionally safe. If the circle is formally closed, use a separate authorized closure workflow.
- A revoked member cannot simply reactivate. Rejoining requires a new invitation and fresh acceptance. A member who left voluntarily follows the same rejoin path.
- Inactive memberships cannot access protected resources. Reactivation, if allowed by a future authorized workflow, requires an audited reason and eligibility/capacity checks; revoked status is not ordinary suspension.

## Rules acceptance and remaining release gate

- The authoritative current rules version is mandatory and stored per circle. It is backend-controlled; clients cannot create or select an authoritative version.
- Do not treat the API-contract example `rules_v1` as approved or use it as a default. Missing or invalid current rules configuration fails closed for invitation acceptance and circle activation.
- Acceptance submits the exact current version and is checked in the same transaction as invitation consumption and membership activation/reactivation. Record immutable evidence associating circle, membership, user, version, UTC time, and event.
- Every version must reference an actual immutable rules document or canonical content revision retrievable by the backend. A rules update is audited with old/new version, actor, time, and reason; prior acceptance evidence is preserved.
- **Still unresolved:** the initial rules document/version and authorized publishing workflow have not been supplied. Also unresolved is whether a rules update affects only future joiners or requires existing members to reaccept, and which actions require reacceptance. Until decided, do not publish/update rules or enable invitation acceptance against invented content.

## Required Stage 2B.2 PostgreSQL tests

- Expiry at the exact boundary, revocation, single-use and configured multi-use limits, and acceptance rollback.
- Concurrent accepts at the final invitation use and final capacity slot.
- Missing capacity, capacity shrink below active membership, and concurrent capacity/member changes.
- New join, rejoin after leaving, rejoin after revocation, duplicate/repeated requests, and no restoration of organizer role.
- Organizer revocation with/without reason, member self-leave, unauthorized cross-member changes, and final-organizer protection under concurrency.
- Membership/audit atomicity, immediate access loss after revocation/leave, preservation of prior tenure events and financial records.
- Missing rules configuration and exact-version mismatch fail closed; acceptance event records the version actually accepted.