# claude-orchestrator

Turn any Claude Code session into Anthropic's orchestrator-worker multi-agent architecture, with infinite-context execution via session looping.

Based on [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) by Anthropic's engineering team.

## The Problem

- Claude Code has a 200k token context window. Complex tasks exhaust it.
- No memory shared between sessions. Context is lost on `/clear`.
- Single-agent sessions mix research, implementation, and review into one context, wasting tokens on verbose tool output.
- Long plans can't be executed end-to-end without context degradation.

## The Solution

**4 specialized subagents** that run in their own context windows, keeping the orchestrator light:

| Agent | Model | Role | Isolation |
|---|---|---|---|
| **You (orchestrator)** | Opus | Plan, delegate, synthesize | Main session |
| `researcher` | Sonnet | Explore codebase, return distilled findings | Read-only |
| `implementer` | Sonnet | Write code | Git worktree |
| `reviewer` | Sonnet | Review changes, run tests | Read-only |
| `planner` | Opus | Design architecture, write plans to disk | Read-only |

**`claude-loop`** — a bash script that executes plans across fresh sessions, giving you effectively infinite context with no degradation.

## Install

```bash
git clone git@github.com:martowasser/claude-loop.git ~/claude-loop

# Install into any project
~/claude-loop/install.sh /path/to/your/project
```

This adds to your project:

```
your-project/
├── .claude/
│   ├── agents/
│   │   ├── researcher.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   └── planner.md
│   └── orchestration.md
├── claude-loop
└── CLAUDE.md              ← @import .claude/orchestration.md appended
```

All runtime files (state, progress, signal, scratch, logs) are automatically added to `.gitignore`.

## How It Works

### The Intended Workflow

#### Phase 1: Plan (interactive)

Use Claude Code as you normally would. Create a plan through conversation:

```
$ claude

You:    "I need to add a discount system to quotes"
Claude: *asks questions, validates requirements, researches codebase*
        → Writes thoughts/shared/plans/2026-03-06-quote-discounts.md
```

This phase is fully interactive. You steer the conversation, answer questions, make decisions. The output is a plan file on disk.

#### Phase 2: Execute (autonomous)

Hand the plan to `claude-loop`. It runs the implementation across fresh sessions:

```
$ ./claude-loop thoughts/shared/plans/2026-03-06-quote-discounts.md
```

Or from inside a Claude session:

```
You:    "Run the loop for this plan"
Claude: *launches claude-loop in the background*
```

Each session gets a full fresh 200k context. No compaction, no degradation.

#### Phase 3: Resume (next day, new terminal)

```
$ claude

You:    "hey"
Claude: "I see you were working on the quote discount system.
         Steps 1-5 done, step 6 next. Continue?"
```

The orchestration rules tell Claude to check for a state file on every session start.

### What Happens Inside `claude-loop`

```
Session 1 (fresh 200k context)
├── Reads plan file
├── Spawns researcher → explores codebase
├── Spawns implementer → schema + migration
├── Spawns implementer → backend service
├── Commits changes
├── Updates .claude/state.md after each subagent
├── Writes signal: echo "continue" > .claude/signal
└── Loop appends summary to .claude/progress.md

── checkpoint: shows diff, asks to approve ──

Session 2 (fresh 200k context)
├── Reads state.md (steps 1-3 done)
├── Reads plan file (source of truth, may have been edited)
├── Checks for .claude/feedback.md (consumed if found)
├── Spawns implementer → frontend form
├── Spawns reviewer → validates everything
├── Commits changes
├── Writes signal: echo "done" > .claude/signal
└── Loop appends summary to .claude/progress.md

═══ Plan complete ═══
```

## Four Modes

### Interactive (default)

Shows a checkpoint between each session where you can review changes:

```
┌──────────────────────────────────────────┐
│         SESSION 1 COMPLETE               │
└──────────────────────────────────────────┘

── Files changed ──
 prisma/schema/quote.prisma  | 3 +++
 apps/api/src/services/quote.service.ts | 12 +++---

  [c] Continue  [d] Full diff  [s] State  [p] Progress  [q] Stop
```

```bash
./claude-loop plan.md
```

### tmux

Same as interactive but with a live monitoring pane showing state, progress, and git log:

```
┌──────────────────────┬──────────────────────────────────────┐
│                      │                                      │
│  ── State ──         │  ═══ Session 2 ═══                   │
│  - [x] Step 1       │                                      │
│  - [x] Step 2       │  [Claude working...]                 │
│  - [ ] Step 3       │                                      │
│                      │                                      │
│  ── Progress ──      │                                      │
│  Session 1 — done    │                                      │
│                      │                                      │
│  ── Git Log ──       │                                      │
│  a1b2c3d Add model   │                                      │
│                      │                                      │
│  (refreshes every 2s)│                                      │
└──────────────────────┴──────────────────────────────────────┘
```

```bash
./claude-loop plan.md --tmux
```

Detach with `Ctrl-B d`, reattach with `tmux attach`.

### Supervised

Designed to run from inside another Claude session. No checkpoints — writes PID + log files, checks for feedback between sessions.

```bash
./claude-loop plan.md --supervised
```

### Yolo

No checkpoints, no supervision. Runs until done or max iterations.

```bash
./claude-loop plan.md --yolo
```

## Signaling

Sessions communicate with the loop via a signal file. Claude writes this as its last action:

```bash
echo "continue" > .claude/signal    # more work to do
echo "done" > .claude/signal        # all complete
echo "failed" > .claude/signal      # session failed
```

On `failed`: the loop **reverts all code changes** to the pre-session git commit but **preserves** state and progress files. The next session retries with clean code and full knowledge of what went wrong.

## Failure Recovery

```
Session 3 fails (bad code, type errors, etc.)
    │
    ├── .claude/signal reads "failed"
    ├── Loop saves state.md + progress.md to temp
    ├── git reset --hard to pre-session commit
    ├── git clean (excluding .claude/)
    ├── Restores state.md + progress.md
    └── Next session starts with clean code + full history
```

## Course-Correcting Mid-Flight

### Small fix — feedback injection

Write `.claude/feedback.md` (or tell your supervising Claude session). The next session reads it, incorporates it, and deletes it. Loop keeps running.

### Bigger change — edit the plan

1. Stop the loop (`q` at checkpoint, or `kill $(cat .claude/loop.pid)`)
2. Edit the plan file (clean, current version)
3. Add `## Plan Changes` to state.md noting what changed and what needs redoing
4. Resume: `./claude-loop --resume`

The next session reads the updated plan, sees the change log, re-implements affected steps, and removes entries from `## Plan Changes` once addressed.

## Key Design Principle: Stateless Subagents

Subagents are stateless workers. They receive a self-contained task and return a structured summary. They do NOT receive:
- Plan context or project history
- Knowledge of other subagents or previous sessions
- Instructions to "continue" something

The orchestrator is the memory. It distills what the next subagent needs into the minimum viable prompt. If a subagent bails out at 70%, the orchestrator identifies the remaining 30% and delegates it as a fresh, independent task.

## Progress Tracking

Two files work together:

| File | Type | Purpose |
|---|---|---|
| `.claude/state.md` | Overwritten | Current status, progress checklist, decisions, context for next session |
| `.claude/progress.md` | Append-only | Chronological log of every session with timestamp and outcome |

Progress auto-archives to `progress_001.md`, `progress_002.md`, etc. after 20 entries to keep the active file compact.

## Scratch Files

Researcher and reviewer write findings incrementally to `.claude/scratch/` as a safety net. If a subagent exhausts its context before returning, the orchestrator reads the scratch file to recover partial work. Scratch files are never passed between subagents — only the orchestrator reads them.

## Key Files at Runtime

| File | Purpose | Persists |
|---|---|---|
| `thoughts/shared/plans/*.md` | The plan (source of truth) | Committed |
| `.claude/state.md` | Current progress + decisions | On disk, gitignored |
| `.claude/progress.md` | Append-only session history | On disk, gitignored |
| `.claude/progress_*.md` | Archived progress (after 20 entries) | On disk, gitignored |
| `.claude/signal` | Session exit signal (done/continue/failed) | Deleted between sessions |
| `.claude/feedback.md` | Async corrections from user | Consumed on read |
| `.claude/scratch/` | Subagent safety net (partial findings) | On disk, gitignored |
| `.claude/loop.pid` | Running loop process ID | Deleted on exit |
| `.claude/loop.log` | Full loop output (supervised mode) | On disk, gitignored |
| `.claude/agent-memory-local/` | Per-agent persistent learnings | On disk, gitignored |

## CLI Reference

```bash
# Execute a plan
./claude-loop <plan-file>

# Modes
./claude-loop <plan-file> --tmux               # live monitoring pane
./claude-loop <plan-file> --yolo               # no checkpoints
./claude-loop <plan-file> --supervised         # for launching from Claude

# Options
./claude-loop <plan-file> --budget 2.00        # cap each session at $2
./claude-loop <plan-file> --model sonnet       # use sonnet instead of opus
./claude-loop <plan-file> --base-branch main   # create feature branch from main
./claude-loop <plan-file> --max-iterations 10  # limit session count

# Resume after stopping
./claude-loop --resume
./claude-loop --resume --supervised
./claude-loop --resume --tmux
```

## What Gets Committed vs Stays Local

**Committed (shared with team):**
- `.claude/agents/*.md` — agent definitions
- `.claude/orchestration.md` — orchestration rules
- `thoughts/shared/plans/*.md` — plan files

**Local (per-developer, gitignored):**
- `.claude/state.md` — active progress
- `.claude/progress.md` — session history
- `.claude/signal` — session signal
- `.claude/feedback.md` — async feedback
- `.claude/scratch/` — subagent safety net
- `.claude/loop.pid` / `.claude/loop.log` — loop runtime
- `.claude/agent-memory-local/` — agent learnings
- `claude-loop` — the script

## Customization

### Add project-specific agents

Create new `.md` files in `.claude/agents/`:

```yaml
---
name: db-migrator
description: "Use when creating or modifying database migrations"
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
memory: local
maxTurns: 30
---

Your system prompt here...
```

### Override model choices

Edit the `model:` field in any agent definition. Use `haiku` for cheap tasks, `sonnet` for most work, `opus` for complex reasoning.

### Adjust orchestration rules

Edit `.claude/orchestration.md` to change scaling rules, delegation patterns, or add new commands the orchestrator should recognize.

## Architecture Reference

- [How we built our multi-agent research system — Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Building Effective Agents — Anthropic](https://www.anthropic.com/research/building-effective-agents)
- [Building agents with the Claude Agent SDK — Anthropic](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [.loop — jandrikus](https://github.com/jandrikus/loop) (inspiration for signal files, progress archiving, failure revert, tmux)
