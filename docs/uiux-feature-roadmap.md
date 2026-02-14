# Eavesdrop App Audit: UI/UX + Feature Roadmap

## What the app currently is

Eavesdrop is a Flutter + Firebase social audio app where users can:
- Browse **Live**, **Upcoming**, and **Featured Past Calls**.
- Join live calls as listeners (and hosts/admins as broadcasters).
- Book one-on-one calls with hosts using credits.
- Ask paid questions during a live call.
- Buy credits and premium via in-app purchase.

## Current strengths

- Distinct dark visual identity and strong card presentation for calls.
- Core user loop exists: discover -> join/listen -> paywall -> top-up.
- Good baseline real-time architecture (Firestore streams + Cloud Functions scheduler).
- Audio pipeline includes recording and replay (past call details).

## Highest-impact UX improvements (next 2-4 weeks)

1. **Improve onboarding and authentication flow**
   - Replace close-only onboarding with explicit guest path and clear value proposition.
   - Add social auth options and password reset surface.
   - Show what users can/can't do as guest before a paywall appears.

2. **Clarify pricing and paywall moments**
   - Explain costs before users enter friction points:
     - booking cost,
     - listen-unlock cost,
     - question cost.
   - Add lightweight “credits needed” badges beside action buttons.

3. **Reduce cognitive overload on home + booking**
   - Make Home top menu persistent (instead of hidden settings toggle).
   - Add filtering chips (Live / Soon / This Week / Past).
   - In booking, show host availability + timezone labels + total credits cost summary.

4. **Fix reliability/feedback issues in live call UX**
   - Show explicit “connected / reconnecting / failed” states.
   - Surface mic/bluetooth permission outcomes with recovery actions.
   - Improve listener join/leave handling and listener count trustworthiness.

5. **Create a tighter empty-state system**
   - Current empty states are text-only.
   - Add branded illustration + clear CTA (“Set reminder”, “Book first call”, “Browse featured”).

## Medium-term product features (4-8 weeks)

1. **Host profiles + trust signals**
   - Dedicated host profile page with bio, tags, specialties, language, ratings, number of calls.
   - Richer call cards with tags (e.g., Relationships, Career, Anxiety).

2. **Social discovery**
   - Follow hosts and topics.
   - Personalized feed (“Because you listened to…”).
   - Search by topic, mood, host, and date.

3. **Engagement loops**
   - Save/favorite past calls.
   - Share deep-links to specific calls.
   - Notification center for reminders, host replies, and recommended sessions.

4. **Audience interaction upgrades**
   - Real reaction system (existing placeholder button can become event stream).
   - Upvote queue for questions.
   - Host moderation tools (pin question, dismiss, ban user from room).

## Monetization improvements

- Add **credit packs anchored to use cases** (“2 calls”, “4 calls”, “unlock + ask 3 questions”).
- Add **free trial funnel** (first 10 minutes free with countdown, then unlock).
- Add **post-call upsell** from recording screen (“Unlock similar calls”, “Book follow-up”).
- Add **subscription perks transparency** in one place (unlimited listening? booking discount? question credits?).

## Key technical/UX debt to address

1. **Secrets management + security hardening**
   - Remove hardcoded Agora credentials from Cloud Functions source.
   - Move to environment config and rotate keys.

2. **Data consistency risks**
   - Listener join logic appears guarded by a flag that is never set before check.
   - Listener leave cleanup is commented out.
   - This can desync listener counts and UI trust.

3. **Code quality + maintainability**
   - Some screens are oversized and combine view/business logic.
   - Extract use-cases and view models for testability and velocity.

4. **Analytics instrumentation**
   - Define event taxonomy: home_view, call_joined, paywall_shown, unlock_success, booking_started, booking_completed, question_sent.
   - Add funnel dashboards before expanding feature scope.

## Suggested execution plan

### Phase 1 (Weeks 1-2): UX + conversion quick wins
- Home navigation cleanup.
- Pricing transparency labels.
- Better empty states and loading states.
- Live call connection status components.

### Phase 2 (Weeks 3-4): Reliability + trust
- Listener tracking bug fixes.
- Error handling polish across booking/live call.
- Security hardening for backend secrets.

### Phase 3 (Weeks 5-8): Discovery + retention
- Host profile + search/filter.
- Follow/favorite and recommendation primitives.
- Notification center.

## What to build first

If only one thing is prioritized, build:

**"Conversion + trust pack"**
1) Paywall/credit transparency
2) Reliable listener/connection states
3) Better onboarding and guest affordances

This should improve both first-session completion and paid action conversion while reducing confusion.
