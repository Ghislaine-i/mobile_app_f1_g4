# Project & Task Tracker App — Group F1 G4

A Flutter app for one small software team. It stores everything on the device with SQLite. No backend is needed.

## Download Android app

[Download the APK (v1.0.0)](https://github.com/Ghislaine-i/mobile_app_f1_g4/releases/latest) from the GitHub Releases page.

1. Download the APK on your Android phone (or transfer it from a computer).
2. Open the APK and install. Allow installs from unknown sources if Android asks.

To publish a new version after code changes:

```bash
flutter build apk --release
gh release create v1.0.1 build/app/outputs/flutter-apk/app-release.apk --title "Project & Task Tracker v1.0.1" --generate-notes
```

## Features

- Register with name, role, email and password. Sign in and sign out.
- Create, edit, delete and assign tasks. Set priority, deadline and status. Add notes.
- Deadline status badges (Completed, Overdue, At Risk, On Track) with a short reason.
- Dashboard counts, donut chart, statistics bar chart and upcoming deadlines.
- Team members with roles and open task counts. Edit your profile.

## Setup

```bash
flutter pub get
flutter run
```

Use an Android emulator or a physical phone (`flutter devices` lists them).

## How it works

### Architecture

```text
lib/
├── main.dart        # App entry point
├── theme.dart       # Shared styling (colors, text, buttons)
├── models/          # TeamMember, Account, Task, TaskNote
├── screens/         # Login, register, dashboard, tasks, team, statistics, profile
├── services/        # database, authentication, deadline status rules
└── widgets/         # Shared UI helpers and dialogs
```

### Local storage

- SQLite file `tracker.db` with three tables: `team_members`, `accounts`, `tasks`.
- Passwords are hashed with PBKDF2-HMAC-SHA256 (600,000 rounds, random 16-byte salt). Hashing runs in a separate isolate so the screen stays smooth.
- The logged-in user is kept in memory only. Each launch starts at the sign-in screen.
- Three fictional team members are added when the database is first created. No passwords are seeded.

### Deadline status rules

Applied in this order, with one shared function (`lib/services/deadline_status.dart`):

1. Workflow is Completed: **Completed**.
2. Deadline is now or in the past: **Overdue**.
3. Deadline is within the next 24 hours (inclusive): **At Risk**.
4. Otherwise: **On Track**.

The deadline is the start of the day after the chosen due date. So a task due today is At Risk for most of the day.

## Checks

```bash
dart format lib test
flutter analyze
flutter test
```

Tests cover the deadline status boundaries, registration, sign in, hashing and basic database actions. They use throw-away in-memory databases.

## Team & Task Division

| Member | Role | Contributions |
|---|---|---|
| Kabera Nshuti Samuel | Project setup & integration | Initialized the repo and Flutter project, built the app entry point (`main.dart`) and shared theme, reviewed and merged the team's PRs, repo maintenance and test suite |
| INEZA M. Ghislaine | Screens & services | Built the core screen layouts (login, register, dashboard, tasks, team, statistics, profile), the SQLite database service, authentication service, and deadline status tracking |
| Noella Uwera | Models & UI | Created the data models (`TeamMember`, `Account`, `Task`, `TaskNote`), shared UI helper widgets, and the team member management screens |
