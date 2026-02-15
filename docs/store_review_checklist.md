# App Store & Play Store Review Checklist

## Current implementation status
- **AI summary provider**: The app calls ElevenLabs (`https://api.elevenlabs.io/v1/convai/conversations/summarize`) and sends `audio_url` + `title` from the call details flow.
- **User consent for AI sharing**: Implemented in-app before any ElevenLabs request. Users must explicitly allow data sharing, and the choice is persisted.
- **iOS Info.plist permissions**: Includes microphone, Bluetooth, and calendar purpose strings.
- **Android Manifest permissions**: Includes microphone, Bluetooth connect, internet, and calendar permissions.

## What must be done before submission

### 1) Privacy policy updates (required)
Update your public privacy policy text to explicitly disclose:
- Data sent to ElevenLabs for AI summarization.
- Exact categories of data sent (call recording URL/audio metadata and call title).
- Purpose (conversation summarization).
- Retention/deletion practices.
- All third parties (Firebase, Agora, ElevenLabs, etc.) and links to their policies.

### 2) App Store Connect privacy questionnaire (required)
In App Store Connect > App Privacy:
- Mark all collected data categories accurately (account identifiers, audio, diagnostics, etc.).
- Mark whether data is linked to the user.
- Mark whether data is used for tracking (if no cross-app tracking, answer accordingly).

### 3) Google Play Data safety form (required)
In Play Console > App content > Data safety:
- Declare all collected/shared data (including AI-summary sharing with ElevenLabs).
- Declare encryption in transit.
- Declare deletion request support if applicable.

### 4) ATT / app tracking check (iOS)
- If the app does **not** track users across apps/websites, do not prompt ATT and ensure your App Store privacy answers reflect that.
- If you **do** track users, add ATT prompt copy (`NSUserTrackingUsageDescription`) and request permission before tracking.

### 5) Reviewer notes (recommended)
In App Review notes, add a short statement:
- "AI summaries are optional. Before sending any call data to ElevenLabs, users are shown a consent dialog explaining what data is sent and to whom."

## Suggested review test script
- Open a call details page with recording.
- Confirm AI consent dialog appears before summary generation.
- Tap "Don't allow" and verify no AI summary request is made.
- Tap "Allow" and verify summary appears.
