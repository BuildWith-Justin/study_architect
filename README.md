# Study Architect

**Study Architect** is a local-first Flutter study planner and tracker designed to help students organize their academic workload, plan study sessions, track tasks, and monitor their study progress.

This repository contains **Version 1 (V1)** of the project.

> 🚧 Study Architect is an actively developing project. V1 focuses on establishing the core study-planning and tracking experience, with further improvements planned for future versions.

## ✨ Features

- 📅 **Study Timetable** — Create and manage planned study sessions.
- 📚 **Subject Management** — Add and organize academic subjects.
- ✅ **Task Management** — Create, edit, and track study-related tasks.
- ⏱️ **Focus Timer** — Track focused study sessions.
- 📊 **Progress Tracking** — View study activity and progress.
- 🎯 **Daily Study Goals** — Set and monitor daily study targets.
- 🔔 **Study Reminders** — Receive reminders for planned study activities and daily goals.
- 👤 **Student Profile** — Store basic student information such as name, school, programme, and level.
- 💾 **Local-First Storage** — Core data is stored locally on the device.
- 📤 **Backup & Sharing** — Export/share supported study data for backup purposes.

## 🛠️ Built With

- **Flutter**
- **Dart**
- **SQLite**
- **Flutter Local Notifications**
- **Material Design**

## 🏗️ Architecture

Study Architect V1 is built as a **local-first application**.

The application currently stores its core data locally rather than relying on a cloud backend. This keeps the V1 experience simple and allows the application to function without requiring a user account or constant internet connection.

Cloud functionality may be explored in future versions.

## 📱 Platform

V1 is primarily developed with Flutter and is intended to support multiple platforms as the project develops.

Some features, particularly device notifications, may depend on platform-specific support.

## 🚀 Getting Started

### Prerequisites

Make sure you have:

- Flutter SDK installed
- Dart SDK
- Android Studio or another supported Flutter development environment
- Git

### Installation

Clone the repository:

```bash
git clone https://github.com/BuildWith-Justin/study_architect.git
```

Move into the project directory:

```bash
cd study_architect
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

## 📂 Project Structure

The project follows a feature-oriented Flutter structure.

```text
lib/
├── app/
├── data/
├── repositories/
├── screens/
├── services/
├── theme/
├── utils/
└── widgets/
```

The exact structure may continue to evolve as the project develops.

## 🧪 Current Status

**Version:** `0.1.0+1`  
**Stage:** V1 — Initial MVP

V1 represents the first working foundation of Study Architect. The project is still being tested, refined, and improved.

Known issues and future improvements will be addressed as development continues.

## 🗺️ Future Development

Potential areas for future versions include:

- ☁️ Cloud synchronization
- 🔐 User accounts and authentication
- 📱 Improved cross-platform support
- 📈 More advanced study analytics
- 🔄 Smarter timetable restructuring
- 🎨 Further UI/UX improvements
- ⚡ Performance improvements
- 🔔 Expanded notification functionality

## 👨🏾‍💻 Developer

**Justin Bill Ocloo**

Computer Engineering student building Study Architect as part of his journey into software development.

The project is being developed as a practical way to explore Flutter, Dart, local data storage, application architecture, Git, GitHub, and software product development.

## 📄 License

This project does not currently specify an open-source license.
