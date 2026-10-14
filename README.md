# Study Architect

**Study Architect** is a Flutter study planner and tracker that helps students organize their academic workload, plan study sessions, stay focused, and monitor their progress, with cloud sync so their data follows them across devices.

This repository contains **Version 2 (V2)** of the project. 

## ✨ Features

- 🔐 **Accounts & Sign-In** — Sign up with email and password or continue with Google.
- 👤 **Onboarding & Student Profile** — Set up your name, school, programme, level, subjects, and daily study goal.
- 📅 **Timetable** — Plan study sessions, including weekly recurring sessions.
- ✅ **Tasks** — Create, edit, and complete study-related tasks.
- 📚 **Subjects & Topics** — Organize subjects with ordered topics and follow a study roadmap.
- ⏱️ **Focus Mode** — Distraction-free countdown ring, with a session-complete screen for mood and notes.
- 📊 **Progress & Analytics** — Charts of your study time, plus a weekly report.
- 🎯 **Daily Study Goals** — Set and track daily targets.
- 📝 **Exam Mode** — Add exams with dates, topic checklists, countdowns, and preparation tracking.
- 🗓️ **Calendar View** — Monthly calendar with a study-hours heatmap.
- 🏆 **Gamification** — XP, levels, study streaks, and achievement badges.
- 💡 **Smart Insights** — Personalized suggestions based on your study habits, plus natural-language quick add. These run on the device with no paid API.
- 🖼️ **Profile Photos** — Upload a profile picture.
- 🔔 **Notifications** — Reminders for planned sessions and daily goals.
- 🌗 **Light & Dark Mode**
- 💾 **Backup & Export** — Export your study data as a backup.

## 🛠️ Built With

- **Flutter** and **Dart**
- **Supabase** (Postgres, Auth, Storage)
- **SQLite** (`sqflite`) for local storage
- **fl_chart** for charts
- **table_calendar** for the calendar view
- **Flutter Local Notifications**
- **GitHub Actions** (scheduled keep-alive ping for the Supabase project)

## 🏗️ Architecture

Study Architect V2 is **offline-first with cloud sync**:

- Data is stored locally in SQLite so the app stays usable without a connection.
- A sync layer pushes and pulls changes to a Supabase Postgres database, secured with Row Level Security so each user only sees their own data.
- Authentication is handled by Supabase Auth (email/password and Google).
- A central refresh bus keeps screens up to date when data changes, and screens also support pull-to-refresh.

## 📱 Platform

V2 is developed and tested primarily on **Android**. It is built with Flutter, so other platforms may work, but they have not been fully tested.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK and Dart SDK
- Android Studio or another supported Flutter environment
- Git
- A free [Supabase](https://supabase.com) project

### Installation

Clone the repository:

```
git clone https://github.com/BuildWith-Justin/study_architect.git
cd study_architect
```

Install dependencies:

```
flutter pub get
```

Create your environment file by copying the example, then fill in your own Supabase values (see `.env.example` for the required keys):

```
copy .env.example .env
```

Set up the database by running the SQL files in `supabase/migrations` in your Supabase project's SQL editor, in order.

Run the app:

```
flutter run
```

## 📂 Project Structure

```
lib/
├── app/
├── core/
├── data/
├── repositories/
├── screens/
├── services/
├── theme/
├── utils/
└── widgets/
supabase/
└── migrations/
test/
```

## 🧪 Current Status

**Stage:** V2 complete. All planned V2 features are built and tested.

Known improvements for future versions:

- Reminder notifications for exams
- Additional sign-in methods
- Further performance and UI polish

## 👨🏾‍💻 Developer

**Justin Bill Ocloo**

Computer Engineering student building Study Architect as part of his journey into software development, exploring Flutter, Dart, Supabase, application architecture, Git, and product design.

## 📄 License

This project does not currently specify an open-source license.