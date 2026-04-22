# Pack: Python

> Rules and conventions for Python developers on the team.

---

## Architecture Rules

- Domain-based organization: each module is a package with an explicit `__init__.py`
- Separation of responsibilities: routers/views → services → repositories
- Dependency injection via constructors or FastAPI Depends()
- Centralized configuration with pydantic-settings or python-decouple
- Avoid circular imports: design the dependency hierarchy from the start
- Type hints required on public functions

## Code Quality Rules

- Type hints required on all public functions
- Docstrings on domain functions/classes (one line is enough for simple functions)
- Names in snake_case, classes in PascalCase
- Short functions with a single responsibility
- Avoid mutating input parameters
- Never silently ignore exceptions (bare `except: pass` forbidden)
- f-strings for string formatting, never concatenation with +

## Thinking Rules

- Prefer the most readable solution over the most "Pythonic" one if there's a clarity trade-off
- Avoid premature abstractions: make it work first, then abstract
- Think about the function contract (inputs/outputs) before implementing
- Consider the execution context: sync vs async, CPU-bound vs I/O-bound
- Validate type assumptions at the system boundary, not in every internal function
