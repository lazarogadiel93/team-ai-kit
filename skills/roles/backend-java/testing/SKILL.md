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

# Backend Java — Testing

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Writing unit tests with JUnit 5 + Mockito
- Writing integration tests with `@SpringBootTest`
- Using Testcontainers for database/infra tests

## Critical Patterns

- Use `@MockBean` only in integration tests; prefer constructor injection with `@Mock` in unit tests
  - ❌ `@MockBean` in every test class (slow Spring context reload)
  - ✅ `@ExtendWith(MockitoExtension.class)` + `@Mock` for unit tests
- Use AssertJ fluent assertions over JUnit assertions
- One assertion concept per test method

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Unit tests | JUnit 5 + Mockito (`@Mock`, `@InjectMocks`) |
| Integration | `@SpringBootTest` + `@AutoConfigureMockMvc` |
| DB tests | Testcontainers or H2 in-memory |
| Assertions | AssertJ fluent assertions |
