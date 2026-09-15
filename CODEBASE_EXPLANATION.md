# 📖 Your Log — Flutter Codebase Architecture & Deep Dive Guide

Welcome to the comprehensive technical documentation for **Your Log**, a modern, high-performance Flutter workout tracking application engineered with offline-first Cloud Firestore synchronization, Gemini 3.6 Flash AI analytics, tactile session logging, and superset support.

---

## 📑 Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Folder & Directory Structure](#2-folder--directory-structure)
3. [Core Entrypoint & Initialization](#3-core-entrypoint--initialization)
4. [Data Models (`lib/models/`)](#4-data-models-libmodels)
5. [Service Layer (`lib/services/`)](#5-service-layer-libservices)
6. [Screens & User Interface (`lib/screens/`)](#6-screens--user-interface-libscreens)
7. [Custom Reusable Widgets (`lib/widgets/`)](#7-custom-reusable-widgets-libwidgets)
8. [Design System & Theming (`lib/theme/`)](#8-design-system--theming-libtheme)
9. [State Management & Data Flow](#9-state-management--data-flow)
10. [Testing Suite (`test/`)](#10-testing-suite-test)

---

## 1. Architecture Overview

**Your Log** follows a clean, reactive architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                       UI Presentation                       │
│    (Screens, Tabs, Modals, Widgets, AppTheme, Google Fonts)  │
└──────────────────────────────┬──────────────────────────────┘
                               │ User Interactions & State
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                        Service Layer                        │
│   • StorageService (Local Cache + Firestore Stream Sync)    │
│   • AiCoachService (Google Gemini 3.6 Flash API Engine)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Serialization / Deserialization
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                         Data Models                         │
│  Exercise, WorkoutSchedule, WorkoutLog, ExerciseSetLog,    │
│  ExerciseCompletionLog, UserProfile                         │
└──────────────────────────────┬──────────────────────────────┘
                               │ Persistence
                               ▼
┌──────────────────────────────┴──────────────────────────────┐
│  • SharedPreferences (Local device cache, instant startup)  │
│  • Cloud Firestore (Real-time multi-device cloud database)  │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Principles
- **Offline-First & Zero Latency**: All reads occur instantly from an in-memory / `SharedPreferences` cache. Data is written optimistically to the local store and synced to Cloud Firestore in the background.
- **Reactive Stream Synchronization**: Real-time Firestore snapshot streams listen for remote updates and notify the UI through a singleton `ChangeNotifier`, automatically rebuilding screens when routines or logs change on other devices.
- **Null Safety & Robust Parsing**: Comprehensive null-safety checks and fallback defaults ensure legacy routines without newer features (e.g. Supersets or Timed holds) load smoothly without runtime errors.
- **Secret Hygiene**: Sensitive credentials (such as user-provided Gemini API keys) are stored strictly on-device in local storage and never hardcoded in git repositories.

---

## 2. Folder & Directory Structure

```
lib/
├── firebase_options.dart          # Auto-generated Firebase web/mobile config
├── main.dart                      # App entry point, theme binding, root provider
├── models/                        # Domain entities & JSON serialization
│   ├── exercise.dart              # Single & Superset exercise configuration
│   ├── user_profile.dart          # Bodyweight, training focus, API key, AI review cache
│   ├── workout_log.dart           # Session history, set logs, volume math
│   └── workout_schedule.dart      # Routine schedules, weekday assignments, color coding
├── screens/                       # Main app screens and tab views
│   ├── ai_coach_screen.dart       # Gemini AI Analysis & interactive coach chat
│   ├── analytics_tab.dart         # Volume charts, weekly momentum, streak counter
│   ├── history_tab.dart           # Completed session timeline and filters
│   ├── log_session_screen.dart    # Tactical workout logger with stopwatch timer
│   ├── main_navigation_screen.dart# Root bottom navigation controller & stream listener
│   ├── schedule_editor_screen.dart# Routine builder with Normal vs Superset pair form
│   └── schedules_tab.dart         # Dashboard listing all routines
├── services/                      # Application backend & infrastructure services
│   ├── ai_coach_service.dart      # Gemini 3.6 Flash prompt builder & HTTP client
│   └── storage_service.dart       # SharedPreferences + Cloud Firestore reactive store
├── theme/
│   └── app_theme.dart             # Dark mode theme, colors, typography, input styles
└── widgets/                       # Reusable UI component cards
    ├── history_card.dart          # Expandable workout log card with set chips
    └── schedule_card.dart         # Routine card with superset badges and day pills
```

---

## 3. Core Entrypoint & Initialization

### [main.dart](file:///Users/admin/Documents/PV/lib/main.dart)
The root entrypoint executes three essential bootstrap tasks before launching `runApp`:
1. `WidgetsFlutterBinding.ensureInitialized()`: Binds the Flutter framework engine.
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`: Connects to Cloud Firestore across Web, Android, and iOS.
3. `StorageService().init()`: Initializes `SharedPreferences`, loads local caches, seeds default routines if empty, and connects Firestore background stream listeners.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await StorageService().init();
  runApp(const WorkoutTrackerApp());
}
```

---

## 4. Data Models (`lib/models/`)

### 1. [exercise.dart](file:///Users/admin/Documents/PV/lib/models/exercise.dart)
Represents an individual exercise template inside a workout routine.
- **Normal Exercise**: Defines target muscle, default sets, default reps, and default weight (kg).
- **Timed Exercise**: When `isTimeBased: true`, the exercise operates as a timed hold (e.g. Plank) using `defaultTimeSeconds` instead of reps.
- **Superset Exercise**: When `isSuperset: true`, the exercise pairs two back-to-back movements in 1 set:
  - **Movement 1**: Defined by `name`, `targetMuscle`, `isTimeBased`, `defaultReps`, `defaultTimeSeconds`, `defaultWeightKg`.
  - **Movement 2**: Defined by `supersetName`, `supersetTargetMuscle`, `supersetIsTimeBased`, `supersetReps`, `supersetTimeSeconds`, `supersetWeightKg`.
  - **Shared Sets**: `defaultSets` defines the number of rounds for the pair.

### 2. [workout_schedule.dart](file:///Users/admin/Documents/PV/lib/models/workout_schedule.dart)
Defines a reusable workout routine (e.g., *Push Day*, *Pull Day*, *Legs & Core*).
- `id`: Unique UUIDv4 identifier.
- `title` & `description`: Routine name and subtitle notes.
- `colorHex`: Accent color hex (e.g. `#10B981` Emerald, `#06B6D4` Cyan, `#F59E0B` Amber).
- `scheduledDays`: List of target weekdays (e.g., `['Monday', 'Thursday']`).
- `exercises`: Ordered list of `Exercise` items.

### 3. [workout_log.dart](file:///Users/admin/Documents/PV/lib/models/workout_log.dart)
Contains classes representing completed workout history:
- **`ExerciseSetLog`**: Individual set metrics including `reps`, `timeSeconds`, `weightKg`, `completed` (boolean), and paired superset metrics (`supersetReps`, `supersetTimeSeconds`, `supersetWeightKg`).
- **`ExerciseCompletionLog`**: Aggregates all sets for an exercise during a session.
  - Automatically computes `totalReps`, `totalTimeSeconds`, and `totalVolume` (summing both paired movements when `isSuperset: true`).
  - `formatSetText()`: Formats set text for display (e.g. `10 reps @ 80kg + 12 reps @ 15kg`).
- **`WorkoutLog`**: Complete recorded session containing `scheduleId`, `scheduleTitle`, `completedDate`, `durationMinutes`, `overallNotes`, and list of `ExerciseCompletionLog` items.

### 4. [user_profile.dart](file:///Users/admin/Documents/PV/lib/models/user_profile.dart)
Stores athlete profile metadata:
- `bodyWeightKg` & `age`: Physical stats used for AI volume and recovery calibration.
- `trainingGoal`: Primary focus (e.g. *Hypertrophy & Muscle Building*, *Strength*, *Fat Loss*).
- `experienceLevel`: Training tenure (*Beginner*, *Intermediate*, *Advanced*).
- `geminiApiKey`: User-provided Gemini API key stored locally.
- `lastAiAnalysis` & `lastAiAnalysisDate`: Cached output of the most recent Gemini performance review.

---

## 5. Service Layer (`lib/services/`)

### 1. [storage_service.dart](file:///Users/admin/Documents/PV/lib/services/storage_service.dart)
A singleton class extending Flutter's `ChangeNotifier` responsible for local persistence and real-time cloud synchronization.
- **Dual-Mode Persistence**:
  - Writes to `SharedPreferences` for instantaneous offline reads and writes.
  - Writes to Cloud Firestore (`schedules` and `logs` collections) in the background.
- **Real-Time Stream Sync**:
  - Sets up `FirebaseFirestore.instance.collection('...').snapshots().listen(...)`.
  - When another device logs a workout or edits a schedule, the local cache updates and calls `notifyListeners()`.
- **Default Seed Data**:
  - Automatically seeds three realistic routines (*Push Day*, *Pull Day*, *Legs & Core*) on first install so new users have a ready-to-use experience immediately.

### 2. [ai_coach_service.dart](file:///Users/admin/Documents/PV/lib/services/ai_coach_service.dart)
Integrates with the Google Gemini API using `gemini-3.6-flash`.
- **`generateWorkoutAnalysis(...)`**:
  - Constructs a prompt packaging the user's logged history, completed volume, frequency, and custom focus.
  - Generates a structured 4-part review: Progressive Overload, Muscle Balance, Recovery Pointers, and Actionable Next-Week Targets.
- **`askCoach(...)`**:
  - Handles freeform fitness Q&A with full context of the user's logged history.

---

## 6. Screens & User Interface (`lib/screens/`)

### 1. [main_navigation_screen.dart](file:///Users/admin/Documents/PV/lib/screens/main_navigation_screen.dart)
- Renders the bottom navigation bar (`Schedules`, `History`, `Analytics`, `AI Coach`).
- Listens to `StorageService` changes to trigger app-wide reactive rebuilds.

### 2. [schedules_tab.dart](file:///Users/admin/Documents/PV/lib/screens/schedules_tab.dart)
- Displays all created routines using `ScheduleCard` widgets.
- Provides a "+ Create Schedule" button and allows tapping any schedule to log a workout.

### 3. [schedule_editor_screen.dart](file:///Users/admin/Documents/PV/lib/screens/schedule_editor_screen.dart)
- Enables routine title, description, accent color, and scheduled weekday selection.
- Features an interactive **ReorderableListView** with drag handles to sort exercises.
- **Normal vs ⚡ Superset Toggle**:
  - Lets users toggle between standard exercises and paired supersets.
  - Dynamically presents inputs for Movement 1 (Primary) and Movement 2 (Paired), along with shared set count.

### 4. [log_session_screen.dart](file:///Users/admin/Documents/PV/lib/screens/log_session_screen.dart)
- Session logging screen with date picker, duration adjuster, and tactical set rows.
- **Superset Row Layout**: Paired movements are rendered in linked rows with individual stepper controls for weight and reps/time.
- **Built-in Plank Stopwatch**: For timed exercises, a 1-tap live stopwatch modal allows timing holds and auto-recording seconds.
- **Controller Cache**: Prevents cursor jumping and text focus loss by caching `TextEditingController` instances per set.

### 5. [history_tab.dart](file:///Users/admin/Documents/PV/lib/screens/history_tab.dart)
- Displays a chronological list of completed workouts using `HistoryCard` components.
- Includes horizontal filter chips to inspect logs for specific routines.

### 6. [analytics_tab.dart](file:///Users/admin/Documents/PV/lib/screens/analytics_tab.dart)
- Summarizes total volume lifted (in kg/tons), total reps, and total completed sets.
- Displays weekly consistency and routine distribution metrics.

### 7. [ai_coach_screen.dart](file:///Users/admin/Documents/PV/lib/screens/ai_coach_screen.dart)
- **AI Performance Review Tab**:
  - Features an editable **"Primary Focus for this Analysis"** input field and preset suggestion chips.
  - Generates Markdown-formatted progressive overload analysis via Gemini 3.6 Flash.
- **Interactive Chat Tab**:
  - Chat interface allowing users to converse directly with their AI Strength Coach.
- **Profile Modal**:
  - Configures bodyweight, age, Gemini API key, training tenure, and default goal.

---

## 7. Custom Reusable Widgets (`lib/widgets/`)

### 1. [schedule_card.dart](file:///Users/admin/Documents/PV/lib/widgets/schedule_card.dart)
- Displays routine details, assigned days, exercise tags, and an amber bolt badge `⚡` for superset pairs.
- Actions: **"Log Workout"**, Edit (pencil), and Delete (trash).

### 2. [history_card.dart](file:///Users/admin/Documents/PV/lib/widgets/history_card.dart)
- Expandable card displaying routine name, completion date, duration, and volume.
- When expanded, shows each exercise, target muscles, and detailed chips for each set.

---

## 8. Design System & Theming (`lib/theme/`)

### [app_theme.dart](file:///Users/admin/Documents/PV/lib/theme/app_theme.dart)
Curated dark-mode theme utilizing high-contrast accents:
- **Backgrounds**: Deep Obsidian `#0B0F17`, Surface Dark `#151D2A`, Surface Lighter `#1E293B`.
- **Primary Accent**: Neon Emerald `#10B981` (buttons, active states, checkboxes).
- **Secondary Accent**: Electric Cyan `#06B6D4` (timed exercises, stopwatches, muscle tags).
- **Superset Accent**: Electric Amber `#F59E0B` (bolt badges, paired movement indicators).
- **Danger**: Vibrant Rose `#F43F5E` (delete actions, error messages).
- **Typography**: Uses the modern Google Fonts **Inter** family.

---

## 9. State Management & Data Flow

```
User Action (e.g. Save Superset or Log Set)
           │
           ▼
    Local State (setState)
           │
           ▼
    StorageService.saveSchedule() / saveLog()
           ├── 1. Writes to SharedPreferences (instant)
           ├── 2. Writes to Cloud Firestore (background)
           └── 3. Calls notifyListeners()
                     │
                     ▼
             MainNavigationScreen
                     │
                     ▼
          Re-renders Active Tabs
```

---

## 10. Testing Suite (`test/`)

### [test/widget_test.dart](file:///Users/admin/Documents/PV/test/widget_test.dart)
Automated unit and widget test suite covering:
1. **App Launch Smoke Test**: Validates dashboard rendering and initial routines.
2. **Plank Timer & Stopwatch Modal**: Verifies hold duration labels and stopwatch modal lifecycle.
3. **Set Manipulation**: Tests dynamic addition, deletion, and completion toggles for workout sets.
4. **AI Coach Profile**: Validates storage and retrieval of `UserProfile` and API key configuration.
5. **Superset Workout Widget Test**: Tests paired movement header rendering, Movement 1 and Movement 2 inputs, and dynamic round additions.

To execute tests:
```bash
docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get && flutter test"
```
