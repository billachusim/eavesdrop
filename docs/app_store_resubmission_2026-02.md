# App Store Resubmission Plan (Review date: 2026-02-23)

## 1) iPad screenshot replacement requirements

Use native iPad captures only (no stretched iPhone UI).

### Accepted iPad 13-inch screenshot sizes
- Portrait: **2064 x 2752** (preferred)
- Portrait alternate: **2048 x 2732**
- Landscape: **2752 x 2064**
- Landscape alternate: **2732 x 2048**

### Capture workflow
1. Open iOS Simulator and boot a 13-inch iPad class simulator.
2. Log in with seeded demo data and navigate to core experiences (home feed, live room, booking, profile).
3. Capture screenshots from simulator (File > Save Screen Shot).
4. Validate exact pixel dimensions before upload.
5. Upload in App Store Connect > Previews and Screenshots > **View All Sizes in Media Manager**.

### Recommended screenshot set (5 frames)
1. Live home feed with active rooms.
2. Call details with social proof + host metadata.
3. Booking flow screen.
4. Live listening room with reactions/questions.
5. Profile/settings with follow + saved calls affordances.

## 2) Required subscription metadata

Because this app offers auto-renewable subscriptions, App Store metadata must include a functional Terms link.

Use Apple standard EULA link in App Description:
- https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Also keep Privacy Policy in App Store Connect Privacy Policy field and in-app paywall/footer links.

## 3) IAP sandbox verification checklist (iPad)

Before resubmission, run on iPad simulator/device with Sandbox account:

- Product list loads for: `credits_1200`, `credits_3500`, `credits_7500`, `premium_monthly`.
- Tapping each paywall CTA triggers a visible loading state immediately.
- Failed transactions surface an explicit error to the user (not silent no-op).
- Successful transactions credit the user and show success feedback.
- Verify restore/subscription flows and confirm transactions complete.

## 4) UGC safeguards required by Guideline 1.2

Implemented/required controls:
- Terms acceptance at signup with no-tolerance policy language.
- In-feed hide/report/block action for objectionable users/content.
- Blocked users removed from the reporting user feed immediately.
- Report records persisted in `ugcReports` for moderation workflow.
- Moderator SLA: act on reports within **24 hours** (remove content + eject abusive account).

## 5) Resolution Center reply template

- Replaced all iPad 13-inch screenshots with native iPad captures at 2064x2752 (and matching landscape where used), with no stretched iPhone imagery.
- Added Terms of Use (EULA) metadata link in App Store Connect description and confirmed in-app Terms/Privacy links are functional.
- Fixed paywall purchase handling so each product tap immediately starts StoreKit purchase flow with loading/error feedback; re-tested in iPad sandbox.
- Implemented and documented UGC protections: mandatory terms acceptance, objectionable-content reporting, abusive-user blocking with immediate feed removal, and 24-hour moderation action policy.
