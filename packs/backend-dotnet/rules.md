# Pack: Backend .NET (ASP.NET Core)

> Rules and conventions for C#/.NET backend developers.

---

## Architecture Rules

- Follow layered architecture: Controller → Service → Repository
- Controllers handle HTTP concerns only — no business logic
- Services contain all business logic
- Repositories handle data access via EF Core
- Use DTOs (record types) for API request/response — never expose entities

## Code Quality Rules

- Use constructor injection via built-in DI (`IServiceCollection`)
- Prefer async/await for all I/O operations
- Use `ProblemDetails` for consistent error responses
- Always validate input with FluentValidation or Data Annotations
- Use middleware for cross-cutting concerns (logging, auth, error handling)

## Testing

- Every service method must have a unit test
- Use `WebApplicationFactory<Program>` for integration tests
- Use NSubstitute or Moq for mocking dependencies
- Use FluentAssertions for readable assertions
- Use Testcontainers for database integration tests when needed

## Naming

- Controllers: `*Controller.cs`
- Services: `I*Service.cs` (interface) + `*Service.cs`
- Repositories: `I*Repository.cs` + `*Repository.cs`
- DTOs: `*Request.cs`, `*Response.cs`
- Tests: `*Tests.cs` (unit), `*IntegrationTests.cs`

## Thinking Rules

- Design the API contract before implementation (API-first)
- Think about idempotency and error cases before the happy path
- Think about the function contract (inputs/outputs) before implementing
- Validate inputs at the system boundary, not deep inside
- Consider transaction boundaries and data consistency under partial failures
