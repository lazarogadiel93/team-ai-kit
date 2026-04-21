---
name: backend-java-api
description: >
  REST API design patterns with Spring Boot: controllers, services, repositories, validation, error handling.
  Trigger: When creating endpoints, defining routes, implementing middleware, or handling HTTP errors in Java/Spring.
globs:
  - "**/*.java"
  - "**/pom.xml"
  - "**/build.gradle"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Building REST endpoints with Spring Boot (`@RestController`, `@RequestMapping`)
- Designing the controller → service → repository layer architecture
- Adding input validation with Jakarta Bean Validation (`@Valid`, custom constraints)
- Implementing centralized error handling with `@ControllerAdvice` and RFC 9457 ProblemDetails
- Defining DTOs as Java records to decouple API contracts from JPA entities
- Wiring dependencies via constructor injection (never field injection)

---

## Critical Patterns

### Pattern 1: Thin Controllers — Business Logic in Services

Controllers handle HTTP concerns ONLY: receive request, validate, delegate to service, return response.
All business logic, transactions, and orchestration belong in the service layer.

```java
// ❌ BAD — business logic lives in the controller
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderRepository orderRepository;
    private final InventoryRepository inventoryRepository;

    public OrderController(OrderRepository orderRepository,
                           InventoryRepository inventoryRepository) {
        this.orderRepository = orderRepository;
        this.inventoryRepository = inventoryRepository;
    }

    @PostMapping
    public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) {
        // Business rules leaked into the controller
        var item = inventoryRepository.findBySku(request.sku())
                .orElseThrow(() -> new RuntimeException("Item not found"));
        if (item.getStock() < request.quantity()) {
            throw new RuntimeException("Insufficient stock");
        }
        item.setStock(item.getStock() - request.quantity());
        inventoryRepository.save(item);

        var order = new Order(request.sku(), request.quantity(), item.getPrice());
        var saved = orderRepository.save(order);
        return ResponseEntity.status(HttpStatus.CREATED).body(OrderResponse.from(saved));
    }
}
```

```java
// ✅ GOOD — controller is thin, service owns business logic
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) {
        var order = orderService.placeOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }

    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> findById(@PathVariable Long id) {
        return ResponseEntity.ok(orderService.findById(id));
    }
}
```

```java
@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final InventoryService inventoryService;

    public OrderService(OrderRepository orderRepository,
                        InventoryService inventoryService) {
        this.orderRepository = orderRepository;
        this.inventoryService = inventoryService;
    }

    @Transactional
    public OrderResponse placeOrder(CreateOrderRequest request) {
        inventoryService.reserveStock(request.sku(), request.quantity());
        var order = new Order(request.sku(), request.quantity());
        var saved = orderRepository.save(order);
        return OrderResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public OrderResponse findById(Long id) {
        var order = orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
        return OrderResponse.from(order);
    }
}
```

Use Java records as immutable DTOs for requests and responses:

```java
public record CreateOrderRequest(
        @NotBlank String sku,
        @Min(1) int quantity
) {}

public record OrderResponse(
        Long id,
        String sku,
        int quantity,
        BigDecimal total,
        Instant createdAt
) {
    public static OrderResponse from(Order order) {
        return new OrderResponse(
                order.getId(), order.getSku(), order.getQuantity(),
                order.getTotal(), order.getCreatedAt()
        );
    }
}
```

### Pattern 2: Input Validation with Jakarta Bean Validation

Use `@Valid` on `@RequestBody` parameters. Define constraints on DTO fields.
For complex rules, create custom constraint annotations.

```java
// ❌ BAD — manual null checks scattered in controller
@PostMapping
public ResponseEntity<?> create(@RequestBody CreateUserRequest request) {
    if (request.email() == null || request.email().isBlank()) {
        return ResponseEntity.badRequest().body("Email is required");
    }
    if (request.age() != null && request.age() < 0) {
        return ResponseEntity.badRequest().body("Age must be positive");
    }
    // ... more manual checks
}
```

```java
// ✅ GOOD — declarative validation with @Valid
public record CreateUserRequest(
        @NotBlank(message = "Name is required")
        String name,

        @NotBlank @Email(message = "Must be a valid email")
        String email,

        @Min(value = 0, message = "Age must be non-negative")
        Integer age,

        @NotNull @Size(min = 8, max = 128, message = "Password must be 8-128 characters")
        String password
) {}

@PostMapping("/api/users")
public ResponseEntity<UserResponse> create(@Valid @RequestBody CreateUserRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(userService.create(request));
}
```

Custom constraint example:

```java
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = NoProfanityValidator.class)
public @interface NoProfanity {
    String message() default "Content contains prohibited words";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class NoProfanityValidator implements ConstraintValidator<NoProfanity, String> {
    @Override
    public boolean isValid(String value, ConstraintValidatorContext ctx) {
        if (value == null) return true;
        return !ProfanityFilter.containsProfanity(value);
    }
}
```

### Pattern 3: Centralized Error Handling with @ControllerAdvice + ProblemDetails

Extend `ResponseEntityExceptionHandler` to get RFC 9457 ProblemDetails support out of the box.
Add `@ExceptionHandler` methods for your domain exceptions.

```java
// ❌ BAD — try/catch in every controller method
@GetMapping("/{id}")
public ResponseEntity<?> findById(@PathVariable Long id) {
    try {
        return ResponseEntity.ok(userService.findById(id));
    } catch (UserNotFoundException e) {
        return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
    } catch (Exception e) {
        return ResponseEntity.status(500).body(Map.of("error", "Something went wrong"));
    }
}
```

```java
// ✅ GOOD — centralized handler, controllers stay clean
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource Not Found");
        problem.setProperty("resourceId", ex.getResourceId());
        return problem;
    }

    @ExceptionHandler(BusinessRuleException.class)
    public ProblemDetail handleBusinessRule(BusinessRuleException ex) {
        var problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        problem.setTitle("Business Rule Violation");
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        // Log the full stack trace — never expose internals to the client
        log.error("Unexpected error", ex);
        return ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }
}
```

Define domain exceptions that carry context:

```java
public class ResourceNotFoundException extends RuntimeException {
    private final Object resourceId;

    public ResourceNotFoundException(String resource, Object id) {
        super("%s with id %s not found".formatted(resource, id));
        this.resourceId = id;
    }

    public Object getResourceId() { return resourceId; }
}
```

### Pattern 4: Repository Pattern with Spring Data JPA

Let Spring Data generate implementations. Use derived queries for simple cases,
`@Query` for complex ones. Never put business logic in repositories.

```java
// ❌ BAD — raw EntityManager in the service
@Service
public class UserService {
    @PersistenceContext
    private EntityManager em;

    public User findByEmail(String email) {
        return em.createQuery("SELECT u FROM User u WHERE u.email = :email", User.class)
                .setParameter("email", email)
                .getSingleResult();
    }
}
```

```java
// ✅ GOOD — Spring Data JPA repository interface
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.department = :dept AND u.active = true")
    List<User> findActiveMembersByDepartment(@Param("dept") String department);

    boolean existsByEmail(String email);
}
```

```java
@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public UserResponse findByEmail(String email) {
        var user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User", email));
        return UserResponse.from(user);
    }
}
```

---

## Anti-Patterns

### Don't: Use Field Injection with @Autowired

Field injection hides dependencies, breaks testability, and makes it impossible to create
immutable objects. Constructor injection is the Spring team's recommended approach.

```java
// ❌ BAD — field injection
@Service
public class PaymentService {
    @Autowired
    private OrderRepository orderRepository;
    @Autowired
    private PaymentGateway paymentGateway;
    @Autowired
    private NotificationService notificationService;
}
```

```java
// ✅ GOOD — constructor injection (implicit @Autowired with single constructor)
@Service
public class PaymentService {

    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;
    private final NotificationService notificationService;

    public PaymentService(OrderRepository orderRepository,
                          PaymentGateway paymentGateway,
                          NotificationService notificationService) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
        this.notificationService = notificationService;
    }
}
```

Why constructor injection wins:
- Dependencies are **explicit** — you see them in the constructor signature
- Fields can be **final** — guarantees immutability after construction
- **Testable** — pass mocks directly in unit tests, no reflection or Spring context needed
- Catches missing beans at **startup**, not at runtime

### Don't: Put Business Logic in Controllers

Controllers that contain business rules become untestable, unreusable, and violate SRP.
If you need a `@Transactional` annotation on a controller method, something is wrong.

```java
// ❌ BAD — controller does everything
@RestController
@RequestMapping("/api/accounts")
public class AccountController {

    private final AccountRepository accountRepository;

    @PostMapping("/{id}/transfer")
    @Transactional // Red flag: transactions don't belong here
    public ResponseEntity<?> transfer(@PathVariable Long id,
                                      @RequestBody TransferRequest request) {
        var source = accountRepository.findById(id).orElseThrow();
        var target = accountRepository.findById(request.targetId()).orElseThrow();

        if (source.getBalance().compareTo(request.amount()) < 0) {
            throw new InsufficientFundsException(id);
        }

        source.debit(request.amount());
        target.credit(request.amount());

        accountRepository.save(source);
        accountRepository.save(target);

        return ResponseEntity.ok().build();
    }
}
```

```java
// ✅ GOOD — controller delegates, service owns the transaction
@RestController
@RequestMapping("/api/accounts")
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    @PostMapping("/{id}/transfer")
    public ResponseEntity<TransferResponse> transfer(
            @PathVariable Long id,
            @Valid @RequestBody TransferRequest request) {
        return ResponseEntity.ok(accountService.transfer(id, request));
    }
}
```

---

## Quick Reference

| Layer | Responsibility |
| --- | --- |
| **Controller** | HTTP mapping, input validation (`@Valid`), response status codes |
| **Service** | Business logic, transactions (`@Transactional`), orchestration |
| **Repository** | Data access via Spring Data JPA interfaces |
| **DTO (Record)** | API contract — decouples HTTP shape from domain entities |
| **Entity** | JPA-mapped domain object — never exposed directly in responses |
| **ExceptionHandler** | `@RestControllerAdvice` returning `ProblemDetail` (RFC 9457) |
| **Validator** | Custom `ConstraintValidator` for domain-specific rules |
