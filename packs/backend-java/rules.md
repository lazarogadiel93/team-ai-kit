# Pack: Backend Java (Spring Boot)

> Rules and conventions for Java/Spring Boot backend developers.

---

## Architecture Rules

- Follow layered architecture: Controller → Service → Repository
- Controllers handle HTTP concerns only — no business logic
- Services contain all business logic
- Repositories handle data access only
- Use DTOs (record classes) for API request/response — never expose entities

## Code Quality Rules

- Use constructor injection — never field injection with `@Autowired`
- Prefer `Optional<T>` returns from repositories over null checks
- Use `@Transactional` at the service layer, not the controller
- Always validate input with Jakarta Bean Validation (`@Valid`)
- Use `@ControllerAdvice` for centralized error handling

## Testing

- Every service method must have a unit test
- Use `@SpringBootTest` only for integration tests — prefer plain JUnit 5 + Mockito for unit tests
- Use Testcontainers for database integration tests
- Use AssertJ for fluent, readable assertions

## Naming

- Controllers: `*Controller.java`
- Services: `*Service.java` (interface) + `*ServiceImpl.java`
- Repositories: `*Repository.java`
- DTOs: `*Request.java`, `*Response.java`
- Tests: `*Test.java` (unit), `*IT.java` (integration)

## Thinking Rules

- Design the API contract before implementation (API-first)
- Think about idempotency and error cases before the happy path
- Think about the function contract (inputs/outputs) before implementing
- Validate inputs at the system boundary, not deep inside
- Consider transaction boundaries and data consistency under partial failures
