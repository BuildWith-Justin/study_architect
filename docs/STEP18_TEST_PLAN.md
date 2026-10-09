# Study Architect V2: Step 18 Completion Test

How to use: tick each box as you go. For every failure, add a row to the Bug Log at the bottom.
Devices: A = Windows app, B = Android phone. Both signed in to the SAME account unless stated.
Keep the Supabase dashboard (Table Editor) open to verify rows.

---

## 0. Preparation

- [ ] Git checkpoint committed
- [ ] `tools/step18_check.ps1` run, result saved to `tools/step18_report.txt`
- [ ] Supabase migration scripts all executed (001 schema, step 4 sync tables, step 11 exams, step 13 xp_log/achievements, step 15 storage bucket)
- [ ] Both devices run the latest build (`flutter run` on each)

## 1. New account, onboarding (Device A)

- [ ] Sign up with a NEW email + password
- [ ] Onboarding flow completes: student setup, daily goal dial, add subjects
- [ ] Supabase: rows appear in `profiles`, `user_settings`, `subjects`, `topics`
- [ ] The "add a password" prompt appears on app entry (for Google-only accounts)
- [ ] Kill the app and reopen: you stay signed in and land on Home (not onboarding)

## 2. Cross-device sync (A creates, B receives)

Sign in on Device B with the same account.

- [ ] B shows the subjects and topics created on A
- [ ] On A create: a subject with topics, a recurring weekly session, a task, an exam
- [ ] On B, WITHOUT touching anything, do they appear (Realtime)? If not, pull to refresh. Note which screens needed the manual pull.
- [ ] On B edit the session title; A updates
- [ ] On B delete the task; it disappears on A
- [ ] On A complete a task; B shows it completed and XP matches
- [ ] Topic order (roadmap) is identical on both devices

## 3. Refresh audit (each screen, both devices)

For every screen: pull-to-refresh works AND the screen updates by itself when data changes elsewhere.

- [ ] Home (stats, next exam card, suggestion card, level/XP card)
- [ ] Timetable
- [ ] Tasks (known exception: reloads after each action, no mixin)
- [ ] Subjects list
- [ ] Subject details + roadmap
- [ ] Exam list / exam detail
- [ ] Progress
- [ ] Weekly report
- [ ] Calendar (heatmap dots)
- [ ] Achievements
- [ ] More
- [ ] Profile / Settings

## 4. Focus mode and sessions

- [ ] Start a focus session from the + button; the ring counts down
- [ ] Switch to another app for 1 minute and come back: the time is still correct (timestamp-based)
- [ ] Press X: confirmation appears; cancel keeps the timer, confirm exits
- [ ] Finish a session: mood, notes, confetti, XP, level-up / badge celebration
- [ ] Session appears on Home, Timetable, Progress, Calendar on BOTH devices
- [ ] A session shorter than 10 min does not count for the streak
- [ ] Delete that session: its XP is removed, unlocked badges are kept

## 5. Sign-out / sign-in

- [ ] Sign out on A: you return to the auth screen, no crash
- [ ] Sign in again with the same account: all data comes back (from Supabase)
- [ ] Sign in with a DIFFERENT account on A: you must NOT see the first account's data
- [ ] Sign back in with the first account: data is intact
- [ ] Profile photo: correct for each account (known limit: cached photo after sign-out, check this)
- [ ] Google sign-in and email+password both work for the same user

## 6. Offline, then reconnect

Device A: switch on airplane mode.

- [ ] App opens and works offline (Home, Timetable, Tasks load from local data)
- [ ] Offline: create a task, edit a subject, finish a focus session
- [ ] No crash and no endless spinner while offline
- [ ] Turn airplane mode off: changes reach Supabase within a short time (check the Table Editor)
- [ ] Device B receives those changes
- [ ] Conflict test: A offline edits the session title to "A-version"; B (online) edits the same session to "B-version"; A reconnects. Last write wins; confirm nothing crashes and both devices end identical.
- [ ] Offline delete on A of an item that B edited: reconnect and check the outcome is sensible

## 7. Gamification consistency

- [ ] XP total and level are the same on A and B
- [ ] Streak value is the same on Home, Progress and Weekly report
- [ ] The "Recalculate XP" button gives the same total as the live value
- [ ] Daily XP cap respected
- [ ] Achievements screen: unlocked badges match on both devices

## 8. Notifications, backup, appearance

- [ ] Study reminder notification fires at the chosen time (Android)
- [ ] Notification permission denied: app does not crash and explains what to do
- [ ] Export backup creates a file; Import backup restores into a fresh state
- [ ] Import an OLD backup (without XP log): app does not crash (known limit: XP/badges may reset until recalculation)
- [ ] Light and dark mode: every screen readable, no overflow
- [ ] Appearance setting persists after restart

## 9. Profile photo

- [ ] Pick a photo: shown on Home, Settings, Profile
- [ ] Photo appears on the other device after refresh
- [ ] Photo larger than 2 MB: clear error message, no crash
- [ ] Replace the photo: new one shows everywhere

## 10. Edge cases

- [ ] Empty states: new account with no sessions/tasks/exams shows friendly messages, not errors
- [ ] Delete a subject that has topics, sessions, tasks: warning appears (known limit: exams not counted in the warning)
- [ ] Rotate the phone / resize the Windows window: no overflow errors
- [ ] Very long subject name / task title: text wraps or truncates cleanly
- [ ] Rapid double tap on Save buttons: no duplicate rows
- [ ] Kill the app during a sync, reopen: no corrupted or duplicated data

## 11. Known limits: decide for each (Fix now / Fix later / Accept)

| # | Limit | Decision |
|---|---|---|
| 1 | Exam reminder notifications missing | |
| 2 | Subject-delete warning does not count exams | |
| 3 | Sync failure on one table blocks the whole push (needs try/catch per table) | |
| 4 | XP is computed on-device, so it is not tamper-proof | |
| 5 | Celebration only shows right after a session (nothing if app closed first) | |
| 6 | XP not changed when a task's date is edited | |
| 7 | XP not removed if a deletion happens on another device before sync | |
| 8 | Home reloads all sessions on each refresh (watch with lots of data) | |
| 9 | Profile photo: no onboarding step, no offline upload queue, no crop, not included in backup | |
| 10 | Cached photos remain after sign-out | |
| 11 | XP/level values chosen arbitrarily, tune after testing | |

---

## Bug Log

| ID | Screen | What I did | What happened | What I expected | Device | Fixed? |
|----|--------|-----------|---------------|-----------------|--------|--------|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |

---

## Final sign-off

- [ ] All sections 1 to 10 passed or bugs fixed and retested
- [ ] Section 11 decisions made
- [ ] `flutter analyze` shows no errors
- [ ] `flutter test` passes
- [ ] Final Git commit and push on `v2-development`
- [ ] Merge plan for `v2-development` into `main` decided
