# First-session prompt for `dblaira.github.io` in Cursor

Use this **after** you open the repo in Cursor: **File → Open Folder** (or **Open** on Mac) and select the folder where GitHub Desktop cloned `dblaira.github.io`. Then start a new chat and paste the block below.

---

## Copy everything inside the box

```
CONTEXT
- Repo: dblaira.github.io (GitHub Pages personal site). I manage git with GitHub Desktop; I use Cursor for editing.
- Skill level: beginner. Explain steps in plain language; define terms briefly when you use them (e.g. “commit,” “branch,” “Jekyll”).
- This is a fresh Cursor window just for this repo—don’t assume I have other projects open.

YOUR JOB (first session)
1) Scan the repo and tell me in simple terms: what kind of site this is (e.g. plain HTML/CSS, Jekyll, another static generator) and which files or folders are the “main” ones I’ll edit most often.
2) Give me a minimal “how to work here” checklist: how to preview the site on my computer (exact commands or steps for *this* repo’s setup), what I should avoid changing until I understand it, and how changes get to GitHub Pages (commit + push via GitHub Desktop is fine—walk me through what to click).
3) If anything is missing for local preview (Ruby, Node, etc.), say what it is, why it’s needed, and the simplest way to install or skip it on macOS.
4) Suggest one small, safe first edit I could make to verify everything works (e.g. a visible text change), and what I should see after refresh.

STYLE
- Short sections, numbered steps, no jargon without a one-line definition.
- If you’re unsure about my machine, say “on your Mac, try X first” and give a fallback.
```

---

## Optional: one line to add if you use a specific GitHub account

If you want the agent to remember your username for URLs or troubleshooting, add this line after the first paragraph in the box:

`My GitHub username is dblaira (or @dblaira).`

---

## Why this works

- **Context** tells the model your tools and skill level so it doesn’t assume terminal fluency or prior Cursor habits.
- **Your job** forces a repo-specific answer (structure, preview, deploy) instead of generic Git advice.
- **Style** keeps explanations beginner-friendly and stepwise.

No extra setup in this Understood repo is required—open `dblaira.github.io` in its own Cursor window and paste the boxed prompt there.
