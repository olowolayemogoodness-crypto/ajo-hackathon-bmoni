# Ajo Backend

Python 3.12 modular-monolith API. The backend is the intended authority for persisted product and financial facts; this foundation does not yet implement financial routes.

## Local setup

From `backend/`, create a virtual environment, install the pinned development dependencies, and configure `AJO_DATABASE_URL` from `.env.example` or the process environment. Do not put service-account credentials in the repository; Firebase authentication is added in the next milestone and uses Application Default Credentials.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
$env:AJO_DATABASE_URL = "postgresql+psycopg://localhost:5432/ajo"
python -m uvicorn app.main:app --reload
```

`GET /health` is a liveness check and does not touch PostgreSQL. `GET /ready` checks the configured database connection. Alembic is configured under `migrations/`; create and review a migration when its owning model milestone is approved. The API never creates tables automatically at startup.

## Tests

```powershell
python -m pytest
ruff check .
```

Foundation tests inject SQLite in memory so liveness/readiness behavior can be tested without a local PostgreSQL service. They do not replace PostgreSQL integration tests for migrations, constraints, locks, or transaction behavior.