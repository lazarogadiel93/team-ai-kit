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

## When to Use

- Writing unit or integration tests for React Native / Expo components
- Testing screen-level behavior (forms, lists, navigation transitions)
- Mocking native modules that crash in the Jest JSDOM environment
- Setting up or extending `jest.setup.ts` for a mobile project
- Writing end-to-end flows with Detox (login, onboarding, deep links)
- Testing custom hooks that depend on React Native APIs

---

## Critical Patterns

### 1. Component Testing with RNTL (render, screen, userEvent)

Use `@testing-library/react-native` with **userEvent** for realistic interactions.
Query by **role first**, then label, then text. Avoid testID when an accessible query exists.

```tsx
// ❌ BAD — fireEvent skips the full press lifecycle and uses testID unnecessarily
import { render, fireEvent } from '@testing-library/react-native';

test('submits form', () => {
  const onSubmit = jest.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  fireEvent.changeText(
    render.getByTestId('email-input'),
    'user@example.com',
  );
  fireEvent.press(render.getByTestId('submit-btn'));

  expect(onSubmit).toHaveBeenCalled();
});
```

```tsx
// ✅ GOOD — userEvent with full event lifecycle; queries by role/label
import { render, screen, userEvent } from '@testing-library/react-native';

jest.useFakeTimers(); // required by userEvent

test('submits login form with valid credentials', async () => {
  const onSubmit = jest.fn();
  const user = userEvent.setup();

  render(<LoginForm onSubmit={onSubmit} />);

  await user.type(screen.getByLabelText('Email'), 'user@example.com');
  await user.type(screen.getByLabelText('Password'), 'secret123');
  await user.press(screen.getByRole('button', { name: 'Login' }));

  expect(onSubmit).toHaveBeenCalledWith({
    email: 'user@example.com',
    password: 'secret123',
  });
});
```

**Key rules:**
- Always call `jest.useFakeTimers()` at the module level when using `userEvent`.
- Use `screen` singleton instead of destructuring `render()` return value.
- Prefer `userEvent.type` over `fireEvent.changeText` — it fires focus, keyPress, and blur.
- Prefer `userEvent.press` over `fireEvent.press` — it fires pressIn and pressOut.
- Use `findBy*` queries for elements that appear asynchronously.

---

### 2. Mocking Native Modules in jest.setup.ts

Native modules crash under Jest because there is no bridge. Mock them in a central
setup file referenced by `setupFiles` in your Jest config.

```ts
// ❌ BAD — mocking inline in every test file; incomplete mocks cause leaks
// some-screen.test.tsx
jest.mock('react-native-safe-area-context', () => ({}));
jest.mock('@react-native-async-storage/async-storage', () => ({}));
// ...repeated in 47 other test files
```

```ts
// ✅ GOOD — centralised jest.setup.ts with proper return shapes

// jest.setup.ts
import '@testing-library/react-native/extend-expect'; // RNTL matchers

// Safe Area
jest.mock('react-native-safe-area-context', () => {
  const insets = { top: 0, right: 0, bottom: 0, left: 0 };
  return {
    SafeAreaProvider: ({ children }: { children: React.ReactNode }) => children,
    SafeAreaView: ({ children }: { children: React.ReactNode }) => children,
    useSafeAreaInsets: () => insets,
  };
});

// Async Storage
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

// react-native-reanimated
jest.mock('react-native-reanimated', () =>
  require('react-native-reanimated/mock'),
);

// Expo modules (Camera, Location, etc.)
jest.mock('expo-camera', () => ({
  Camera: 'Camera',
  useCameraPermissions: () => [{ granted: false }, jest.fn()],
}));

jest.mock('expo-location', () => ({
  requestForegroundPermissionsAsync: jest.fn().mockResolvedValue({
    status: 'granted',
  }),
  getCurrentPositionAsync: jest.fn().mockResolvedValue({
    coords: { latitude: 0, longitude: 0 },
  }),
}));
```

```jsonc
// jest.config.ts (or package.json "jest" key)
{
  "preset": "jest-expo", // or "react-native"
  "setupFiles": ["./jest.setup.ts"],
  "transformIgnorePatterns": [
    "node_modules/(?!((jest-)?react-native|@react-native(-community)?|expo(nent)?|@expo(nent)?/.*|react-navigation|@react-navigation/.*)/)"
  ]
}
```

**Key rules:**
- One `jest.setup.ts` at the repo root — never scatter mocks across test files.
- Return the minimum shape the module expects (functions return `jest.fn()`).
- For Expo, use `jest-expo` preset which pre-mocks many Expo modules.
- Add `@testing-library/react-native/extend-expect` in setup for matchers like
  `toBeOnTheScreen()`, `toHaveTextContent()`, `toHaveDisplayValue()`.

---

### 3. Testing Navigation (mocking useNavigation / useRouter)

Navigation tests should verify that the correct **route** is called, not that the
navigator renders. Mock the hook, not the entire library.

```tsx
// ❌ BAD — importing the real navigator tree into a unit test
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

test('navigates to details', async () => {
  const Stack = createNativeStackNavigator();
  render(
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="Details" component={DetailsScreen} />
      </Stack.Navigator>
    </NavigationContainer>,
  );
  // slow, brittle, full navigator setup just to test a button
});
```

```tsx
// ✅ GOOD — mock useNavigation, assert the call

// For @react-navigation/native
const mockNavigate = jest.fn();
jest.mock('@react-navigation/native', () => ({
  ...jest.requireActual('@react-navigation/native'),
  useNavigation: () => ({
    navigate: mockNavigate,
    goBack: jest.fn(),
  }),
  useRoute: () => ({
    params: { id: '123' },
  }),
}));

test('navigates to details on item press', async () => {
  const user = userEvent.setup();
  render(<HomeScreen />);

  await user.press(screen.getByRole('button', { name: 'View Details' }));

  expect(mockNavigate).toHaveBeenCalledWith('Details', { id: '123' });
});
```

```tsx
// ✅ GOOD — for Expo Router (useRouter)
const mockPush = jest.fn();
jest.mock('expo-router', () => ({
  useRouter: () => ({
    push: mockPush,
    back: jest.fn(),
    replace: jest.fn(),
  }),
  useLocalSearchParams: () => ({ id: '123' }),
  Link: ({ children }: { children: React.ReactNode }) => children,
}));

test('pushes to profile screen', async () => {
  const user = userEvent.setup();
  render(<SettingsScreen />);

  await user.press(screen.getByRole('button', { name: 'Edit Profile' }));

  expect(mockPush).toHaveBeenCalledWith('/profile/edit');
});
```

**Key rules:**
- Use `jest.requireActual` to preserve non-hook exports (e.g., `NavigationContainer`
  if you still need it as a wrapper for integration tests).
- Reset mocks in `beforeEach` to avoid leakage between tests.
- For integration-level navigation tests, wrap with `<NavigationContainer>` but keep
  those in a separate `__integration__/` folder — they are slower.

---

### 4. E2E Testing with Detox (device, element, expect)

Detox tests run on a real simulator/emulator. They use `element()`, `by.*` matchers,
actions (`.tap()`, `.typeText()`), and `expect()` assertions.

```typescript
// ❌ BAD — no beforeAll launch, no reload between tests, hardcoded waits
it('logs in', async () => {
  await new Promise((r) => setTimeout(r, 3000)); // manual sleep
  await element(by.id('email')).typeText('a@b.com');
  await element(by.id('password')).typeText('123');
  await element(by.text('Login')).tap();
});
```

```typescript
// ✅ GOOD — proper lifecycle, Detox auto-sync, clean state
describe('Login flow', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true });
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('should login successfully with valid credentials', async () => {
    await element(by.id('email-input')).typeText('john@example.com');
    await element(by.id('password-input')).typeText('secret123');
    await element(by.id('password-input')).tapReturnKey();

    await element(by.text('Login')).tap();

    // Detox auto-waits for animations and network — no manual sleep
    await expect(element(by.text('Welcome, John'))).toBeVisible();
    await expect(element(by.text('Login'))).not.toExist();
  });

  it('should show error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com');
    await element(by.id('password-input')).typeText('bad');
    await element(by.text('Login')).tap();

    await expect(element(by.text('Invalid credentials'))).toBeVisible();
  });
});
```

**Key rules:**
- Use `device.launchApp({ newInstance: true })` in `beforeAll` for a clean start.
- Use `device.reloadReactNative()` in `beforeEach` for state reset between tests.
- **Never** use `setTimeout` or manual waits — Detox synchronizes automatically.
- Prefer `by.id()` for Detox (unlike RNTL where you prefer roles). In E2E, testIDs
  are the stable contract between code and tests.
- Use `tapReturnKey()` to dismiss the keyboard before tapping other elements.
- Keep Detox tests in a separate `e2e/` folder with its own Jest config.

---

## Anti-Patterns

### 1. Snapshot Tests for Behavior Verification

Snapshot tests capture rendered output as a string. They are useful for detecting
**unintentional UI changes** but tell you nothing about **behavior**.

```tsx
// ❌ BAD — snapshot "tests" behavior
test('login form works', () => {
  const tree = render(<LoginForm onSubmit={jest.fn()} />);
  expect(tree.toJSON()).toMatchSnapshot();
  // This passes even if the submit button does nothing.
  // Any style change breaks it, creating noise.
});
```

```tsx
// ✅ GOOD — behavioral assertion
test('shows validation error when email is empty', async () => {
  const user = userEvent.setup();
  render(<LoginForm onSubmit={jest.fn()} />);

  await user.press(screen.getByRole('button', { name: 'Login' }));

  expect(screen.getByRole('alert')).toHaveTextContent('Email is required');
});
```

**When snapshots ARE acceptable:** Guarding complex static layouts (e.g., a terms
of service screen) against accidental changes. Never as the only test for a component.

---

### 2. Testing Implementation Details (testID Over Accessible Queries)

Querying by `testID` when an accessible role or label exists couples tests to
implementation rather than user-visible behavior.

```tsx
// ❌ BAD — testID when a role exists
<Pressable testID="submit-btn" accessibilityRole="button" accessibilityLabel="Submit">
  <Text>Submit</Text>
</Pressable>

// Test:
screen.getByTestId('submit-btn'); // brittle, not what the user "sees"
```

```tsx
// ✅ GOOD — query by role, the way assistive technology would
screen.getByRole('button', { name: 'Submit' });
```

**RNTL query priority (use the highest one that works):**

| Priority | Query | Use when |
|----------|-------|----------|
| 1st | `getByRole` | Element has a semantic role (button, heading, alert, textbox) |
| 2nd | `getByLabelText` | Element has `accessibilityLabel` or `aria-label` |
| 3rd | `getByText` | Visible text uniquely identifies the element |
| 4th | `getByPlaceholderText` | Input with a placeholder (less accessible) |
| 5th | `getByDisplayValue` | Input with a current value |
| Last | `getByTestId` | No semantic query applies (e.g., a generic `View` wrapper) |

---

## Quick Reference

### Common RNTL Queries

| Query | Async? | Use case |
|-------|--------|----------|
| `screen.getByRole('button', { name: 'Save' })` | No | Button with accessible name |
| `screen.getByLabelText('Email')` | No | Input with `accessibilityLabel` |
| `screen.getByText('Welcome')` | No | Static visible text |
| `screen.findByRole('alert')` | Yes | Element that appears after async action |
| `screen.queryByText('Error')` | No | Assert element does NOT exist |
| `screen.getAllByRole('listitem')` | No | Multiple elements with same role |

### Common RNTL Matchers

| Matcher | Asserts |
|---------|---------|
| `toBeOnTheScreen()` | Element is in the component tree |
| `toHaveTextContent('text')` | Element contains text |
| `toHaveDisplayValue('value')` | TextInput shows value |
| `toBeEnabled()` / `toBeDisabled()` | Pressable / input state |
| `toHaveProp('propName', value)` | Specific prop value |
| `toBeVisible()` | Element is not hidden by `display: none` or `opacity: 0` |

### userEvent API

| Method | Replaces |
|--------|----------|
| `await user.press(element)` | `fireEvent.press` |
| `await user.type(input, 'text')` | `fireEvent.changeText` |
| `await user.longPress(element)` | `fireEvent(el, 'longPress')` |
| `await user.scrollTo(scrollView, { y: 300 })` | `fireEvent.scroll` |

### Detox Cheat Sheet

| Action | Code |
|--------|------|
| Launch app | `await device.launchApp({ newInstance: true })` |
| Reload JS | `await device.reloadReactNative()` |
| Tap | `await element(by.id('btn')).tap()` |
| Type text | `await element(by.id('input')).typeText('hello')` |
| Clear text | `await element(by.id('input')).clearText()` |
| Scroll down | `await element(by.id('list')).scroll(200, 'down')` |
| Assert visible | `await expect(element(by.text('Done'))).toBeVisible()` |
| Assert not exist | `await expect(element(by.id('modal'))).not.toExist()` |
| Dismiss keyboard | `await element(by.id('input')).tapReturnKey()` |

### Project Structure

```
__tests__/              # RNTL unit/integration tests (mirrors src/)
  components/
    LoginForm.test.tsx
  screens/
    HomeScreen.test.tsx
  hooks/
    useAuth.test.ts
e2e/                    # Detox E2E tests (separate jest config)
  login.e2e.ts
  onboarding.e2e.ts
jest.setup.ts           # Global mocks for native modules
jest.config.ts          # Jest configuration
.detoxrc.js             # Detox configuration
```
