---
description: Create detailed implementation plans through interactive research and iteration
---

# Implementation Plan

You are tasked with creating detailed implementation plans through an interactive, iterative process. You should be skeptical, thorough, and work collaboratively with the user to produce high-quality technical specifications.

## Core Principle: Deep User Interviews

**Before writing any plan, conduct thorough interviews using `AskUserQuestion`.**

You must deeply understand the user's intent, constraints, and preferences. Don't ask obvious questions - dig into the non-obvious aspects that will affect implementation success.

### Interview Philosophy

- **Assume nothing** - Even if something seems obvious, verify it
- **Go deep** - Surface-level answers aren't enough; follow up
- **Cover all angles** - Technical, UX, business logic, edge cases, tradeoffs
- **Continue until complete** - Don't stop interviewing prematurely
- **Ask non-obvious questions** - Skip generic questions; focus on decisions that actually matter

### What to Interview About

| Domain | Example Non-Obvious Questions |
|--------|-------------------------------|
| **Technical** | "Should this fail silently or surface errors to the user?", "What's the expected data volume - tens, thousands, or millions?", "Should this work offline?" |
| **UI/UX** | "What should happen during the 2-3 second loading state?", "If validation fails, should we block submission or show inline warnings?", "Mobile-first or desktop-first?" |
| **Edge Cases** | "What if the user has no data yet - empty state?", "What happens on partial failure?", "How do we handle rate limiting?" |
| **Tradeoffs** | "Speed vs completeness - which matters more here?", "Should we optimize for first-time users or power users?", "Build custom or use existing library?" |
| **Business Logic** | "Who can see this data - just the owner or their team too?", "Should soft-delete or hard-delete?", "What's the audit trail requirement?" |
| **Integration** | "Does this need to sync with any external systems?", "What's the source of truth if data conflicts?", "Webhook or polling?" |

### Interview Cadence

1. **Initial interview** (Step 1) - Understand the big picture
2. **Research-informed interview** (Step 2) - Ask questions based on what you found in the codebase
3. **Design decision interview** (Step 3) - Get buy-in on approach and structure
4. **Review interview** (Step 5) - Validate the plan covers everything

**Keep interviewing until:**
- All ambiguities are resolved
- User has made decisions on all tradeoffs
- Edge cases have been discussed
- You could implement without asking more questions

---

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:
   - If a file path or ticket reference was provided, read it FULLY first
   - Begin the research process

2. **If no parameters provided**, respond with:
```
I'll help you create a detailed implementation plan. Let me start by understanding what we're building.

Please provide:
1. The task/ticket description (or reference to a ticket file)
2. Any relevant context, constraints, or specific requirements

Tip: You can invoke with a file: `/create_plan path/to/ticket.md`
```

Then wait for the user's input.

---

## Process Steps

### Step 1: Context Gathering & Initial Interview

1. **Read all mentioned files FULLY** - no partial reads

2. **Spawn research tasks** to understand the codebase:
   - Use **Explore** agent to find related files
   - Understand current implementation patterns

3. **Begin the initial interview** - Ask about the big picture:

```
AskUserQuestion({
  questions: [
    {
      question: "What's the primary goal - solving a user pain point, technical debt, or new capability?",
      header: "Goal",
      options: [
        { label: "User pain point", description: "Users are struggling with something" },
        { label: "Technical debt", description: "Existing code needs improvement" },
        { label: "New capability", description: "Adding something that doesn't exist" },
        { label: "Compliance/security", description: "Required for regulatory or security reasons" }
      ],
      multiSelect: false
    },
    {
      question: "What's the acceptable complexity level for this solution?",
      header: "Complexity",
      options: [
        { label: "Minimal (Recommended)", description: "Simplest thing that works, iterate later" },
        { label: "Moderate", description: "Handle known edge cases upfront" },
        { label: "Comprehensive", description: "Production-hardened from day one" }
      ],
      multiSelect: false
    }
  ]
})
```

4. **Follow up based on answers** - Each answer should trigger deeper questions

### Step 2: Research & Discovery Interview

After initial research completes:

1. **Present findings** from codebase exploration

2. **Ask research-informed questions** - Questions specific to what you found in the codebase. Adapt to whatever patterns and tech stack the project uses.

3. **Dig into technical concerns** - error handling, failure modes, observability needs

4. **Explore UI/UX decisions** (if applicable) - loading states, empty states, responsive behavior

5. **Continue until all aspects are covered** - Don't move to Step 3 until you've asked about:
   - [ ] Error handling approach
   - [ ] Performance expectations
   - [ ] Security/permissions model
   - [ ] Mobile/responsive considerations (if UI)
   - [ ] Accessibility requirements (if UI)
   - [ ] Data validation rules
   - [ ] Caching strategy (if applicable)

### Step 3: Design Decision Interview

Once you have a proposed approach:

1. **Present design options** with tradeoffs — always offer at least 2 approaches

2. **Validate phase structure** — ask if the granularity is right

3. **Get buy-in** on the approach before writing the plan

### Step 4: Detailed Plan Writing

After all interviews complete:

1. **Ensure directory exists**: `mkdir -p plans` (or whatever convention the project uses)

2. **Write the plan** to `plans/YYYY-MM-DD-<description>.md`

3. **Include all decisions from interviews** - The plan should reflect everything discussed

**Plan Template:**

````markdown
# [Feature/Task Name] Implementation Plan

## Overview
[Brief description]

## Interview Summary
[Key decisions made during interviews - reference specific choices]

## Current State Analysis
[What exists now, what's missing]

## Desired End State
[Specification of completion]

## What We're NOT Doing
[Explicit scope boundaries]

## Implementation Approach
[High-level strategy based on interview decisions]

## Phase 1: [Name]

### Overview
[What this accomplishes]

### Changes Required:
**File**: `path/to/file.ext`
**Changes**: [Summary]

### Success Criteria:
#### Automated:
- [ ] Type checking passes
- [ ] Tests pass

#### Manual:
- [ ] [Specific verification]

---

## Phase 2: [Name]
[Continue pattern...]

---

## Edge Cases Addressed
[From interview discussions]

## Testing Strategy
[Unit, integration, manual steps]

## References
[Links to tickets, similar code]
````

### Step 5: Review Interview

1. **Present the plan and ask for structured feedback**:

```
AskUserQuestion({
  questions: [
    {
      question: "Does the plan capture everything we discussed?",
      header: "Completeness",
      options: [
        { label: "Yes, complete", description: "All decisions are reflected" },
        { label: "Missing something", description: "I'll specify what's missing" },
        { label: "Misunderstood something", description: "Some decisions are wrong" }
      ],
      multiSelect: false
    },
    {
      question: "Ready to proceed?",
      header: "Status",
      options: [
        { label: "Approved", description: "Run validation and finalize" },
        { label: "Need changes", description: "I'll specify what to adjust" }
      ],
      multiSelect: false
    }
  ]
})
```

2. **Iterate until approved**

### Step 6: Automatic Validation (Always Runs)

After approval, validate tech choices:

1. **Extract new/novel tech choices** from the plan (skip established project patterns)

2. **Research each** using WebSearch:
   - `"[library] best practices [current year]"`
   - `"[library] vs alternatives [current year]"`
   - `"[pattern] deprecated [current year]"`

3. **Assess as:** VALID | OUTDATED | DEPRECATED | RISKY

4. **Append validation section** to plan file:

```markdown
---

## Tech Validation (Auto-Generated)

**Date:** [timestamp]
**Status:** [VALIDATED | NEEDS REVIEW]

### Validated Choices
- [Choice 1] - [brief finding]
- [Choice 2] - [brief finding]

### Issues Found
- [Choice 3] - [issue and recommendation]

### Sources
- [URLs used for validation]
```

5. **Report results** and the path to the plan file. If using claude-loop, remind the user they can now run:
```
./claude-loop <plan-file>
```

---

## Important Guidelines

1. **Interview deeply** - Don't accept surface answers; follow up
2. **Ask non-obvious questions** - Skip "what color should the button be"
3. **Continue until complete** - Every ambiguity should be resolved
4. **Track decisions** - The plan must reflect all interview outcomes
5. **No open questions in final plan** - If something is unclear, interview more

## Skip Validation For

- Established project patterns (anything documented in CLAUDE.md)
- Standard library usage
- Patterns already in use in the codebase

Focus validation on new libraries, major upgrades, or novel patterns.
