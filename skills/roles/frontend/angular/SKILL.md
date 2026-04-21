---
name: frontend-angular
description: >
  Angular development patterns: standalone components, signals, dependency injection, reactive forms, RxJS, routing.
  Trigger: When building Angular components, services, forms, or configuring routing and state management.
globs:
  - "**/*.component.ts"
  - "**/*.service.ts"
  - "**/*.module.ts"
  - "**/angular.json"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

- Building Angular components, directives, or pipes with the standalone API (no NgModule).
- Managing reactive state with Angular Signals (`signal()`, `computed()`, `linkedSignal()`, `effect()`).
- Injecting services using the functional `inject()` API instead of constructor injection.
- Creating or validating reactive forms with `FormBuilder`, typed `FormGroup`, and validators.
- Configuring HTTP clients with functional interceptors via `provideHttpClient` and `withInterceptors`.
- Setting up routing with `provideRouter`, lazy-loaded routes, and route guards.

---

## Critical Patterns

### Pattern 1: Standalone Components (No NgModule)

Modern Angular uses standalone components exclusively. Every component declares its own
imports directly in the `@Component` decorator. Application bootstrap uses `bootstrapApplication`
with provider functions instead of `NgModule`.

```typescript
// app.config.ts
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors, withFetch } from '@angular/common/http';
import { routes } from './app.routes';
import { authInterceptor } from './interceptors/auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient(withFetch(), withInterceptors([authInterceptor])),
  ],
};
```

```typescript
// main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app/app.component';
import { appConfig } from './app/app.config';

bootstrapApplication(AppComponent, appConfig).catch((err) => console.error(err));
```

```typescript
// user-card.component.ts
import { Component, input } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-user-card',
  standalone: true,                        // explicit — default in Angular 19+
  imports: [DatePipe, RouterLink],         // declare deps per component
  template: `
    <article>
      <h3>{{ name() }}</h3>
      <p>Joined: {{ joinedAt() | date:'mediumDate' }}</p>
      <a [routerLink]="['/users', id()]">View profile</a>
    </article>
  `,
})
export class UserCardComponent {
  id = input.required<string>();
  name = input.required<string>();
  joinedAt = input.required<Date>();
}
```

> **Rule**: Never create an `NgModule` for new code. Use `imports` in `@Component` for
> template dependencies and `providers` arrays in `app.config.ts` for application-wide services.

---

### Pattern 2: Signals for Reactive State

Signals are Angular's primary reactivity primitive. Use `signal()` for writable state,
`computed()` for derived read-only state, `linkedSignal()` for derived writable state,
and `effect()` for side effects that react to signal changes.

```typescript
import { Component, signal, computed, effect, linkedSignal } from '@angular/core';

@Component({
  selector: 'app-counter',
  standalone: true,
  template: `
    <p>Count: {{ count() }}</p>
    <p>Double: {{ double() }}</p>
    <button (click)="increment()">+1</button>
    <button (click)="reset()">Reset</button>
  `,
})
export class CounterComponent {
  // Writable signal — source of truth
  count = signal(0);

  // Read-only derived signal — recalculates when count changes
  double = computed(() => this.count() * 2);

  // Linked signal — derived but writable, re-syncs when source changes
  // Useful for "defaults that can be overridden"
  label = linkedSignal(() => `Count is ${this.count()}`);

  constructor() {
    // Side effect — runs whenever referenced signals change
    effect(() => {
      console.log(`Count changed to ${this.count()}`);
    });
  }

  increment(): void {
    this.count.update((c) => c + 1);
  }

  reset(): void {
    this.count.set(0);
  }
}
```

> **Rule**: Prefer `computed()` over `effect()` when deriving state. Use `effect()` only
> for true side effects (logging, localStorage, API calls). Never mutate signals inside
> `computed()`.

---

### Pattern 3: Dependency Injection with `inject()`

The functional `inject()` API replaces constructor-based injection. It is more concise,
works in any injection context, and enables better composition through helper functions.

```typescript
// auth.service.ts
import { Injectable, inject, signal, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);

  private currentUser = signal<User | null>(null);

  isAuthenticated = computed(() => this.currentUser() !== null);
  user = this.currentUser.asReadonly();

  login(credentials: LoginPayload): void {
    this.http.post<User>('/api/auth/login', credentials).subscribe({
      next: (user) => this.currentUser.set(user),
      error: (err) => console.error('Login failed', err),
    });
  }

  logout(): void {
    this.currentUser.set(null);
    this.router.navigate(['/login']);
  }
}
```

```typescript
// Composable injection functions — reusable across components
import { inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { map } from 'rxjs';

export function injectRouteParam(param: string) {
  return inject(ActivatedRoute).params.pipe(map((p) => p[param]));
}

// Usage in component
export class UserDetailComponent {
  userId$ = injectRouteParam('id');
}
```

> **Rule**: Always use `inject()` over constructor injection. It enables extracting
> injection logic into reusable functions, which constructor injection cannot do.

---

### Pattern 4: Reactive Forms with FormBuilder + Typed FormGroup

Use `FormBuilder` with `inject()` to create strongly-typed reactive forms.
Angular's typed forms (since v14) catch mismatches at compile time.

```typescript
import { Component, inject } from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators,
  AbstractControl,
  ValidationErrors,
} from '@angular/forms';

@Component({
  selector: 'app-registration',
  standalone: true,
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      <label>
        Email
        <input formControlName="email" type="email" />
      </label>
      @if (form.controls.email.errors?.['email']) {
        <span class="error">Invalid email</span>
      }

      <label>
        Password
        <input formControlName="password" type="password" />
      </label>
      @if (form.controls.password.errors?.['minlength']) {
        <span class="error">Minimum 8 characters</span>
      }

      <fieldset formGroupName="profile">
        <legend>Profile</legend>
        <input formControlName="firstName" placeholder="First name" />
        <input formControlName="lastName" placeholder="Last name" />
      </fieldset>

      <button type="submit" [disabled]="form.invalid">Register</button>
    </form>
  `,
})
export class RegistrationComponent {
  private fb = inject(FormBuilder);

  // Typed FormGroup — TS infers the shape from the builder
  form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
    profile: this.fb.nonNullable.group({
      firstName: ['', Validators.required],
      lastName: ['', Validators.required],
    }),
  });

  onSubmit(): void {
    if (this.form.invalid) return;

    // form.getRawValue() is fully typed:
    // { email: string; password: string; profile: { firstName: string; lastName: string } }
    const value = this.form.getRawValue();
    console.log(value);
  }
}
```

> **Rule**: Always use `fb.nonNullable.group()` to get non-nullable typed controls.
> Access errors via `form.controls.fieldName.errors` — the type system will guide you.

---

## Anti-Patterns

### Anti-Pattern 1: Using NgModule When Standalone Is Available

NgModules add indirection and boilerplate. Every new component requires editing a
module file, which creates coupling and slows development.

```typescript
// ❌ BAD — NgModule-based component
@NgModule({
  declarations: [DashboardComponent, WidgetComponent],
  imports: [CommonModule, SharedModule, RouterModule.forChild(routes)],
  exports: [DashboardComponent],
})
export class DashboardModule {}

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
})
export class DashboardComponent {}
```

```typescript
// ✅ GOOD — Standalone component, self-contained
@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [WidgetComponent, RouterLink, DatePipe],
  templateUrl: './dashboard.component.html',
})
export class DashboardComponent {}

// Route config — no module needed
export const dashboardRoutes: Routes = [
  {
    path: '',
    component: DashboardComponent,
  },
  {
    path: ':id',
    loadComponent: () =>
      import('./detail/detail.component').then((m) => m.DetailComponent),
  },
];
```

> Standalone components are the default since Angular 19. Modules exist only for
> legacy compatibility.

---

### Anti-Pattern 2: Manual Subscriptions Without Cleanup

Subscribing to observables without cleanup causes memory leaks. Components that
manually call `.subscribe()` must ensure unsubscription on destroy.

```typescript
// ❌ BAD — subscription leaks when component is destroyed
@Component({ /* ... */ })
export class BadComponent {
  private http = inject(HttpClient);

  ngOnInit(): void {
    this.http.get('/api/data').subscribe((data) => {
      // This callback may fire AFTER the component is destroyed
      this.processData(data);
    });

    interval(1000).subscribe(() => {
      // This runs FOREVER — classic memory leak
      this.tick();
    });
  }
}
```

```typescript
// ✅ GOOD — Option A: takeUntilDestroyed (for imperative subscriptions)
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { DestroyRef, inject } from '@angular/core';

@Component({ /* ... */ })
export class GoodComponentA {
  private http = inject(HttpClient);
  private destroyRef = inject(DestroyRef);

  ngOnInit(): void {
    this.http
      .get('/api/data')
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((data) => this.processData(data));

    interval(1000)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.tick());
  }
}
```

```typescript
// ✅ GOOD — Option B: async pipe (declarative, no manual subscription)
import { AsyncPipe } from '@angular/common';

@Component({
  standalone: true,
  imports: [AsyncPipe],
  template: `
    @if (data$ | async; as data) {
      <app-widget [data]="data" />
    }
  `,
})
export class GoodComponentB {
  private http = inject(HttpClient);
  data$ = this.http.get<WidgetData>('/api/data');
}
```

```typescript
// ✅ GOOD — Option C: toSignal (convert observable to signal — best of both worlds)
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  standalone: true,
  template: `
    @if (data(); as data) {
      <app-widget [data]="data" />
    }
  `,
})
export class GoodComponentC {
  private http = inject(HttpClient);
  data = toSignal(this.http.get<WidgetData>('/api/data'));
}
```

> **Preference order**: `toSignal()` > `async` pipe > `takeUntilDestroyed()`.
> Use signals as the default. Fall back to RxJS only for complex async flows
> (debounce, merge, switchMap).

---

## Quick Reference

| Concept                  | Modern API                                            | Legacy (avoid)                     |
| ------------------------ | ----------------------------------------------------- | ---------------------------------- |
| Component declaration    | `standalone: true` + `imports` in `@Component`        | `NgModule` declarations            |
| App bootstrap            | `bootstrapApplication(App, appConfig)`                | `platformBrowserDynamic().bootstrapModule()` |
| Dependency injection     | `inject(Service)` function                            | `constructor(private svc: Service)` |
| HTTP setup               | `provideHttpClient(withInterceptors([...]))`          | `HttpClientModule` import          |
| Routing setup            | `provideRouter(routes)`                               | `RouterModule.forRoot(routes)`     |
| Writable state           | `signal(initialValue)`                                | Component property + `ChangeDetectorRef` |
| Derived state            | `computed(() => ...)`                                 | `get` accessor + manual change detection |
| Derived writable state   | `linkedSignal(() => ...)`                             | No equivalent                      |
| Side effects             | `effect(() => ...)`                                   | `ngOnChanges` / `ngDoCheck`        |
| Observable to signal     | `toSignal(obs$)`                                      | Manual subscribe + signal.set      |
| Signal to observable     | `toObservable(sig)`                                   | No equivalent                      |
| Sub cleanup              | `takeUntilDestroyed(destroyRef)`                      | `Subject` + `takeUntil` + `ngOnDestroy` |
| Template sub             | `async` pipe or `toSignal()`                          | Manual subscribe in `ngOnInit`     |
| Forms                    | `fb.nonNullable.group({...})`                         | `new FormGroup({...})` untyped     |
| Control flow             | `@if`, `@for`, `@switch`                              | `*ngIf`, `*ngFor`, `[ngSwitch]`   |
| Lazy loading             | `loadComponent: () => import(...)`                    | `loadChildren` with module         |
| Functional interceptor   | `(req, next) => next(req).pipe(...)`                  | Class-based `HttpInterceptor`      |
| Functional guard         | `() => inject(Auth).isAuthenticated()`                | Class-based `CanActivate`          |
