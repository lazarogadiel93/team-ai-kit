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

## When to Use

- Setting up or modifying Expo Router file-based navigation (layouts, groups, typed routes)
- Building list-heavy screens that need scroll performance optimization
- Choosing between client state (Zustand) and server state (TanStack Query)
- Writing platform-specific code for iOS and Android divergences
- Handling safe areas, keyboard avoidance, or responsive layout on mobile
- Styling components with NativeWind or StyleSheet

## Critical Patterns

### 1. File-Based Routing with Expo Router

Expo Router maps the `app/` directory to navigation routes. Layout files (`_layout.tsx`) define
navigators. Route groups `(groupName)` organize routes without affecting the URL. Use typed
routes for compile-time safety.

**Directory structure:**

```
app/
├── _layout.tsx              # Root layout (Stack or Tabs)
├── index.tsx                # "/" route
├── (auth)/
│   ├── _layout.tsx          # Auth group layout
│   ├── login.tsx            # "/login"
│   └── register.tsx         # "/register"
├── (tabs)/
│   ├── _layout.tsx          # Tab navigator
│   ├── home.tsx             # "/home"
│   └── profile.tsx          # "/profile"
└── settings/
    ├── _layout.tsx          # Nested stack
    ├── index.tsx            # "/settings"
    └── [id].tsx             # "/settings/:id" (dynamic route)
```

#### Bad: hardcoded string navigation without type safety

```tsx
// ❌ Untyped navigation — typos cause runtime crashes, no autocomplete
import { router } from "expo-router";

function goToProfile() {
  router.push("/proflie"); // typo — crashes at runtime, no compiler warning
}
```

#### Good: typed routes with Expo Router href

```tsx
// ✅ Typed routes — compiler catches invalid paths, full autocomplete
import { router } from "expo-router";

function goToProfile() {
  router.push("/profile"); // type-checked route (enable typed routes in app.json)
}

function goToSettings(id: string) {
  router.push({ pathname: "/settings/[id]", params: { id } });
}
```

#### Good: layout file with groups and screen options

```tsx
// app/(tabs)/_layout.tsx
// ✅ Tab navigator using Expo Router layout convention
import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#6366f1",
      }}
    >
      <Tabs.Screen
        name="home"
        options={{
          title: "Home",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
```

> **Tip:** Enable `partialRouteTypes` in `app.json` for incremental typed-route generation.
> Run `npx expo customize tsconfig.json` to include generated route types.

---

### 2. FlashList Over FlatList for Large Lists

FlashList from `@shopify/flash-list` is a drop-in replacement for FlatList with recycling-based
rendering. It is dramatically faster for lists with 100+ items.

- **v1**: requires `estimatedItemSize` for the recycler to pre-allocate layout.
- **v2**: `estimatedItemSize` is removed; sizing is automatic.
- Always use `getItemType` for heterogeneous lists so the recycler reuses the correct cell type.
- Always test list performance in **release mode** — debug mode hides real perf.

#### Bad: FlatList for a long feed

```tsx
// ❌ FlatList does not recycle views — janky on 500+ items
import { FlatList } from "react-native";

export function Feed({ items }: { items: FeedItem[] }) {
  return (
    <FlatList
      data={items}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => <FeedCard item={item} />}
    />
  );
}
```

#### Good: FlashList with proper configuration

```tsx
// ✅ FlashList recycles views — smooth 60fps even with thousands of items
import { FlashList } from "@shopify/flash-list";

export function Feed({ items }: { items: FeedItem[] }) {
  return (
    <FlashList
      data={items}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => <FeedCard item={item} />}
      estimatedItemSize={120} // v1 only — remove for v2
      getItemType={(item) => item.type} // required for mixed-type lists
    />
  );
}
```

> **Note:** In FlashList v2, remove `estimatedItemSize`, `estimatedListSize`, and
> `estimatedFirstItemOffset` — they are no longer supported. Use `masonry` prop instead of
> `MasonryFlashList`.

---

### 3. State Management: Zustand (Client) + TanStack Query (Server)

Separate **client UI state** (modals, filters, theme) from **server/async state** (API data,
pagination, cache). Zustand owns client state. TanStack Query owns server state.

#### Bad: Zustand store fetching and caching API data

```tsx
// ❌ Zustand is not a server-state cache — no refetch, stale-while-revalidate,
//    or deduplication. You end up re-implementing what TanStack Query gives you.
import { create } from "zustand";

interface UserStore {
  users: User[];
  loading: boolean;
  fetchUsers: () => Promise<void>;
}

const useUserStore = create<UserStore>((set) => ({
  users: [],
  loading: false,
  fetchUsers: async () => {
    set({ loading: true });
    const res = await fetch("/api/users");
    const users = await res.json();
    set({ users, loading: false });
  },
}));
```

#### Good: Zustand for UI state, TanStack Query for server data

```tsx
// ✅ Client state — Zustand
import { create } from "zustand";

interface UIStore {
  selectedFilter: string;
  setFilter: (filter: string) => void;
}

export const useUIStore = create<UIStore>((set) => ({
  selectedFilter: "all",
  setFilter: (filter) => set({ selectedFilter: filter }),
}));

// ✅ Server state — TanStack Query
import { useQuery } from "@tanstack/react-query";

const userKeys = {
  all: ["users"] as const,
  filtered: (filter: string) => ["users", { filter }] as const,
};

export function useUsers(filter: string) {
  return useQuery({
    queryKey: userKeys.filtered(filter),
    queryFn: () => fetch(`/api/users?filter=${filter}`).then((r) => r.json()),
    staleTime: 5 * 60 * 1000,
  });
}
```

```tsx
// ✅ Screen combining both
export function UserListScreen() {
  const filter = useUIStore((s) => s.selectedFilter);
  const { data: users, isLoading } = useUsers(filter);

  if (isLoading) return <LoadingSpinner />;

  return (
    <FlashList
      data={users}
      renderItem={({ item }) => <UserCard user={item} />}
      estimatedItemSize={80}
    />
  );
}
```

---

### 4. Platform-Specific Code Isolation

React Native resolves `.ios.tsx` and `.android.tsx` extensions automatically. Use this for
components with fundamentally different native behavior. For minor tweaks, use `Platform.select`.

#### Bad: Platform.OS conditionals scattered throughout a component

```tsx
// ❌ Deeply nested Platform.OS checks make the component hard to read and test
import { Platform, View, Text } from "react-native";

export function DatePicker({ value, onChange }: DatePickerProps) {
  if (Platform.OS === "ios") {
    return (
      <View>
        {/* 40 lines of iOS-specific wheel picker */}
        <Text>iOS picker</Text>
      </View>
    );
  }
  return (
    <View>
      {/* 40 lines of Android-specific material picker */}
      <Text>Android picker</Text>
    </View>
  );
}
```

#### Good: platform-specific files with a shared interface

```tsx
// components/date-picker/types.ts — shared contract
export interface DatePickerProps {
  value: Date;
  onChange: (date: Date) => void;
  minimumDate?: Date;
  maximumDate?: Date;
}
```

```tsx
// components/date-picker/date-picker.ios.tsx
import { DatePickerProps } from "./types";
import DateTimePicker from "@react-native-community/datetimepicker";

export function DatePicker({ value, onChange, ...rest }: DatePickerProps) {
  return (
    <DateTimePicker
      value={value}
      mode="date"
      display="spinner" // iOS-native wheel
      onChange={(_, date) => date && onChange(date)}
      {...rest}
    />
  );
}
```

```tsx
// components/date-picker/date-picker.android.tsx
import { DatePickerProps } from "./types";
import DateTimePicker from "@react-native-community/datetimepicker";

export function DatePicker({ value, onChange, ...rest }: DatePickerProps) {
  return (
    <DateTimePicker
      value={value}
      mode="date"
      display="default" // Android material dialog
      onChange={(_, date) => date && onChange(date)}
      {...rest}
    />
  );
}
```

```tsx
// Usage — the bundler resolves the correct file automatically
import { DatePicker } from "@/components/date-picker/date-picker";
```

> **When to use Platform.select:** small one-liners like shadow styles, font weights, or
> status bar height. When the divergence exceeds ~10 lines, split into platform files.

---

## Anti-Patterns

### 1. Using FlatList for Large Lists

FlatList creates and destroys views on scroll — no recycling. For lists beyond ~100 items, this
causes frame drops and high memory usage. FlashList's recycling architecture maintains 60fps
by reusing off-screen views.

**Symptoms:** janky scrolling, high JS thread usage, `VirtualizedList: You have a large list`
warning.

**Fix:** Replace `FlatList` with `FlashList`. The API is nearly identical — change the import,
add `estimatedItemSize` (v1), and verify in release mode. See Pattern 2 above.

---

### 2. Inline Styles Instead of StyleSheet.create or NativeWind

Inline style objects are re-created on every render, triggering unnecessary bridge
serialization and layout recalculations. This adds up in lists and animated views.

#### Bad: inline styles

```tsx
// ❌ New object on every render — no memoization, no static analysis
export function Card({ title }: { title: string }) {
  return (
    <View style={{ padding: 16, backgroundColor: "#fff", borderRadius: 8 }}>
      <Text style={{ fontSize: 18, fontWeight: "bold", color: "#111" }}>
        {title}
      </Text>
    </View>
  );
}
```

#### Good: NativeWind utility classes (preferred in NativeWind projects)

```tsx
// ✅ Styles resolved at build time — zero runtime overhead
export function Card({ title }: { title: string }) {
  return (
    <View className="p-4 bg-white rounded-lg">
      <Text className="text-lg font-bold text-gray-900">{title}</Text>
    </View>
  );
}
```

#### Good: StyleSheet.create (when not using NativeWind)

```tsx
// ✅ Static style objects created once — bridge-efficient
import { StyleSheet, View, Text } from "react-native";

export function Card({ title }: { title: string }) {
  return (
    <View style={styles.card}>
      <Text style={styles.title}>{title}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { padding: 16, backgroundColor: "#fff", borderRadius: 8 },
  title: { fontSize: 18, fontWeight: "bold", color: "#111" },
});
```

---

## Quick Reference

| Concern | Recommended Tool | Notes |
|---|---|---|
| Navigation | Expo Router (file-based) | `app/` directory maps to routes; uses React Navigation under the hood |
| Large lists | `@shopify/flash-list` | Drop-in FlatList replacement with view recycling |
| Client state | Zustand | UI state: modals, filters, theme. Small, no boilerplate |
| Server state | TanStack Query | Fetching, caching, refetch, pagination, optimistic updates |
| Styling | NativeWind (Tailwind) | Build-time resolution; `className` prop. Fallback: `StyleSheet.create` |
| Safe areas | `react-native-safe-area-context` | Wrap root in `SafeAreaProvider`; use NativeWind `p-safe` or `<SafeAreaView>` |
| Keyboard | `react-native-keyboard-controller` | Replaces `KeyboardAvoidingView`; smoother animations, works with ScrollView |
| Platform code | `.ios.tsx` / `.android.tsx` files | Auto-resolved by bundler. Use `Platform.select` for minor tweaks only |
| Dynamic routes | `app/[param].tsx` | Access via `useLocalSearchParams<{ param: string }>()` |
| Route groups | `app/(group)/` | Organize without affecting URL; each group can have its own `_layout.tsx` |
| Typed routes | `expo-router` Href type | Enable `partialRouteTypes` in app.json for incremental generation |
| Animations | `react-native-reanimated` | Run on UI thread; never use `Animated` from core RN for complex animations |
