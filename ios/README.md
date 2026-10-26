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
  program, save it to a client and optionally make it their active program,
  or save it as a reusable template.
- Admin extras: templates (preview, assign to any client), announcements
  (shown on every user's Today screen, dismissible), and an exercise library
  editor for any client or yourself.
- Units (kg or lb), bodyweight logging, silent re-login via the Keychain.

## Surba coaching features

- Plan with Surba: choose a goal (build muscle, strength, powerlifting, bodyweight,
  sculpt, general), days, session length, equipment and focus. Surba drafts the
  program, you preview it and start it as your active plan.
- Quick workout: pick where you are (full gym, home, hotel, no equipment), how long
  you have and what to hit. Surba builds one workout and you start it right away.
  These live in a "Quick Workouts" program that is never your active plan.
- Weekly review: Surba analyzes your week and proposes changes (sets, reps, rest,
  loads). Tick the ones you want and apply them to your plan in one tap.
- Classes: guided HIIT, cardio, core, yoga and mobility sessions with an interval
  timer, haptics, a 3-2-1 count-in and optional voice cues. Saved to Apple Health.
- Challenges: admins create time boxed challenges (workouts, sets or volume). You opt
  in by joining and appear on the leaderboard as first name and last initial only.

Server: apply the new migration (`20261028090000_add_challenges`). Everything else
uses the existing AI provider configuration.

## Workout control

- Pause and resume: pausing freezes the workout clock and the rest timer and covers
  the screen. The pause is saved on the server, so it survives closing the app and
  shows the same on every device. A reminder fires after 30 minutes paused.
- Minimize a workout and keep using the app: a "workout in progress" bar sits above
  the tab bar. Starting a different workout while one is open asks what to do.
  A forgotten empty workout older than 12 hours is cleaned up automatically.
- Edit any set: tap its number to change weight, reps, effort, warm-up, drop set
  and notes. Long press for duplicate and delete (delete has Undo).
- Offline safe logging: a set that cannot reach the server is kept on the phone,
  marked as waiting, and sent automatically. Finishing waits until nothing is pending.
- Change the workout on the fly: add, swap, remove and reorder exercises. When you
  finish you can save those changes to the workout in your program.
- Edit your programs: You > My programs. Rename, reorder, duplicate, activate or
  delete programs and workouts, edit sets, reps, effort, rest and notes per exercise.
- History: long press a workout (or use the menu) to edit it, change its notes or
  delete it. Editing reopens it as a paused workout, and the time spent finished
  is not counted as training time.

Server: apply the migration `20261029090000_add_session_pause`.

## Admin access

Set `ADMIN_EMAILS=you@example.com` in the server environment (comma separated),
restart, and apply the new migration (`npx prisma migrate deploy`, new migrations). That account
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
