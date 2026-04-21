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

# Backend .NET — API Design

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Building REST APIs with ASP.NET Core
- Designing controller/service/repository layers
- Implementing middleware, filters, or error handling

## Critical Patterns

- Return `ProblemDetails` for all error responses via exception middleware
  - ❌ Returning plain strings or custom error shapes per endpoint
  - ✅ Centralized exception middleware producing RFC 7807 `ProblemDetails`
- Use record types for DTOs to decouple API contracts from EF entities
- Register services with the correct lifetime (`Scoped` for DB contexts, `Singleton` for stateless)

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Architecture | Controller → Service → Repository |
| Validation | Data Annotations + FluentValidation |
| Error handling | Exception middleware + ProblemDetails |
| DTOs | Record types for request/response |
| DI | Built-in `IServiceCollection` |
