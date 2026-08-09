# Hearth

A private digital home for two people. Our life. Our money. Our plans.

This is **Phase 1: Foundation** — auth, households, membership, roles, and a
responsive shell. Money, Calendar, Goals, Our Life, Personal Space, and AI
are built in later phases on top of this.

## What's in Phase 1

- Next.js 14 (App Router) + TypeScript + Tailwind
- Supabase auth (email/password), with the architecture ready for Google + passkeys later
- Database: `profiles`, `households`, `household_roles`, `household_members`, `businesses`
- Row Level Security on every table — a user can only see their own household's data
- Onboarding flow: sign up → create household → land on dashboard
- Responsive shell: sidebar on desktop, bottom nav on mobile
- Warm, calm design system (see `tailwind.config.ts` — `hearth` color palette)

## Setup — step by step

### 1. Create the Supabase project
1. Go to supabase.com → New Project.
2. Once it's created, go to **Project Settings → API**. You'll need:
   - `Project URL`
   - `anon public` key
   - `service_role` key (keep this one secret — never put it in the frontend)

### 2. Run the database migration
1. In Supabase, go to **SQL Editor**.
2. Open `supabase/migrations/0001_foundation.sql` from this project.
3. Paste the whole file into the SQL Editor and run it.
4. You should see new tables under **Table Editor**: `profiles`, `households`, `household_roles`, `household_members`, `businesses`.

### 3. Create the GitHub repo
1. Create a new repo called `hearth-app` (or whatever you'd like).
2. Upload this whole folder using GitHub's **Add file → Upload files**, dragging
   the folder in so it keeps its structure. This app is plain TypeScript
   (no JSX comparison-operator issue like Setzio), so the web editor is fine too —
   but for a first upload, drag-and-drop is easiest.

### 4. Connect to Vercel
1. Go to vercel.com → New Project → import the `hearth-app` repo.
2. Before deploying, add these Environment Variables (from Step 1):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (mark as **Sensitive**)
   - `NEXT_PUBLIC_APP_URL` → your Vercel URL once you know it (e.g. `https://hearth-app.vercel.app`)
3. Deploy.

### 5. Supabase auth redirect
1. In Supabase → **Authentication → URL Configuration**, set the Site URL to
   your Vercel URL, and add it to Redirect URLs too.

### 6. Test it
1. Visit your deployed URL → you should land on **Sign in**.
2. Click **Create an account**, sign up, confirm via the email Supabase sends.
3. You'll land on **Set up your home** → create your household.
4. You'll arrive at the **Home dashboard** with your name and household name showing.

## What's deliberately NOT built yet

Money, Calendar, Goals, Our Life, Personal Space, Documents, AI, and the
partner-invite flow are all placeholders in the dashboard right now — real
functionality for each ships phase by phase, same pattern as Setzio.

## Deploy rules for this project

- Every file here is plain TypeScript/TSX with no dangerous `>` comparisons
  in JSX in a way that's broken the web editor before, but **when in doubt,
  use GitHub's Upload files, not the pencil editor** — same rule as Setzio.
- One phase at a time. Test each phase before moving to the next.
