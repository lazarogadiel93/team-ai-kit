# Pack: Mobile (React Native / Expo)

> Rules and conventions for mobile developers.

---

## Architecture Rules

- Use file-based routing (Expo Router) or stack-based navigation (React Navigation)
- Separate screens from reusable components
- Keep platform-specific code isolated with `.ios.ts` / `.android.ts` suffixes
- Use a global state manager (Zustand) for client state and TanStack Query for server state

## Code Quality Rules

- Use `FlashList` over `FlatList` for large lists
- Always handle loading, error, and empty states in every screen
- Avoid inline styles — use `StyleSheet.create()` or NativeWind
- Handle keyboard avoidance, safe areas, and gesture conflicts
- Test on both iOS and Android before merging

### Testing

- Use React Native Testing Library (RNTL) for component tests
- Mock native modules with `jest.mock()` in setup files
- Avoid snapshot tests — prefer behavioral assertions
- Use Detox or Maestro for E2E testing

### Naming

- Screens: `*Screen.tsx` in `app/` or `screens/`
- Components: PascalCase in `components/`
- Hooks: `use*.ts` in `hooks/`
- Navigation: defined in `app/` (Expo Router) or `navigation/`

## Thinking Rules

- Think about the user experience on both platforms before implementing
- Consider offline-first patterns and optimistic updates for mobile UX
- Think about the function contract (inputs/outputs) before implementing
- Validate inputs at the system boundary, not deep inside
- Avoid premature abstractions: make it work first, then abstract
