# Surba Fit for iOS

A native SwiftUI client for your Surba Fit server (this repo's backend). The AI coach is called Surba. It uses the same
JSON API as the website (cookie session), so no server changes are needed:
your programs, history, bodyweight and AI coach are all shared with the web app.

## What is in it

- Today: weekly goal ring, week streak, 7 day volume, the next workout in your program.
- Live workout logging: previous-performance prefill, haptics, rest timer ring
  with a notification when rest ends, PR detection with confetti, plate
  calculator, cardio sets, add or undo sets.
- History: 12 week consistency heatmap and per-workout breakdowns.
- Progress: Swift Charts for weekly volume, estimated 1RM per lift, and
  bodyweight with your goal line.
- Surba: streaming AI chat, with the conversation kept between launches.
- Admin tab (admins only): dashboard, client list and detail, role changes,
  and "Create a workout with Surba": describe a goal, review the generated
  program, save it to a client and optionally make it their active program.
- Units (kg or lb), bodyweight logging, silent re-login via the Keychain.

## Admin access

Set `ADMIN_EMAILS=you@example.com` in the server environment (comma separated),
restart, and apply the new migration (`npx prisma migrate deploy`). That account
gets the Admin tab. Admins can promote other accounts from a client's page.
Every `/api/admin` route is checked on the server; hiding the tab is only cosmetic.

## Run it on your iPhone

Requires a Mac with Xcode 15 or later (iOS 17+ device or simulator).

```bash
brew install xcodegen
cd ios
xcodegen            # generates GymCoach.xcodeproj from project.yml
open GymCoach.xcodeproj
```

1. In Xcode, select the GymCoach target, Signing & Capabilities, and pick your
   Team . Change the bundle identifier if `com.surbafit.app` is taken on your account.
2. Plug in your iPhone, select it as the run destination, press Run. The first
   time, trust your developer profile in Settings, General, VPN & Device Management.
3. Start the server (`docker compose up`, see the main README) and enter its
   address on the login screen, e.g. `http://192.168.1.20:3000`. Your phone must
   reach that address (same Wi-Fi, or Tailscale for use away from home).

### Server notes

- Over plain HTTP, set `SESSION_COOKIE_SECURE=false` in the server environment,
  otherwise the session cookie is marked Secure and never sent. Prefer HTTPS
  (a reverse proxy or `tailscale serve`) when the server is reachable beyond your LAN.
- The app allows plain HTTP connections (App Transport Security is relaxed in
  `project.yml`) because self-hosted servers rarely have certificates on a LAN.
  Remove `NSAllowsArbitraryLoads` there if you only use HTTPS.

## Layout

```
GymCoach/Core    API client, models, app state, rest timer, Keychain, theme
GymCoach/Views   Home, workout session, history, progress, coach, settings
```

## Next ideas

HealthKit bodyweight sync, a Live Activity for the rest timer, home screen
widgets, an offline queue for sets logged without signal, and program editing.
