# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- The section 13 synthetic scenario is defined in `lib/data/mock/seed_data.dart`; keep demo identities, contribution history, and payout order deterministic there rather than duplicating fixtures in screens.
- Ledger status, reliability, and reminder rules live in `lib/data/logic/`. Keep them side-effect free and cover rule changes with focused tests under `test/`.
- Money values are integer kobo throughout. Payment providers must implement `lib/data/payments/payments_adapter.dart`, preserve idempotency, and label simulations clearly.
- Validate changes with `flutter analyze` and `flutter test`.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
