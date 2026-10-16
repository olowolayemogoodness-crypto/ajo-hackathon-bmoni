# Ajo Backend

Python 3.12 modular-monolith API. The backend is the intended authority for persisted product and financial facts. The one-period contribution/payout flow described below is a local synthetic demo only; no live-provider or real-money routes are implemented.

## Local setup

From `backend/`, create a virtual environment, install the pinned development dependencies, and configure the variables in `.env.example` in your process environment. Do not put service-account credentials in the repository; Firebase Admin uses Application Default Credentials.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
$env:AJO_DATABASE_URL = "postgresql+psycopg://localhost:5432/ajo"
$env:AJO_FIREBASE_PROJECT_ID = "ajo-hackathon"
python -m uvicorn app.main:app --reload
```

`GET /health` is a liveness check and does not touch PostgreSQL. `GET /ready` checks the configured database connection. Alembic is configured under `migrations/`; create and review a migration when its owning model milestone is approved. The API never creates tables automatically at startup.

`POST /v1/session` verifies a Firebase ID token, resolves or creates the internal user by verified Firebase UID, and returns the internal user ID. Resource-level authorization is intentionally deferred until circle membership and role records are implemented. Local tests inject a token verifier and do not require Firebase credentials.

## Tests

```powershell
python -m pytest
ruff check .
```

Foundation tests inject SQLite in memory so liveness/readiness behavior can be tested without a local PostgreSQL service. They do not replace PostgreSQL integration tests for migrations, constraints, locks, or transaction behavior.

The PostgreSQL integration test is opt-in. Set `AJO_TEST_POSTGRES_URL` to a disposable database whose name ends in `_test`; the test refuses other database names and unrelated tables. On each run it resets the test schema to Alembic `base`, applies all migrations, checks PostgreSQL constraints, foreign keys, rollback and concurrency behavior, then verifies a downgrade/upgrade round trip. Do not use a database containing data you need. Then run:

```powershell
$env:AJO_TEST_POSTGRES_URL = "postgresql+psycopg://localhost:5432/ajo_test"
python -m pytest -m postgres
```

The PostgreSQL test also prints the server version so the result can be recorded with the gate. Do not point it at a development or production database.

## Local synthetic demo

The circle create/invite/accept/activate flow and one-period simulated ledger/payout endpoints are available only when the backend is explicitly configured for a local synthetic demo. Start a disposable local PostgreSQL database, then configure these values in the backend process (never commit them):

```powershell
docker run -d --name ajo-demo-db -e POSTGRES_USER=ajo -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=ajo_demo -p 5432:5432 postgres:17
$env:AJO_ENVIRONMENT = "local"
$env:AJO_DATABASE_URL = "postgresql+psycopg://ajo@localhost:5432/ajo_demo"
$env:AJO_FIREBASE_PROJECT_ID = "ajo-hackathon"
$env:AJO_DEMO_MODE = "true"
$env:AJO_SYNTHETIC_DATA = "true"
$env:AJO_DEMO_OPERATOR_FIREBASE_UIDS = "<local-demo-operator-firebase-uid>"
python -m alembic upgrade head
python -m uvicorn app.main:app --reload
```

Demo mode fails closed unless the environment is `local` or `test`, synthetic data is explicitly enabled, and the server-side operator UID allowlist is non-empty. The allowlist grants only simulated contribution and settlement operations; organizer status alone is not sufficient. Keep the actual UID in local environment configuration, not source control.

Run Flutter Web against the local API with `flutter run -d chrome --dart-define=AJO_API_BASE_URL=http://127.0.0.1:8000`. For an Android emulator, use `http://10.0.2.2:8000` as the compile-time API base URL.

The demo uses the distinct, pinned rules version `ajo-demo-rules-1.0.0` in [the local demo rules](../docs/architecture/circle-rules/ajo-demo-rules-1.0.0.md). It is not production rules. Contributions and payout settlement are explicitly labelled simulated, use synthetic records only, and never call a payment provider. The one-period payout recipient is selected before activation and is locked afterward; settlement requires a separate demo-operator API action, never a timer.

The Flutter flow uses `GET /v1/demo/rules` to show the exact rules before the organizer creates a circle and before an invited member accepts. `GET /v1/assistant/queries` is a deterministic, read-only explanation over the same membership-authorized backend summary; it does not use a model or perform financial actions.