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

# Backend .NET — Testing

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Writing unit tests with xUnit + NSubstitute/Moq
- Writing integration tests with `WebApplicationFactory`
- Testing EF Core with in-memory provider or Testcontainers

## Critical Patterns

- Use `WebApplicationFactory<Program>` for integration tests, not manual host setup
  - ❌ `new HttpClient()` pointing at a running server
  - ✅ `factory.CreateClient()` with service overrides
- Use FluentAssertions for readable assertions
- One logical assertion per test method

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Unit tests | xUnit + NSubstitute (`Substitute.For<T>()`) |
| Integration | `WebApplicationFactory<Program>` |
| DB tests | EF Core InMemory or Testcontainers |
| Assertions | FluentAssertions |
