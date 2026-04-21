---
name: mobile-architecture
description: >
  Mobile app architecture patterns with React Native/Expo: navigation, state management, platform-specific code, performance.
  Trigger: When building screens, setting up navigation, managing state, or optimizing mobile performance.
globs:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/app.json"
  - "**/app.config.ts"
metadata:
  author: team-ai-kit
  version: "1.0"
---

# Mobile — Architecture

> Placeholder skill. Full content coming in a follow-up PR.

## When to Use

- Building mobile apps with React Native / Expo
- Setting up navigation (React Navigation / Expo Router)
- Managing state in mobile contexts
- Handling platform-specific code (iOS vs Android)

## Critical Patterns

- Use FlashList instead of FlatList for large lists
  - ❌ `<FlatList>` with 1000+ items
  - ✅ `<FlashList estimatedItemSize={50}>` for performant rendering
- Separate platform-specific code with `.ios.ts` / `.android.ts` suffixes
- Keep navigation configuration colocated with screen definitions

## Quick Reference

| Topic | Pattern |
|-------|---------|
| Navigation | Expo Router (file-based) or React Navigation |
| State | Zustand for client, TanStack Query for server |
| Lists | FlashList over FlatList |
| Styling | StyleSheet.create or NativeWind |
