# Ajo Intelligence Boundary (Draft)

- **Status:** Proposed boundary; no backend intelligence service exists in the inspected repository
- **Placement recommendation:** Internal module in the proposed modular monolith
- **Implementation sequence:** After identity, authorization, and deterministic reporting

## 1. Current baseline

The Flutter app currently calls a deterministic keyword/template engine that reads the process-local demo store. It is read-only and uses seeded financial facts, but it is not a backend API, an LLM integration, or a server-side authorization boundary. There is no model provider, retrieval system, prompt evaluator, or inference timeout policy in the checkout.

Keep the current local assistant available as part of the demo until a separately approved integration milestone. Do not describe it as model-backed AI.

## 2. Trust boundary

1. Authenticate and authorize the caller in the backend before handling an assistant request.
2. Resolve the caller's internal user ID from verified request context; never accept identity or role from the question body.
3. Authorize the requested circle and permitted reporting period before loading facts.
4. Have deterministic reporting functions calculate amounts, statuses, dates, payout readiness, and history evidence.
5. Construct a purpose-built fact bundle containing only data needed to answer the question.
6. Pass that bundle, not database credentials or unrestricted records, to the intelligence component.
7. Return an answer that is traceable to authorized facts and cannot perform mutations.

The model, if later selected, is an explanation layer, not the financial authority.

## 3. Permitted capabilities

The eventual assistant may:

- Explain the authenticated member's next contribution and due date.
- Explain the next payout recipient, status, and release conditions.
- Summarize expected and confirmed circle totals for an authorized period.
- Explain the caller's own outstanding obligations.
- Describe recorded contribution history with sample size, timing evidence, and limitations.
- State when data is missing, inconsistent, stale, or outside its permissions.
- Ask a clarifying question or refuse unsupported/private requests.

It must not:

- Independently calculate an authoritative total or decide that a payment is confirmed.
- Create, confirm, reverse, allocate, or reconcile a financial event.
- Approve, submit, or settle a payout.
- Change payout order, membership, rules, or a ledger record.
- Reveal another member's private bank/account details or non-shared personal data.
- Infer trustworthiness, fraud, intent, or a predictive risk score from sparse history.
- Treat user-supplied references, balances, or assertions as verified evidence.

## 4. Proposed request/response contract

Request proposal for a future `POST /v1/assistant/queries`:

```json
{
  "circleId": "cir_opaque",
  "question": "Why is the current payout held?",
  "language": "en"
}
```

The authenticated caller is derived from the bearer token, not the request. Proposed response:

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

`sources` must contain only resource identifiers the caller is authorized to see. Whether user-facing answers include source detail and which languages ship in the MVP require product approval. `factsAsOf` is UTC and communicates the age of the underlying report, not model training time.

## 5. Fact-bundle boundary

The reporting module should expose narrow typed facts, for example:

- Circle/period identifiers and authorized display names.
- Expected, confirmed, and outstanding integer-kobo totals calculated from authoritative records.
- Caller-specific obligations and their derived statuses.
- Original due instant, grace deadline, and verified payment timing status under the approved `Africa/Lagos`/UTC policy.
- Payout recipient/order as recorded, current payout state, and unmet release conditions.
- Contribution-history counts, timestamps, and explicit sample-size limitations.
- Fact timestamp and source record identifiers.

Do not include payment credentials, bank account numbers, unrestricted member profiles, raw provider payloads, or unrelated circles. Omit private fields before model invocation, not merely from the final response.

## 6. Reliability explanations

- Report recorded facts and sample size; do not convert them into a credit/trust score.
- Distinguish late-but-resolved payments from unresolved/missed obligations.
- Do not assert intent or predict future behavior from a small number of periods.
- Explain the current calculation and its date window; sparse history must visibly indicate uncertainty.
- Reliability facts cannot affect payout order or membership unless a separately approved product policy explicitly says so; current recommendation is that they do not.

## 7. Safety, privacy, and failure behavior

- Prompt injection and requests to ignore access controls do not alter the authorized fact bundle.
- Requests for another member's private account details are refused without disclosing whether hidden data exists.
- Requests to invent transaction references or claim provider confirmation are refused or answered from verified facts only.
- Requests to initiate payment or alter payout state explain that the assistant cannot perform those actions and direct the user to the authorized workflow.
- Missing/conflicting facts produce a clear unavailable/needs-review answer, not a guessed value.
- Define request size limits, timeouts, rate limits, retention, redaction, and provider-data policy before connecting an external model.
- Model/provider unavailability must not block core ledger or simulated payment flows.

## 8. Evaluation gate before model use

Before adding a model provider, build deterministic tests for correct answers from known ledger facts, authorization filtering, private-data refusal, conflicting/stale source facts, fabricated references, payment mutation requests, payout-order requests, prompt injection, unsupported questions, sparse history, and provider timeout. Compare extracted factual claims to the reporting facts. Tests must demonstrate the assistant cannot change state.

## 9. Sequence and dependencies

1. Approve API identity and circle-level authorization.
2. Implement deterministic reporting functions and their tests.
3. Define and test the fact-bundle schema.
4. Add a read-only assistant endpoint using deterministic templates if that meets MVP needs.
5. Consider a model only if the product requirement cannot be met adequately with deterministic responses and the evaluation/privacy gates pass.
