---
name: backend-dotnet-api
description: >
  REST API design patterns with ASP.NET Core: controllers, services, middleware, model validation, error handling.
  Trigger: When creating endpoints, defining routes, implementing middleware, or handling HTTP errors in C#/.NET.
globs:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/Program.cs"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Creating or modifying API controllers or minimal API endpoints in ASP.NET Core.
- Registering services, repositories, or validators in the DI container (`IServiceCollection`).
- Building or extending the middleware pipeline (`Program.cs` / `Startup.cs`).
- Implementing input validation with FluentValidation (`AbstractValidator<T>`).
- Designing error handling that returns RFC 9457 ProblemDetails responses.
- Setting up the repository pattern over Entity Framework Core (`DbContext`, `DbSet<T>`).

---

## Critical Patterns

### Pattern 1: Thin Controller — Business Logic in Services

Controllers are HTTP adapters. They parse the request, delegate to a service, and map the result to an HTTP response. **Zero** domain logic belongs in a controller.

❌ **Bad — logic in the controller:**

```csharp
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly AppDbContext _db;

    public OrdersController(AppDbContext db) => _db = db;

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderRequest req)
    {
        // Business rules leaked into the controller
        if (req.Items.Count == 0)
            return BadRequest("Order must have at least one item.");

        var total = req.Items.Sum(i => i.Price * i.Quantity);
        if (total > 10_000)
            return BadRequest("Order exceeds maximum allowed total.");

        var order = new Order { Total = total, Items = req.Items };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
    }
}
```

✅ **Good — controller delegates to a service:**

```csharp
// --- Service layer (injected via DI) ---
public interface IOrderService
{
    Task<OrderDto> CreateAsync(CreateOrderRequest request);
}

public class OrderService : IOrderService
{
    private readonly IRepository<Order> _repo;

    public OrderService(IRepository<Order> repo) => _repo = repo;

    public async Task<OrderDto> CreateAsync(CreateOrderRequest request)
    {
        if (request.Items.Count == 0)
            throw new ValidationException("Order must have at least one item.");

        var total = request.Items.Sum(i => i.Price * i.Quantity);
        if (total > 10_000)
            throw new BusinessRuleException("Order exceeds maximum allowed total.");

        var order = new Order { Total = total, Items = request.Items };
        await _repo.AddAsync(order);
        return order.ToDto();
    }
}

// --- Registration in Program.cs ---
builder.Services.AddScoped<IOrderService, OrderService>();

// --- Controller ---
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orders;

    public OrdersController(IOrderService orders) => _orders = orders;

    [HttpPost]
    public async Task<IActionResult> Create(CreateOrderRequest req)
    {
        var dto = await _orders.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = dto.Id }, dto);
    }
}
```

> **Rule of thumb:** if you can't describe what the controller method does in one sentence starting with "delegates to…", it's doing too much.

---

### Pattern 2: Input Validation with FluentValidation

Use `FluentValidation` with DI auto-registration. Validate explicitly in the controller or service — do NOT rely on the automatic MVC pipeline filter (it was removed in FluentValidation 11+).

✅ **Validator definition:**

```csharp
public record CreateOrderRequest(List<OrderItemDto> Items);

public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderRequestValidator()
    {
        RuleFor(x => x.Items)
            .NotEmpty()
            .WithMessage("Order must contain at least one item.");

        RuleForEach(x => x.Items).ChildRules(item =>
        {
            item.RuleFor(i => i.Price).GreaterThan(0);
            item.RuleFor(i => i.Quantity).InclusiveBetween(1, 1000);
        });
    }
}
```

✅ **Registration (Program.cs):**

```csharp
using FluentValidation;

builder.Services.AddValidatorsFromAssemblyContaining<CreateOrderRequestValidator>();
```

✅ **Usage in controller (explicit call):**

```csharp
[HttpPost]
public async Task<IActionResult> Create(
    [FromBody] CreateOrderRequest req,
    [FromServices] IValidator<CreateOrderRequest> validator)
{
    var result = await validator.ValidateAsync(req);
    if (!result.IsValid)
        return ValidationProblem(new ValidationProblemDetails(result.ToDictionary()));

    var dto = await _orders.CreateAsync(req);
    return CreatedAtAction(nameof(GetById), new { id = dto.Id }, dto);
}
```

✅ **Usage in minimal API endpoint:**

```csharp
app.MapPost("/api/orders", async (
    IValidator<CreateOrderRequest> validator,
    IOrderService orders,
    CreateOrderRequest req) =>
{
    var result = await validator.ValidateAsync(req);
    if (!result.IsValid)
        return Results.ValidationProblem(result.ToDictionary());

    var dto = await orders.CreateAsync(req);
    return Results.Created($"/api/orders/{dto.Id}", dto);
});
```

---

### Pattern 3: Centralized Error Handling with Exception Middleware + ProblemDetails

Never let raw exceptions leak to the client. Use `AddProblemDetails()` and `UseExceptionHandler` to produce RFC 9457 responses for every unhandled exception.

✅ **Program.cs setup:**

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
    };
});

builder.Services.AddControllers();
// ... other registrations ...

var app = builder.Build();

app.UseExceptionHandler(exceptionApp =>
{
    exceptionApp.Run(async context =>
    {
        var problemDetailsService =
            context.RequestServices.GetRequiredService<IProblemDetailsService>();
        var exception =
            context.Features.Get<IExceptionHandlerFeature>()?.Error;

        var (status, title) = exception switch
        {
            ValidationException     => (StatusCodes.Status422UnprocessableEntity, "Validation failed"),
            BusinessRuleException   => (StatusCodes.Status409Conflict, "Business rule violation"),
            NotFoundException       => (StatusCodes.Status404NotFound, "Resource not found"),
            UnauthorizedAccessException => (StatusCodes.Status403Forbidden, "Forbidden"),
            _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred")
        };

        context.Response.StatusCode = status;

        await problemDetailsService.WriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            ProblemDetails =
            {
                Status = status,
                Title = title,
                Detail = exception?.Message,
                Type = $"https://httpstatuses.io/{status}"
            }
        });
    });
});

app.UseAuthorization();
app.MapControllers();
app.Run();
```

✅ **Client receives consistent RFC 9457 JSON:**

```json
{
  "type": "https://httpstatuses.io/409",
  "title": "Business rule violation",
  "status": 409,
  "detail": "Order exceeds maximum allowed total.",
  "traceId": "00-abc123..."
}
```

---

### Pattern 4: Repository Pattern with EF Core

Abstract data access behind `IRepository<T>` so services never depend on `DbContext` directly. This makes unit testing trivial — mock the repository, not the ORM.

✅ **Generic repository interface:**

```csharp
public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(int id);
    Task<IReadOnlyList<T>> ListAsync();
    Task<IReadOnlyList<T>> ListAsync(Expression<Func<T, bool>> predicate);
    Task AddAsync(T entity);
    void Update(T entity);
    void Remove(T entity);
    Task SaveChangesAsync();
}
```

✅ **EF Core implementation:**

```csharp
public class EfRepository<T> : IRepository<T> where T : class
{
    private readonly AppDbContext _db;
    private readonly DbSet<T> _set;

    public EfRepository(AppDbContext db)
    {
        _db = db;
        _set = db.Set<T>();
    }

    public async Task<T?> GetByIdAsync(int id) => await _set.FindAsync(id);
    public async Task<IReadOnlyList<T>> ListAsync() => await _set.ToListAsync();
    public async Task<IReadOnlyList<T>> ListAsync(Expression<Func<T, bool>> predicate)
        => await _set.Where(predicate).ToListAsync();
    public async Task AddAsync(T entity) => await _set.AddAsync(entity);
    public void Update(T entity) => _set.Update(entity);
    public void Remove(T entity) => _set.Remove(entity);
    public async Task SaveChangesAsync() => await _db.SaveChangesAsync();
}
```

✅ **Registration:**

```csharp
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
```

---

## Anti-Patterns

### Anti-Pattern 1: Business Logic in Controllers

When controllers contain domain rules, you end up duplicating logic across endpoints, making it untestable without spinning up the full HTTP pipeline.

❌ **Bad:**

```csharp
[HttpPut("{id}")]
public async Task<IActionResult> Cancel(int id)
{
    var order = await _db.Orders.FindAsync(id);
    if (order is null) return NotFound();

    // Business rule buried in controller
    if (order.Status == OrderStatus.Shipped)
        return BadRequest("Cannot cancel a shipped order.");

    order.Status = OrderStatus.Cancelled;
    order.CancelledAt = DateTime.UtcNow;
    await _db.SaveChangesAsync();
    return NoContent();
}
```

✅ **Good — service owns the rule:**

```csharp
// Service
public async Task CancelAsync(int id)
{
    var order = await _repo.GetByIdAsync(id)
        ?? throw new NotFoundException($"Order {id} not found.");

    if (order.Status == OrderStatus.Shipped)
        throw new BusinessRuleException("Cannot cancel a shipped order.");

    order.Status = OrderStatus.Cancelled;
    order.CancelledAt = DateTime.UtcNow;
    await _repo.SaveChangesAsync();
}

// Controller
[HttpPut("{id}/cancel")]
public async Task<IActionResult> Cancel(int id)
{
    await _orders.CancelAsync(id);
    return NoContent();
}
```

---

### Anti-Pattern 2: Returning Raw Exceptions to Clients

Leaking stack traces or exception types to clients is a security risk and provides a poor developer experience for API consumers.

❌ **Bad — raw exception serialized:**

```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id)
{
    try
    {
        var order = await _orders.GetByIdAsync(id);
        return Ok(order);
    }
    catch (Exception ex)
    {
        // Leaks internal details: stack trace, connection strings, class names
        return StatusCode(500, new { error = ex.ToString() });
    }
}
```

✅ **Good — let the exception middleware handle it with ProblemDetails:**

```csharp
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id)
{
    // No try/catch needed — the exception middleware
    // converts unhandled exceptions to ProblemDetails (RFC 9457)
    var order = await _orders.GetByIdAsync(id);
    return Ok(order);
}
```

The centralized exception handler (Pattern 3) maps exceptions to appropriate status codes and produces a safe, structured response — never exposing internals.

---

## Quick Reference

| Concept                | Recommendation                                                        |
| ---------------------- | --------------------------------------------------------------------- |
| **Controller role**    | HTTP adapter only — parse request, delegate, map response             |
| **Business logic**     | Lives in service classes registered as `Scoped` in DI                 |
| **Validation**         | FluentValidation `AbstractValidator<T>`, explicit call, not auto-pipe |
| **Error responses**    | `AddProblemDetails()` + `UseExceptionHandler` — RFC 9457              |
| **Data access**        | `IRepository<T>` over EF Core `DbContext`                             |
| **DTOs**               | C# `record` types — immutable, value equality, concise                |
| **DI lifetimes**       | `Scoped` for services/repos, `Transient` for validators              |
| **Middleware order**    | ExceptionHandler → Auth → Routing → Endpoints                        |
| **Status code mapping** | Validation → 422, NotFound → 404, BusinessRule → 409, Unknown → 500 |
| **Testing**            | Mock `IRepository<T>` and `IValidator<T>` — no DB or HTTP needed     |
