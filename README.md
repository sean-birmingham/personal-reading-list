# Bookshelf — [Your Name]

A personal reading tracker where you search for books, organize them into shelves, track reading progress, and explore year-in-review statistics.

**Live URL:** _Not deployed yet._

<!-- ![Screenshot of your solution](./screenshot.png) -->

---

## Overview

Bookshelf is a full-stack reading tracker built with Next.js and Supabase as a [Frontend Mentor](https://www.frontendmentor.io) Product Challenge. It's built in phases: the foundation (app scaffold, brand design tokens, fonts) and the data model (database schema with Row Level Security) are done, and the user-facing features come next.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router, Cache Components) |
| Database | Supabase (Postgres), schema managed with Supabase CLI migrations |
| Authentication | Supabase Auth (email + password) |
| Book API | Open Library |
| Hosting | Vercel |
| Styling | Tailwind CSS v4 with the brand design tokens |
| Charts/Viz | TBD |
| Other | Lora + Inter via `next/font` |

---

## Data Model

<!-- TODO: Rewrite this section in your own words. Any sentence you can't rephrase is a part of the schema worth asking about. -->

The full schema is in [`supabase/migrations/20261015001353_init_schema.sql`](supabase/migrations/20261015001353_init_schema.sql).

**1. Each user has their own copy of a book's metadata.** Instead of a shared `books` catalog, `library_books` stores a book's details alongside the user's shelf, rating and notes. Bookshelf has no social features, so a shared catalog would add complexity without benefit, and users can fix missing data (like a page count) on their own copy. *Trade-off:* metadata is duplicated across users, and later Open Library corrections don't reach existing copies.

**2. A book's identity is its Open Library work ID.** Open Library groups every edition of a book under one work (*Dune* has 155 editions and 240 ISBNs). Making the work ID unique per user means you can't add *Dune* twice by picking a different edition. Edition details like ISBN, cover and page count are ordinary columns. *Trade-off:* books Open Library doesn't have get no work ID, so they aren't checked for duplicates.

**3. Shelves say where a book is; dates say what happened.** The spec puts each book on exactly one shelf, but moving a finished book to "Favorites" shouldn't remove it from your reading goal. So "read this year" is based on `finished_on`, not the Read shelf. Moving a book onto Currently Reading or Read fills in the start or finish date. Adding old books straight to Read doesn't, so a new user's backlog doesn't inflate this year's goal. Dates are plain `date`s rather than timestamps, so a book finished late on New Year's Eve can't land in the wrong year. *Trade-off:* one finish date per book means re-reads aren't tracked.

**4. Progress is stored as both a current position and a history.** The book row holds the current page for fast library loads, and `progress_updates` is an append-only log of positions that powers stats like pages per week. A database trigger keeps the two in sync.

**5. Deleting a shelf never deletes books.** A `delete_shelf` function moves each book to the default shelf that matches its dates (finished → Read, started → Currently Reading, otherwise Want to Read), then removes the shelf. The database itself refuses to delete a shelf that still has books, so an app bug can't lose data.

**Security.** Every table uses Row Level Security, so users can only see and change their own rows. Composite foreign keys also guarantee a book can only sit on its owner's shelves. Rules that protect data live in the database, not just the UI.

---

## Design Decisions

These are the product and design choices I made where the spec left room for interpretation.

### Year-in-Review & Reading Insights

<!-- How did you design the year-in-review experience? What data do you show? How is it visualized? Does it feel like a special moment or just another page? -->

_Not designed yet._

<!--
**The problem I was solving:**

**My approach:**

**Why I chose this approach:**

**What I'd do differently:**
-->

### Book Discovery & Recommendations

<!-- How did you design the book discovery experience? What does onboarding look like for a new user? How do they find books beyond direct search? -->

_Not designed yet._

<!--
**The problem I was solving:**

**My approach:**

**Why I chose this approach:**

**What I'd do differently:**
-->

### Reading Progress Tracking UX

<!-- How do users update their reading progress? What's the input method? Where can they do it? How does it feel? -->

_Not designed yet. The data model already stores a history of reading positions, so it supports any input method (page number, quick increments, sessions)._

<!--
**The problem I was solving:**

**My approach:**

**Why I chose this approach:**

**What I'd do differently:**
-->

### Other Design Choices

<!-- Document any other significant design decisions: shelf layout, book cover presentation, navigation structure, landing page approach, etc. -->

_Coming as the UI is built._

---

## Development Journey

### Initial Approach vs. Final

I started by having AI scaffold the whole project, then switched to having it walk me through each step instead: explaining the options and trade-offs, with me making the decisions.

<!-- TODO: In your own words — why did you switch? -->

### Decisions Reconsidered

- **Timestamps → dates for reading history.** I first planned `started_at` / `finished_at` timestamps, then switched to plain `date` columns. A timestamp of 11pm on December 31 in New York is already January 1 in UTC, which would count the book toward the wrong year's goal.

### What Surprised Me

<!-- TODO: In your own words. Candidates from the first sessions:
- create-next-app refuses to scaffold into a folder that already has files
- the dev server kept serving stale CSS until it was restarted
- create-next-app now offers Cache Components, Next.js's new caching model
- most of the "Supabase" work was really Postgres: tables, Row Level Security, triggers
-->

### Session Breakdown

| Session | Focus | What I Accomplished |
|---------|-------|-------------------|
| 1 | Foundation | Scaffolded Next.js 16, wired up brand tokens and fonts, set up Supabase and its CLI |
| 2 | Data model | Made five schema decisions, wrote and tested the migration, applied it to Supabase |

---

## AI Collaboration Reflection

### How I Used AI

I used Claude Code as a guide rather than a code generator. It explained each step and its trade-offs, and I made the product and technical decisions. For unfamiliar territory (the SQL migration), I had it write code that it tested against a scratch Postgres database, then reviewed it.

### What Worked Well

<!-- TODO: Which prompting strategies or collaboration patterns produced the best results? -->

### What I Learned

<!-- TODO: How did your approach to AI collaboration evolve? Prompts:
- The challenge's AGENTS.md assumed the AI would write all the code. What did you change or want to change?
- For the SQL you asked for complete code instead of hints. What did that teach you about when to learn something vs. delegate it?
-->

### Where I Pushed Back

<!-- TODO: Were there moments where AI suggestions weren't right, or where you chose differently? How did you decide? -->

---

## Differentiators

### Chosen Differentiator(s)

_Not chosen yet. Shortlist: reading statistics dashboard, social sharing cards, animated shelf interactions, AI reading companion._

<!--
**1. [Differentiator Name]**

**Why I chose this:**

**How it enhances the product:**

**Implementation highlights:**

**What I learned:**
-->

---

## Self-Assessment

<!-- Fill in at the end of the project. Rate your implementation honestly. This self-awareness is part of the portfolio artifact.

| Category | Rating | Notes |
|----------|--------|-------|
| **Works for real users** — Deployed, functional end-to-end | /5 | |
| **Book API integration** — Handles missing covers, varied ISBNs, inconsistent metadata | /5 | |
| **Design-it-yourself features** — Quality and thoughtfulness of year-in-review, discovery, and progress tracking solutions | /5 | |
| **Design quality** — Typography pairing, warm aesthetic, spacing, visual hierarchy, polish | /5 | |
| **Responsive design** — Fully functional and well-designed across devices | /5 | |
| **Performance** — Fast load, smooth scrolling, efficient cover image loading | /5 | |
| **Accessibility** — Keyboard nav, screen reader support, contrast | /5 | |
| **Edge case handling** — Empty states, errors, loading, missing data, large libraries | /5 | |
| **Code quality** — Clean, maintainable, well-structured | /5 | |
| **Landing page** — Compelling, communicates value, visually polished | /5 | |
| **Guest experience** — Immediately impressive, real books, full features | /5 | |

### Lighthouse Scores

Run Lighthouse on your deployed site and record the scores.

| Category | Score |
|----------|-------|
| Performance | |
| Accessibility | |
| Best Practices | |
| SEO | |

### Strengths

What are you most proud of in this project?

### Areas for Improvement

What would you improve with more time? Be specific.
-->

_Coming at the end of the project._

---

## Known Limitations

- **Re-reads aren't tracked.** Each book has one start and one finish date, so reading a book again overwrites them.
- **Books outside Open Library aren't de-duplicated.** They have no work ID, so the same book could be added twice.
- **Automatic dates use UTC.** When a book is moved onto Currently Reading or Read without a date, the database fills in today's date in UTC. The app will send the user's local date instead.

---

## Running Locally

```bash
# Clone the repo
git clone https://github.com/sean-birmingham/personal-reading-list.git
cd personal-reading-list

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local
# Fill in your Supabase URL and publishable key

# Apply the database schema to your own Supabase project
npx supabase login
npx supabase link --project-ref your-project-ref
npx supabase db push

# Run the development server
npm run dev
```

### Environment Variables

| Variable | Description |
|----------|------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL (Dashboard → Connect) |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Your Supabase publishable key. Safe in the browser, because Row Level Security protects the data |

---

## Acknowledgments

Built as a [Frontend Mentor Product Challenge](https://www.frontendmentor.io). Book data from [Open Library](https://openlibrary.org).
