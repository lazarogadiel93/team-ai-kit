---
name: backend-dotnet-testing
description: >
  Testing patterns for ASP.NET Core applications: xUnit, NSubstitute/Moq, integration tests, WebApplicationFactory.
  Trigger: When writing tests, mocking dependencies, or setting up test infrastructure in C#/.NET.
globs:
  - "**/*Tests.cs"
  - "**/*Test.cs"
  - "**/*.Tests/**/*.cs"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Writing unit tests with xUnit + NSubstitute (or Moq)
- Writing integration tests with `WebApplicationFactory<Program>`
- Testing EF Core repositories with InMemory provider or Testcontainers
- Setting up test infrastructure, fixtures, or shared context in a .NET solution
- Adding FluentAssertions for readable test output

---

## Critical Patterns

### Pattern 1: Unit Tests with xUnit + NSubstitute — Arrange-Act-Assert

Use `Substitute.For<T>()` to create test doubles. Inject them via constructor.
Always follow Arrange-Act-Assert structure with clear separation.

```csharp
using NSubstitute;
using FluentAssertions;

public class OrderServiceTests
{
    private readonly IOrderRepository _orderRepository;
    private readonly IPaymentGateway _paymentGateway;
    private readonly OrderService _sut;

    public OrderServiceTests()
    {
        // Arrange — shared setup via constructor (xUnit creates new instance per test)
        _orderRepository = Substitute.For<IOrderRepository>();
        _paymentGateway = Substitute.For<IPaymentGateway>();
        _sut = new OrderService(_orderRepository, _paymentGateway);
    }

    [Fact]
    public async Task PlaceOrder_ValidOrder_PersistsAndReturnsId()
    {
        // Arrange
        var dto = new CreateOrderDto { ProductId = "P1", Quantity = 2 };
        _orderRepository
            .SaveAsync(Arg.Any<Order>())
            .Returns(callInfo =>
            {
                var order = callInfo.Arg<Order>();
                order.Id = Guid.NewGuid();
                return order;
            });

        _paymentGateway
            .ChargeAsync(Arg.Any<decimal>())
            .Returns(new PaymentResult { Success = true });

        // Act
        var result = await _sut.PlaceOrderAsync(dto);

        // Assert
        result.Should().NotBeNull();
        result.Id.Should().NotBeEmpty();

        // Verify interactions
        await _orderRepository.Received(1).SaveAsync(Arg.Is<Order>(o => o.Quantity == 2));
        await _paymentGateway.Received(1).ChargeAsync(Arg.Any<decimal>());
    }

    [Fact]
    public async Task PlaceOrder_PaymentFails_ThrowsPaymentException()
    {
        // Arrange
        var dto = new CreateOrderDto { ProductId = "P1", Quantity = 1 };
        _paymentGateway
            .ChargeAsync(Arg.Any<decimal>())
            .Returns(new PaymentResult { Success = false, Error = "Declined" });

        // Act
        var act = () => _sut.PlaceOrderAsync(dto);

        // Assert
        await act.Should().ThrowAsync<PaymentFailedException>()
            .WithMessage("*Declined*");

        await _orderRepository.DidNotReceive().SaveAsync(Arg.Any<Order>());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task PlaceOrder_InvalidQuantity_ThrowsValidationException(int quantity)
    {
        var dto = new CreateOrderDto { ProductId = "P1", Quantity = quantity };

        var act = () => _sut.PlaceOrderAsync(dto);

        await act.Should().ThrowAsync<ValidationException>();
    }
}
```

**Key NSubstitute patterns:**
- `Substitute.For<T>()` — create mock for interface or abstract class
- `.Returns(value)` — set return value for a call
- `.Returns(callInfo => ...)` — dynamic return based on arguments
- `.Received(n).Method(args)` — verify method was called n times
- `.DidNotReceive().Method(args)` — verify method was NOT called
- `Arg.Any<T>()` — match any argument of type T
- `Arg.Is<T>(predicate)` — match argument satisfying a condition

---

### Pattern 2: Integration Tests with WebApplicationFactory

`WebApplicationFactory<Program>` boots your entire ASP.NET Core pipeline in-memory.
Use `IClassFixture<T>` to share the factory across tests in one class.

```csharp
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;

// Custom factory — override services for testing
public class ApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureServices(services =>
        {
            // Remove the real DbContext registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            // Add InMemory database for fast integration tests
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("TestDb_" + Guid.NewGuid()));

            // Replace external services with fakes
            var paymentDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IPaymentGateway));
            if (paymentDescriptor != null) services.Remove(paymentDescriptor);

            services.AddSingleton<IPaymentGateway>(Substitute.For<IPaymentGateway>());
        });
    }
}

public class OrdersEndpointTests : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client;
    private readonly ApiFactory _factory;

    public OrdersEndpointTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    [Fact]
    public async Task CreateOrder_ReturnsCreated()
    {
        // Arrange
        var dto = new { ProductId = "P1", Quantity = 3 };

        // Act
        var response = await _client.PostAsJsonAsync("/api/orders", dto);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        var body = await response.Content.ReadFromJsonAsync<OrderResponse>();
        body.Should().NotBeNull();
        body!.Id.Should().NotBeEmpty();
    }

    [Fact]
    public async Task GetOrder_NotFound_Returns404()
    {
        var response = await _client.GetAsync($"/api/orders/{Guid.NewGuid()}");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CreateOrder_InvalidPayload_Returns400()
    {
        var response = await _client.PostAsJsonAsync("/api/orders", new { });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
```

**Key points:**
- `CreateClient()` gives you an `HttpClient` wired to the in-memory test server — no network, no ports
- Override `ConfigureWebHost` to swap real services (DB, external APIs) with test doubles
- Use `IClassFixture<ApiFactory>` so the host is built ONCE per test class (not per test)
- For shared state across multiple test classes, use `ICollectionFixture<ApiFactory>`

---

### Pattern 3: FluentAssertions for Readable Assertions

FluentAssertions replaces raw `Assert.*` calls with a fluent, discoverable API that produces
clear failure messages. Use it everywhere — unit and integration tests.

```csharp
using FluentAssertions;
using FluentAssertions.Extensions;

// --- Primitives ---
result.Should().Be(42);
name.Should().StartWith("Order").And.EndWith("001");
amount.Should().BeApproximately(99.99m, 0.01m);

// --- Collections ---
orders.Should().HaveCount(3);
orders.Should().ContainSingle(o => o.Status == "Pending");
orders.Should().BeInAscendingOrder(o => o.CreatedAt);
orders.Should().AllSatisfy(o => o.TotalAmount.Should().BePositive());
orders.Select(o => o.Id).Should().OnlyHaveUniqueItems();

// --- Objects ---
actual.Should().BeEquivalentTo(expected, options => options
    .Excluding(o => o.Id)           // ignore auto-generated fields
    .Excluding(o => o.CreatedAt));

// --- Exceptions ---
var act = () => service.Process(null!);
act.Should().Throw<ArgumentNullException>()
    .WithParameterName("input");

// async variant
var asyncAct = () => service.ProcessAsync(null!);
await asyncAct.Should().ThrowAsync<ArgumentNullException>();

// --- HTTP responses (useful in integration tests) ---
response.StatusCode.Should().Be(HttpStatusCode.OK);
var body = await response.Content.ReadFromJsonAsync<OrderResponse>();
body.Should().NotBeNull();
body!.Items.Should().HaveCountGreaterThan(0);

// --- Time assertions ---
order.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, 5.Seconds());
```

**Why FluentAssertions over raw Assert:**
- Failure messages tell you WHAT was expected vs WHAT was found
- Chaining (`.And`) reads like a specification
- `BeEquivalentTo` does deep structural comparison — essential for DTOs

---

### Pattern 4: EF Core Testing — InMemory vs Testcontainers

**Option A: InMemory Provider** — fast, no infrastructure, good for unit-level repository tests.

```csharp
public class ProductRepositoryTests
{
    private AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()) // unique DB per test
            .Options;

        var context = new AppDbContext(options);
        return context;
    }

    [Fact]
    public async Task GetByCategory_ReturnsMatchingProducts()
    {
        // Arrange
        await using var context = CreateContext();
        context.Products.AddRange(
            new Product { Name = "Widget", Category = "Tools" },
            new Product { Name = "Gadget", Category = "Electronics" },
            new Product { Name = "Wrench", Category = "Tools" }
        );
        await context.SaveChangesAsync();

        var repo = new ProductRepository(context);

        // Act
        var results = await repo.GetByCategoryAsync("Tools");

        // Assert
        results.Should().HaveCount(2);
        results.Should().AllSatisfy(p => p.Category.Should().Be("Tools"));
    }
}
```

**Option B: Testcontainers** — real database engine, catches SQL-specific bugs. Use for
integration tests where query behavior matters (joins, transactions, constraints).

```csharp
using Testcontainers.PostgreSql;

public class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder()
        .WithDatabase("testdb")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        // Run EF migrations against the real engine
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;

        await using var context = new AppDbContext(options);
        await context.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();
}

[CollectionDefinition("Database")]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture> { }

[Collection("Database")]
public class ProductRepositoryIntegrationTests
{
    private readonly DatabaseFixture _db;

    public ProductRepositoryIntegrationTests(DatabaseFixture db) => _db = db;

    private AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(_db.ConnectionString)
            .Options;
        return new AppDbContext(options);
    }

    [Fact]
    public async Task GetByCategory_WithRealPostgres_ReturnsCorrectResults()
    {
        await using var context = CreateContext();
        context.Products.Add(new Product { Name = "Bolt", Category = "Hardware" });
        await context.SaveChangesAsync();

        var repo = new ProductRepository(context);
        var results = await repo.GetByCategoryAsync("Hardware");

        results.Should().ContainSingle(p => p.Name == "Bolt");
    }
}
```

**When to use which:**

| Criteria | InMemory | Testcontainers |
|---|---|---|
| Speed | ~ms | ~seconds (container startup) |
| SQL fidelity | Low — no real SQL engine | High — real PostgreSQL/SQL Server |
| Transactions | Not supported | Full support |
| Constraints/indexes | Ignored | Enforced |
| CI friendliness | No Docker needed | Requires Docker |
| Best for | Fast unit tests, simple CRUD | Integration tests, complex queries |

**Rule of thumb:** Use InMemory for fast feedback during development. Use Testcontainers in CI
and for any test that exercises raw SQL, transactions, or database-specific behavior.

---

## Anti-Patterns

### Anti-Pattern 1: Using a Real Database in Unit Tests

```csharp
// WRONG — unit test hits real SQL Server
public class OrderServiceTests
{
    [Fact]
    public async Task PlaceOrder_SavesOrder()
    {
        // This needs a running SQL Server, connection string, migrations...
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer("Server=localhost;Database=TestDb;...")
            .Options;

        var context = new AppDbContext(options);
        var repo = new OrderRepository(context);
        var service = new OrderService(repo, new RealPaymentGateway());

        var result = await service.PlaceOrderAsync(dto);
        // Slow, flaky, requires infrastructure, leaves data behind
    }
}
```

**Why it's wrong:**
- Tests become slow and non-deterministic
- Requires infrastructure to run (can't run on a fresh clone)
- Shared database state causes ordering-dependent test failures
- You're testing infrastructure, not business logic

**Fix:** Mock the repository with NSubstitute for unit tests. Use InMemory or Testcontainers
for integration tests where you NEED the database.

---

### Anti-Pattern 2: Manual HttpClient Instead of WebApplicationFactory

```csharp
// WRONG — starts a real Kestrel server, manages ports, fragile setup
public class ApiTests
{
    [Fact]
    public async Task GetOrders_ReturnsOk()
    {
        // Manual host startup — duplicates Program.cs configuration
        var host = Host.CreateDefaultBuilder()
            .ConfigureWebHostDefaults(b => b.UseStartup<Startup>())
            .Build();
        await host.StartAsync();

        var client = new HttpClient { BaseAddress = new Uri("http://localhost:5000") };
        var response = await client.GetAsync("/api/orders");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        await host.StopAsync();
    }
}
```

**Why it's wrong:**
- Binds to real ports — parallel test runs fail with port conflicts
- Duplicates app startup logic instead of reusing `Program.cs`
- No easy way to replace services (DB, external APIs) for testing
- Manual lifecycle management (`StartAsync`/`StopAsync`) is error-prone

**Fix:** Use `WebApplicationFactory<Program>` — it runs the full pipeline in-memory with no
port binding, shares the real `Program.cs` configuration, and lets you override services cleanly.

---

## Quick Reference

| Topic | Tool / Pattern | Key API |
|---|---|---|
| Test framework | xUnit | `[Fact]`, `[Theory]`, `[InlineData]` |
| Mocking | NSubstitute | `Substitute.For<T>()`, `.Returns()`, `.Received()` |
| Assertions | FluentAssertions | `.Should().Be()`, `.BeEquivalentTo()`, `.Throw()` |
| Integration tests | WebApplicationFactory | `WebApplicationFactory<Program>`, `CreateClient()` |
| Fast DB tests | EF Core InMemory | `UseInMemoryDatabase("name")` |
| Real DB tests | Testcontainers | `PostgreSqlBuilder`, `MsSqlBuilder` |
| Shared fixture | xUnit | `IClassFixture<T>`, `ICollectionFixture<T>` |
| Async lifecycle | xUnit | `IAsyncLifetime` (`InitializeAsync` / `DisposeAsync`) |

### Project Structure Convention

```
src/
  MyApp.Api/
  MyApp.Domain/
  MyApp.Infrastructure/
tests/
  MyApp.UnitTests/           # Fast, mocked, no infrastructure
    Services/
      OrderServiceTests.cs
  MyApp.IntegrationTests/    # WebApplicationFactory, InMemory DB
    Endpoints/
      OrdersEndpointTests.cs
    Fixtures/
      ApiFactory.cs
  MyApp.FunctionalTests/     # Testcontainers, real DB engine
    Repositories/
      ProductRepositoryTests.cs
    Fixtures/
      DatabaseFixture.cs
```

### NuGet Packages

```xml
<!-- Unit + Integration tests -->
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
<PackageReference Include="xunit" Version="2.*" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
<PackageReference Include="NSubstitute" Version="5.*" />
<PackageReference Include="FluentAssertions" Version="7.*" />

<!-- Integration tests with WebApplicationFactory -->
<PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.*" />

<!-- EF Core InMemory -->
<PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="8.*" />

<!-- Testcontainers (pick your DB) -->
<PackageReference Include="Testcontainers.PostgreSql" Version="3.*" />
<PackageReference Include="Testcontainers.MsSql" Version="3.*" />
```
