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

# Backend Java — API Design

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Building REST APIs with Spring Boot
- Designing controller/service/repository layers
- Implementing validation, error handling, or middleware

## Critical Patterns

- Always return consistent error responses via `@ControllerAdvice`
  - ❌ Throwing raw exceptions from controllers
  - ✅ Centralized exception handler returning `ProblemDetail`
- Use DTOs (record classes) to decouple API contracts from entities
  - ❌ Exposing JPA entities directly in responses
  - ✅ Mapping entities to response records via a mapper
- Validate input at the controller boundary with `@Valid`

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Architecture | Controller → Service → Repository |
| Validation | Jakarta Bean Validation (`@Valid`) |
| Error handling | `@ControllerAdvice` + `@ExceptionHandler` |
| DTOs | Record classes for request/response |
