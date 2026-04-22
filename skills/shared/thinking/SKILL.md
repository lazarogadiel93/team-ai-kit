---
name: thinking
description: >
  Cognitive analysis patterns for decomposing complex problems before proposing solutions.
  Trigger: When analyzing a problem, evaluating alternatives, assessing risks, or when input is ambiguous.
globs:
  - "**/*"
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Load this skill when:

- The user describes a problem or feature without clear definition
- There are multiple possible alternatives and you need to evaluate tradeoffs
- You detect hidden risks in the proposed approach
- The scope seems larger than necessary (possible overengineering)
- A decision has long-term consequences that need analysis
- The problem is ambiguous and needs decomposition before coding

---

## Critical Patterns

### Pattern 1: Decompose Before You Solve

Before proposing ANY solution, define precisely:

1. **What is the REAL problem?** (not the symptom)
2. **What assumptions are being made?**
3. **What risks exist in each alternative?**
4. **Is there a simpler solution?**

```
❌ BAD decomposition:
   Problem: "The app is slow"
   Solution: "Add Redis caching"

✅ GOOD decomposition:
   Symptom: "The app is slow"
   Question: Where is it slow? → API response time
   Question: Which endpoint? → GET /orders
   Question: Why is it slow? → N+1 queries (profiler shows 200 queries per request)
   Root cause: Missing JOIN in the orders query
   Solution: Add eager loading → fix the query
   Validation: Response time dropped from 2s to 50ms
```

### Pattern 2: Decision Matrix for Technical Choices

When choosing between alternatives, make the comparison EXPLICIT.

```
Example: Choosing a message queue

| Criteria          | Weight | RabbitMQ | Kafka   | SQS     |
| ----------------- | ------ | -------- | ------- | ------- |
| Throughput needed  | High   | Medium   | High    | Medium  |
| Ordering guarantee | High   | Per-queue| Per-part| FIFO opt|
| Ops complexity     | Medium | Medium   | High    | Low     |
| Team familiarity   | High   | Low      | Medium  | High    |
| Cost at our scale  | Medium | Self-host| Self-host| Pay/use|

Winner for THIS context: SQS
WHY: Our throughput is moderate, team knows AWS well,
and we don't want to operate infrastructure.
Kafka would be overengineering at our current scale.
```

```
Example: Monolith vs Microservices

| Criteria           | Weight | Monolith    | Microservices |
| ------------------ | ------ | ----------- | ------------- |
| Team size          | High   | 4 devs ✅   | 4 devs ❌     |
| Deployment speed   | Medium | Fast ✅      | Complex ❌    |
| Independent scaling| Low    | No ❌        | Yes ✅        |
| Debugging ease     | High   | Easy ✅      | Distributed ❌|

Winner: Monolith — team is too small for microservices.
Revisit when team reaches 15+ developers.
```

### Pattern 3: Prioritize Simplicity

```
Unnecessary complexity → technical debt
Simple solution that works > elegant solution that doesn't exist yet
```

The simplest solution that meets ALL requirements wins. Not the most "architecturally pure" one.

```
❌ BAD: "Let's build a plugin system with dynamic module loading
        so we can add payment providers later"
        (You have 1 payment provider and no plans for more)

✅ GOOD: Implement Stripe directly. When a second provider appears,
         THEN extract the interface.
```

**The Rule of Three:**
- First time: just do it
- Second time: note the duplication
- Third time: NOW abstract

### Pattern 4: Validate Before You Build

```
idea → hypothesis → minimal validation → implementation
```

Do NOT abstract without at least 2 real cases that require it.

```
❌ BAD thinking:
   "We MIGHT need to support multiple databases in the future,
    so let's build a database abstraction layer now"

✅ GOOD thinking:
   "We use PostgreSQL. If we ever need another DB, we'll abstract then.
    Right now, the abstraction adds complexity with zero benefit."
```

### Pattern 5: Risk Assessment — Reversibility Matters

Not all decisions are equal. Classify them:

```
Type 1 (One-way door): Hard/impossible to reverse
  Examples: Database schema in production, public API contract,
            choosing a primary language, data deletion
  → Analyze carefully. Get team input. Prototype first.

Type 2 (Two-way door): Easy to reverse
  Examples: Library choice (can swap), internal API design,
            folder structure, CI configuration
  → Decide quickly. Move fast. Adjust later if needed.
```

```
❌ BAD: Spending 2 weeks deciding between two logging libraries (Type 2)
✅ GOOD: Pick one in 30 minutes, move on

❌ BAD: Choosing the database in 30 minutes (Type 1)
✅ GOOD: Benchmark, prototype, evaluate for 1-2 days
```

### Pattern 6: Scope Check — YAGNI

Before adding ANY feature or abstraction, ask:

1. Is someone asking for this RIGHT NOW?
2. What is the cost of adding it LATER vs NOW?
3. Am I building for a real requirement or an imagined future?

```
❌ BAD scope creep:
   User asks: "Add a login page"
   Agent builds: Login + registration + password reset + OAuth + 2FA + admin panel

✅ GOOD scope control:
   User asks: "Add a login page"
   Agent: "I'll implement email/password login. Do you also need:
           - Registration? (separate task)
           - Password reset? (separate task)
           - OAuth providers? (separate task)"
```

### Pattern 7: Structured Problem-Solving Template

For any non-trivial problem, fill in this template mentally before coding:

```
## Problem
[One sentence — what is actually broken or missing?]

## Context
[What do we know? What constraints exist?]

## Assumptions
[What are we taking for granted? Which could be wrong?]

## Options
1. [Option A] — Pros: ... Cons: ... Effort: ...
2. [Option B] — Pros: ... Cons: ... Effort: ...
3. [Do nothing] — Pros: ... Cons: ...

## Recommendation
[Which option and WHY]

## Validation
[How will we know this worked?]
```

**Concrete example:**

```
## Problem
Users report checkout fails intermittently.

## Context
- Happens ~5% of the time
- Only on orders with 10+ items
- Started after last deployment (v2.4.1)

## Assumptions
- The payment provider is not the issue (their status page is green)
- It's not a client-side issue (happens across browsers)

## Options
1. Rollback to v2.4.0 — Pros: immediate fix. Cons: loses new features.
2. Debug and fix forward — Pros: keeps features. Cons: takes longer.
3. Add retry logic — Pros: masks the issue. Cons: doesn't fix root cause.

## Recommendation
Option 2. The diff between v2.4.0 and v2.4.1 is small (3 files changed).
Start by reviewing those changes.

## Validation
- Failing test that reproduces the bug
- 0% failure rate in staging with 10+ item orders after the fix
```

---

## Anti-Patterns

### Anti-Pattern 1: Jump Straight to Code

```
❌ User: "I need authentication"
   Agent: "Here's the auth code..."

✅ User: "I need authentication"
   Agent: "What type? Session-based, JWT, OAuth?
           Who are the users? What's the security requirement?
           Do you need role-based access?"
```

### Anti-Pattern 2: Abstract Prematurely

```
❌ Create BaseRepository<T> when you only have one use case

✅ Implement directly. Extract an abstraction at the second real case.
```

### Anti-Pattern 3: Confuse Effort with Progress

```
❌ "I spent 3 days building a perfect config system"
   (But the actual feature isn't started)

✅ Start with hardcoded values → extract config when needed
```

### Anti-Pattern 4: Optimize for the Wrong Audience

```
❌ "This architecture will support 10 million users"
   (Current users: 50. Expected in 1 year: 500)

✅ Design for 10x your current scale, not 1000x.
   You'll rewrite before you hit 10M anyway.
```

### Anti-Pattern 5: Ignore the "Do Nothing" Option

```
❌ "We need to migrate from REST to GraphQL"
   (But REST is working fine and nobody complained)

✅ Ask: "What problem does GraphQL solve that REST doesn't,
        given our current situation?"
   Often the answer is: none. Don't fix what isn't broken.
```

---

## Quick Reference

| Question                                | Action                                              |
| --------------------------------------- | --------------------------------------------------- |
| Is the problem well-defined?            | If not → ask clarifying questions before proceeding |
| Are there simpler alternatives?         | Always explore at least 2 paths                     |
| What is the cost of being wrong?        | Evaluate reversibility (Type 1 vs Type 2 decision)  |
| Is this really needed now?              | YAGNI — don't build for a hypothetical future       |
| Am I solving the symptom or the cause?  | Dig deeper — ask "why" at least 3 times             |
| How will I know this worked?            | Define success criteria BEFORE implementing         |
| Is the scope appropriate?               | If scope grew → split into separate tasks           |
| Am I making assumptions?                | List them explicitly and validate each one           |
