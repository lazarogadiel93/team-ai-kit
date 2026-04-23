---
name: backend-java-testing
description: >
  Testing patterns for Spring Boot applications: JUnit 5, Mockito, integration tests, testcontainers.
  Trigger: When writing tests, mocking dependencies, or setting up test infrastructure in Java/Spring.
globs:
  - "**/*Test.java"
  - "**/*Tests.java"
  - "**/test/**/*.java"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- Writing unit tests for services or domain logic with JUnit 5 + Mockito
- Testing Spring MVC controllers with `@WebMvcTest` and `MockMvc`
- Writing integration tests that boot the full Spring context with `@SpringBootTest`
- Setting up Testcontainers for database or infrastructure tests
- Choosing the right test slice annotation (`@WebMvcTest`, `@DataJpaTest`, etc.)
- Replacing JUnit `assertEquals` with AssertJ fluent assertions

---

## Critical Patterns

### Pattern 1: Unit Tests with Mockito

Use `@ExtendWith(MockitoExtension.class)` with `@Mock` and `@InjectMocks` for fast, isolated unit tests. **No Spring context is loaded.**

```java
// ❌ BAD: Using @SpringBootTest for a simple service test — loads entire context for no reason
@SpringBootTest
class OrderServiceTest {

    @Autowired
    private OrderService orderService;

    @MockBean
    private OrderRepository orderRepository;

    @Test
    void shouldCalculateTotal() {
        when(orderRepository.findById(1L)).thenReturn(Optional.of(new Order(1L, 100.0)));
        double total = orderService.calculateTotal(1L);
        assertEquals(100.0, total);
    }
}
```

```java
// ✅ GOOD: Plain JUnit 5 + Mockito — fast, no Spring overhead
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private PricingService pricingService;

    @InjectMocks
    private OrderService orderService;

    @Test
    @DisplayName("should calculate total with discount applied")
    void shouldCalculateTotalWithDiscount() {
        // Arrange
        var order = new Order(1L, List.of(new LineItem("SKU-1", 2, 50.0)));
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));
        when(pricingService.getDiscount(any())).thenReturn(0.1);

        // Act
        double total = orderService.calculateTotal(1L);

        // Assert
        assertThat(total).isEqualTo(90.0);
        verify(orderRepository).findById(1L);
        verify(pricingService).getDiscount(any());
    }

    @Test
    @DisplayName("should throw when order not found")
    void shouldThrowWhenOrderNotFound() {
        when(orderRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> orderService.calculateTotal(99L))
            .isInstanceOf(OrderNotFoundException.class)
            .hasMessageContaining("99");
    }
}
```

**Key rules:**
- `@Mock` creates the mock. `@InjectMocks` injects all `@Mock` fields into the constructor.
- Use `verify()` to assert interactions. Use `ArgumentCaptor` when you need to inspect arguments.
- One logical assertion per test. Use `@DisplayName` to describe behavior, not implementation.

---

### Pattern 2: Controller Tests with @WebMvcTest + MockMvc

`@WebMvcTest` loads ONLY the web layer (controllers, filters, advice). Dependencies must be mocked with `@MockitoBean`.

```java
// ❌ BAD: Using @SpringBootTest + @AutoConfigureMockMvc for a controller-only test
@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {
    // Loads the ENTIRE application context — database, services, repos, everything
    @Autowired
    private MockMvc mvc;

    @Test
    void shouldReturnUser() throws Exception {
        mvc.perform(get("/users/1"))
            .andExpect(status().isOk());
    }
}
```

```java
// ✅ GOOD: @WebMvcTest loads only the controller slice
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private UserService userService;

    @Test
    @DisplayName("GET /users/{id} returns user when found")
    void shouldReturnUser() throws Exception {
        given(userService.findById(1L))
            .willReturn(new UserDto(1L, "Alice", "alice@example.com"));

        mvc.perform(get("/users/{id}", 1L)
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    @DisplayName("GET /users/{id} returns 404 when not found")
    void shouldReturn404WhenNotFound() throws Exception {
        given(userService.findById(99L))
            .willThrow(new UserNotFoundException(99L));

        mvc.perform(get("/users/{id}", 99L)
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.error").value("User not found: 99"));
    }

    @Test
    @DisplayName("POST /users validates request body")
    void shouldValidateRequestBody() throws Exception {
        var invalidBody = """
            { "name": "", "email": "not-an-email" }
            """;

        mvc.perform(post("/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidBody))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors").isArray());
    }
}
```

**Key rules:**
- Always specify the controller under test: `@WebMvcTest(UserController.class)`.
- Use `@MockitoBean` (Spring Boot 3.4+) instead of the deprecated `@MockBean`.
- Use `given()` (BDD-style from Mockito) for readability in controller tests.
- Test both happy paths AND error handling (404, 400, 500).

---

### Pattern 3: Integration Tests with @SpringBootTest + Testcontainers

Use `@SpringBootTest` only when you need the full application context. Combine with Testcontainers for real database testing.

```java
// ❌ BAD: Integration test with H2 that hides Postgres-specific behavior
@SpringBootTest
@ActiveProfiles("test")  // application-test.yml points to H2
class OrderIntegrationTest {
    // H2 silently accepts queries that would fail on Postgres
}
```

```java
// ✅ GOOD: Testcontainers with real Postgres
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private OrderRepository orderRepository;

    @BeforeEach
    void setUp() {
        orderRepository.deleteAll();
    }

    @Test
    @DisplayName("full order lifecycle: create, retrieve, update status")
    void shouldHandleFullOrderLifecycle() {
        // Create
        var createRequest = new CreateOrderRequest("SKU-1", 3);
        var createResponse = restTemplate.postForEntity("/orders", createRequest, OrderDto.class);

        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody()).isNotNull();
        assertThat(createResponse.getBody().status()).isEqualTo("PENDING");

        Long orderId = createResponse.getBody().id();

        // Retrieve
        var getResponse = restTemplate.getForEntity("/orders/{id}", OrderDto.class, orderId);

        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().sku()).isEqualTo("SKU-1");

        // Verify persisted in real database
        assertThat(orderRepository.findById(orderId)).isPresent();
    }
}
```

**Key rules:**
- Mark containers as `static` so they are shared across all tests in the class.
- Use `@DynamicPropertySource` to wire container connection details into Spring.
- Use `RANDOM_PORT` + `TestRestTemplate` for true HTTP testing.
- Clean up test data in `@BeforeEach` to avoid test coupling.

---

### Pattern 4: AssertJ Fluent Assertions

Always prefer AssertJ over JUnit's `assertEquals`/`assertTrue`. It provides better error messages and IDE autocomplete.

```java
// ❌ BAD: JUnit assertions — poor readability, weak error messages
assertEquals("Alice", user.getName());
assertTrue(users.size() > 0);
assertNotNull(result);
assertTrue(result.contains("error"));
assertEquals(3, items.size());
```

```java
// ✅ GOOD: AssertJ fluent assertions — type-safe, readable, descriptive failures
// Strings
assertThat(user.getName()).isEqualTo("Alice");
assertThat(user.getEmail()).startsWith("alice").endsWith("@example.com");

// Collections
assertThat(users).isNotEmpty()
    .hasSize(3)
    .extracting(User::getName)
    .containsExactlyInAnyOrder("Alice", "Bob", "Charlie");

// Objects
assertThat(result).isNotNull()
    .satisfies(r -> {
        assertThat(r.getStatus()).isEqualTo("SUCCESS");
        assertThat(r.getTimestamp()).isBeforeOrEqualTo(Instant.now());
    });

// Exceptions
assertThatThrownBy(() -> service.process(null))
    .isInstanceOf(IllegalArgumentException.class)
    .hasMessageContaining("must not be null")
    .hasNoCause();

// Optionals
assertThat(repository.findById(1L))
    .isPresent()
    .get()
    .extracting(Order::getStatus)
    .isEqualTo("SHIPPED");

// Maps
assertThat(config)
    .containsKey("timeout")
    .containsEntry("retries", 3)
    .doesNotContainKey("deprecated");
```

**Key rules:**
- Always start with `assertThat(actual)` — the subject comes first.
- Use `extracting()` to drill into nested properties on collections.
- Use `satisfies()` for grouped assertions on a single object.
- AssertJ error messages include both expected and actual values automatically.

---

## Anti-Patterns

### Anti-Pattern 1: Using @SpringBootTest for Unit Tests

Loading the full Spring context for simple unit tests wastes time and hides design problems.

```java
// ❌ BAD: 5-15 second startup for a test that needs zero Spring infrastructure
@SpringBootTest
class InvoiceCalculatorTest {

    @MockBean
    private TaxService taxService;

    @MockBean
    private DiscountService discountService;

    @Autowired
    private InvoiceCalculator calculator;

    @Test
    void shouldCalculateInvoiceTotal() {
        when(taxService.getRate("US")).thenReturn(0.08);
        when(discountService.getDiscount(any())).thenReturn(0.0);

        double total = calculator.calculate(100.0, "US");

        assertEquals(108.0, total);
    }
}
```

```java
// ✅ GOOD: Millisecond execution, true isolation, forces clean dependency injection
@ExtendWith(MockitoExtension.class)
class InvoiceCalculatorTest {

    @Mock
    private TaxService taxService;

    @Mock
    private DiscountService discountService;

    @InjectMocks
    private InvoiceCalculator calculator;

    @Test
    @DisplayName("should apply tax rate to subtotal")
    void shouldCalculateInvoiceTotal() {
        when(taxService.getRate("US")).thenReturn(0.08);
        when(discountService.getDiscount(any())).thenReturn(0.0);

        double total = calculator.calculate(100.0, "US");

        assertThat(total).isEqualTo(108.0);
    }
}
```

**Rule of thumb:** If your test does not need a Spring `ApplicationContext`, do NOT use `@SpringBootTest`. Use plain JUnit 5 + Mockito.

---

### Anti-Pattern 2: Not Using Test Slices

Spring Boot provides fine-grained slice annotations. Use them instead of loading the entire context.

```java
// ❌ BAD: Full context boot to test a single repository
@SpringBootTest
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldFindByEmail() {
        userRepository.save(new User("Alice", "alice@test.com"));
        Optional<User> found = userRepository.findByEmail("alice@test.com");
        assertTrue(found.isPresent());
    }
}
```

```java
// ✅ GOOD: @DataJpaTest loads only JPA components + embedded DB
@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("should find user by email")
    void shouldFindByEmail() {
        entityManager.persistAndFlush(new User("Alice", "alice@test.com"));

        Optional<User> found = userRepository.findByEmail("alice@test.com");

        assertThat(found).isPresent()
            .get()
            .extracting(User::getName)
            .isEqualTo("Alice");
    }
}
```

**Available test slices:**

| Slice | Loads |
|-------|-------|
| `@WebMvcTest` | Controllers, filters, converters, `@ControllerAdvice` |
| `@DataJpaTest` | JPA repositories, `EntityManager`, Flyway/Liquibase |
| `@DataMongoTest` | MongoDB repositories |
| `@JsonTest` | JSON serialization (`ObjectMapper`) |
| `@RestClientTest` | `RestTemplate` / `RestClient` auto-configuration |

---

## Quick Reference

| Scenario | Annotation | Dependencies |
|----------|------------|--------------|
| Unit test (service/domain) | `@ExtendWith(MockitoExtension.class)` | `@Mock`, `@InjectMocks` |
| Controller test | `@WebMvcTest(Controller.class)` | `MockMvc`, `@MockitoBean` |
| JPA repository test | `@DataJpaTest` | `TestEntityManager` |
| Full integration test | `@SpringBootTest` | `TestRestTemplate`, real beans |
| Integration + real DB | `@SpringBootTest` + `@Testcontainers` | `@Container`, `@DynamicPropertySource` |
| JSON serialization | `@JsonTest` | `JacksonTester<T>` |
| Assertions | AssertJ | `assertThat(actual).isEqualTo(expected)` |
| Exception assertion | AssertJ | `assertThatThrownBy(() -> ...).isInstanceOf(...)` |
| BDD-style mocking | Mockito BDD | `given(mock.method()).willReturn(...)` |
