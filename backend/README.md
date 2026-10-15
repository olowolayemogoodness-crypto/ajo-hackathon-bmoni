# Ajo Backend

Python 3.12 modular-monolith API. The backend is the intended authority for persisted product and financial facts; this foundation does not yet implement financial routes.

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