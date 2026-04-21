---
name: mobile-testing
description: >
  Testing patterns for React Native/Expo apps: Jest, React Native Testing Library, Detox E2E.
  Trigger: When writing tests for mobile components, screens, navigation, or E2E flows.
globs:
  - "**/*.test.tsx"
  - "**/*.test.ts"
  - "**/*.spec.tsx"
  - "**/*.spec.ts"
metadata:
  author: team-ai-kit
  version: "1.0"
---

# Mobile — Testing

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Writing unit tests for components with RNTL
- Testing navigation flows
- Writing E2E tests with Detox or Maestro

## Critical Patterns

- Prefer behavioral tests over snapshot tests
  - ❌ `expect(tree).toMatchSnapshot()` for component logic
  - ✅ `expect(screen.getByText('Submit')).toBeTruthy()` for behavior
- Mock native modules at the top of test files with `jest.mock()`
- Test user interactions with `fireEvent` / `userEvent` from RNTL

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Unit tests | Jest + React Native Testing Library |
| Mocking | `jest.mock()` for native modules |
| E2E | Detox or Maestro |
| Snapshots | Avoid — prefer behavioral tests |
