# Flex Connect — Project Analysis & Feature Suggestions

**Date:** August 12, 2026  
**Version Analyzed:** 1.0.10  
**Platform:** Android (Flutter)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Feature Inventory](#feature-inventory)
4. [Strengths](#strengths)
5. [Areas for Improvement](#areas-for-improvement)
6. [Feature Suggestions](#feature-suggestions)
   - [Tier 1: High Impact, Low Effort](#tier-1-high-impact-low-effort)
   - [Tier 2: High Impact, Medium Effort](#tier-2-high-impact-medium-effort)
   - [Tier 3: Game Changers, Higher Effort](#tier-3-game-changers-higher-effort)
7. [Technical Debt & Recommendations](#technical-debt--recommendations)

---

## Executive Summary

Flex Connect is a student companion app built for FAST NUCES students. It scrapes the university's Flex portal (via an embedded WebView), caches all academic records locally, and provides a polished offline-first experience with tools like timetable generation, grading calculators, bunk prediction, and faculty reviews.

The app currently has a strong foundation with 9 feature modules, 7 data models, and 10 services. The architecture follows a feature-based folder structure and uses SharedPreferences as its persistence layer.

---

## Architecture Overview

```
lib/
├── main.dart                  # App entry + RestartWidget
├── core/                      # (Reserved, currently empty)
├── features/
│   ├── auth/                  # Login, WebView scraping engine
│   ├── home/                  # Dashboard with bunk calculator, sync, GPA snapshot
│   ├── attendance/            # Detailed attendance per course
│   ├── marks/                 # Marks breakdown per course/section
│   ├── transcript/            # Semester-wise transcript viewer
│   ├── gpa/                   # GPA calculator + Academic Report (PDF export)
│   ├── timetable/             # Timetable generator from Excel/PDF
│   ├── more/                  # Settings hub + additional tools
│   └── navigation/            # Bottom nav bar + tab management
├── models/                    # 7 data models (attendance, marks, transcript, etc.)
├── services/                  # 10 services (storage, parsers, API, update checker)
└── widgets/                   # Shared UI components (custom toast)
```

### Data Flow

```
University Flex Portal
       ↓ (WebView scraping via university_login_webview.dart)
  SharedPreferences (JSON snapshots)
       ↓ (Storage classes: AttendanceStorage, MarksStorage, etc.)
  Feature Screens (Home, Attendance, Marks, Transcript, GPA)
```

### Navigation Structure (Bottom Nav — 6 Tabs)

| Tab | Screen | Description |
|-----|--------|-------------|
| Home | HomeScreen | Dashboard with profile, CGPA/SGPA, bunk calculator, danger zone, sync controls |
| Transcript | TranscriptScreen | Semester-wise course list with grades |
| Attendance | AttendanceScreen | Per-course attendance with P/L/A breakdown |
| Marks | MarksScreen | Per-course marks with section-level drill-down |
| GPA | GpaScreen | What-if GPA calculator + PDF academic report |
| More | MoreScreen | Timetable, Datesheet, Grading Calculators, Past Papers, Faculty Review, Feedback, Settings |

---

## Feature Inventory

### Core Features (Portal Data)

| # | Feature | File(s) | Description |
|---|---------|---------|-------------|
| 1 | Smart Sync Engine | university_login_webview.dart | Automated WebView scraping chain: Login → Dashboard → Transcript → Attendance → Marks |
| 2 | Offline Dashboard | home_screen.dart | Profile card, CGPA/SGPA stats, semester dropdown, smart sync card |
| 3 | Bunk Calculator | home_screen.dart (CourseBunkStatus) | Per-course "classes you can miss" / "classes to recover" |
| 4 | Danger Zone Alerts | home_screen.dart | Automatic warnings for courses below 80% or near threshold |
| 5 | Attendance Viewer | attendance_screen.dart | Detailed per-course attendance with lecture-by-lecture breakdown |
| 6 | Marks Viewer | marks_screen.dart | Per-course marks with section drill-down, weighted score calculation, "best-of" dropping |
| 7 | New Marks Highlighting | marks_storage.dart | Detects and highlights newly uploaded marks after sync |
| 8 | Transcript Viewer | transcript_screen.dart | Full semester history with CGPA/SGPA per semester |
| 9 | GPA Simulator | gpa_screen.dart | What-if grade editing to simulate SGPA/CGPA changes |
| 10 | Academic Report PDF | academic_report_screen.dart | Generates shareable PDF with GPA trend, grade distribution, and credit analysis |

### Utility Features (Student Tools)

| # | Feature | File(s) | Description |
|---|---------|---------|-------------|
| 11 | Timetable Generator | timetable_screen.dart | Upload Excel/PDF → filter by section → visual grid + planner views with image export |
| 12 | Datesheet Generator | datesheet_screen.dart | Custom exam schedule from uploaded Excel |
| 13 | Absolute Grading Calculator | absolute_grading_calculator_screen.dart | NUCES absolute grading scheme tool |
| 14 | Relative Grading Calculator | relative_grading_calculator_screen.dart | Mean-based relative grading mapper |
| 15 | Past Papers & Resources | past_papers_screen.dart | Google Drive archive browser for exam resources |
| 16 | Faculty Review | faculty_review_screen.dart | Faculty directory with campus/department filtering and Supabase-backed reviews |
| 17 | Exam Rechecking Schedule | rechecking_schedule_screen.dart | Paper showing and rechecking deadline viewer |
| 18 | Send Feedback | feedback_screen.dart | In-app feedback form with auto-filled student info |

### Infrastructure Features

| # | Feature | File(s) | Description |
|---|---------|---------|-------------|
| 19 | In-App Update Checker | update_service.dart | GitHub Releases API-based version checker with download prompt |
| 20 | Auto-Sync on Launch | more_screen.dart / home_screen.dart | Toggle to auto-sync portal data every time the app opens |
| 21 | Password Visibility Toggle | credential_gate.dart | Eye icon to show/hide password on login |
| 22 | Section Input Formatter | timetable_screen.dart | Auto uppercase + hyphen insertion (bcs7c → BCS-7C) |
| 23 | Full Logout Data Wipe | home_screen.dart / more_screen.dart | Complete SharedPreferences.clear() + notifier reset on logout |

---

## Strengths

1. **Offline-First Architecture**: All scraped data is cached locally. Students can access attendance, marks, and transcript without internet after initial sync.

2. **Smart Bunk Calculator**: The CourseBunkStatus model is well-designed — it calculates maxMissable classes and minConsecutiveToAttend for recovery, sorted by urgency.

3. **Marks Intelligence**: The "best-of" dropping logic in MarksSection.activeItemRows is sophisticated — it auto-detects when a professor drops lowest scores based on category weightage math.

4. **New Marks Detection**: MarksStorage.compareAndHighlightNewMarks provides a diff mechanism that highlights newly uploaded evaluations.

5. **Rich Tool Suite**: Timetable generator, datesheet parser, both absolute and relative grading calculators, and past paper search make this a comprehensive student toolkit.

6. **Clean Feature-Based Architecture**: Each feature module is self-contained with clear separation between models, services, and screens.

7. **In-App Update System**: GitHub Releases-based update checker with critical update support (non-dismissable dialog) is well implemented.

---

## Areas for Improvement

### UI/UX Issues
- **No Dark Mode Support**: All screens use hardcoded Colors.white backgrounds. The design system references dark mode colors in some places (more_screen, update_service) but the core screens (Home, Attendance, Marks, Transcript) don't adapt.
- **No Onboarding Flow**: New users land directly on a credential input form with no context about what the app does or how sync works.
- **Single Semester View Only**: Attendance and Marks screens only show the currently selected semester. There's no way to view historical data side-by-side.

### Technical Concerns
- **Giant File Sizes**: home_screen.dart (2000 lines, 69KB), timetable_screen.dart (2300 lines, 87KB), and faculty_review_screen.dart (1300 lines, 55KB) are monolithic files that should be decomposed.
- **SharedPreferences for Large JSON**: Storing entire transcript, attendance, and marks snapshots as JSON strings in SharedPreferences works but will become a bottleneck as data grows. Consider migrating to sqflite or Hive for structured persistence.
- **No Error Logging/Analytics**: There's no crash reporting (e.g., Sentry) or analytics (e.g., Firebase Analytics) to understand app health and user behavior.
- **API Service Hardcoded to localhost**: The ApiService baseUrl still points to localhost/10.0.2.2:5000 for the feedback endpoint.

---

## Feature Suggestions

### Tier 1: High Impact, Low Effort

These features can be built in 1-2 days each using existing data already in the app.

#### 1. Required Final Marks Calculator
**What**: For each course, calculate exactly how many marks the student needs in the Final Exam to achieve a target grade (A, B+, B, etc.).

**Why**: This is THE most requested feature by university students. The app already has all the data — weighted obtained marks per course, total weightage released, and the grading scheme.

**How**: Add a "Target Grade" dropdown to each course card in the Marks screen. Using the existing weightedScore map and remaining weightage (100% - totalWeight), calculate requiredMarks = ((targetPercentage * 100) - obtained) / remainingWeight * 100.

---

#### 2. Attendance Forecast / "What-If Bunk Simulator"
**What**: A slider or input that lets students simulate "If I miss the next N classes, what will my attendance be?"

**Why**: Students constantly do this math mentally. The bunk calculator already shows max missable, but a visual simulator showing the attendance percentage dropping in real-time would be much more engaging.

**How**: Add an interactive slider to each course card in the attendance view. Use the existing CourseBunkStatus.calculate() logic with projected total + N and attended values.

---

#### 3. Semester Comparison View
**What**: Side-by-side SGPA comparison across semesters with a simple bar chart or trend line on the GPA screen.

**Why**: Students want to see their academic trajectory at a glance. The transcript data already contains SGPA per semester.

**How**: Use a simple Flutter CustomPainter or the fl_chart package to render SGPA bars for each semester on the GPA screen header.

---

#### 4. Export Attendance Report
**What**: Share/export attendance summary as a formatted image or PDF (similar to how the timetable grid can be exported as an image).

**Why**: Students often need to share attendance summaries with parents or for record-keeping. The timetable screen already has image export logic using RepaintBoundary and RenderRepaintBoundary.

**How**: Reuse the existing image capture pattern from timetable_screen.dart. Wrap the attendance summary in a RepaintBoundary and capture it.

---

#### 5. Course Notes / Quick Reminders
**What**: Per-course text notes or sticky reminders that appear on each course card (e.g., "Assignment 2 due Friday", "Quiz tomorrow").

**Why**: Students need a quick place to jot down course-specific reminders without switching to another app. This is lightweight to implement with SharedPreferences.

**How**: Add a small notes icon on each course card. Tapping opens a text field that saves to SharedPreferences keyed by course code.

---

### Tier 2: High Impact, Medium Effort

These features require 3-5 days each and may need new packages or UI patterns.

#### 6. CGPA Target Planner
**What**: "I want a 3.5 CGPA by graduation. What grades do I need this semester?"

**Why**: Extends the existing GPA simulator with backward calculation. The transcript already has total credits earned and CGPA.

**How**: Using the formula target_CGPA = (current_QP + new_QP) / (current_credits + new_credits), solve for required new_QP and map it to grade combinations across current courses.

---

#### 7. Smart Notifications
**What**: Local push notifications for:
- Low attendance warnings when approaching 80% threshold
- New marks detected after sync
- Upcoming exam reminders (from datesheet data)

**Why**: Students forget to check the app regularly. Proactive notifications keep them informed.

**How**: Use flutter_local_notifications package. Trigger notifications after each sync by comparing old vs new data (the marks comparison logic already exists in MarksStorage.compareAndHighlightNewMarks).

---

#### 8. Today's Schedule Widget
**What**: A "Today's Classes" card on the Home Screen showing today's remaining classes with times and rooms, pulled from the saved timetable.

**Why**: The timetable data is already stored locally in TimetableStorage. Showing today's schedule on the home dashboard saves students from navigating to the Timetable tab every time.

**How**: Load TimetableStorage data, filter events for today's day-of-week, sort by time, and render a compact card list above the bunk calculator section.

---

#### 9. Marks Change History / Diff Log
**What**: A history log showing "Quiz 1 marks uploaded for CS-220: 18/20" and "Assignment 2 marks updated: 8→9/10".

**Why**: The app already detects new marks via compareAndHighlightNewMarks, but the diff information is lost after the highlight is cleared. Persisting a changelog would be valuable.

**How**: Create a MarksChangelog model and storage. Before overwriting marks data during sync, run the comparison and append entries to a changelog list in SharedPreferences.

---

#### 10. Calendar/ICS Export
**What**: Export timetable and datesheet as .ics calendar files that sync with Google Calendar, Apple Calendar, or Outlook.

**Why**: Students want class schedules and exam dates directly in their phone calendar with native reminders.

**How**: Use the icalendar package or manually generate .ics format strings from timetable events. Share via share_plus (already a dependency).

---

### Tier 3: Game Changers, Higher Effort

These features require 1-2 weeks and significant new infrastructure.

#### 11. Multi-Semester Data Retention
**What**: Instead of overwriting attendance/marks each sync, store snapshots per semester so students can browse historical data.

**Why**: Currently syncing a new semester overwrites the previous semester's data. Students lose access to old attendance and marks.

**How**: Change storage keys from flex_attendance_data to flex_attendance_data_{semesterCode}. Modify storage classes to support loading by semester code.

---

#### 12. Course Registration Assistant
**What**: During registration week, suggest optimal course combinations based on:
- Prerequisite chain from transcript (which courses are unlocked)
- Faculty ratings from the review system
- Timetable conflict detection

**Why**: Course registration is the most stressful week every semester. This would be a killer feature.

**How**: Build a prerequisite graph from transcript course codes, cross-reference with faculty data, and use timetable slot matching to detect conflicts.

---

#### 13. Anonymous Class Group Chat / Discussion Board
**What**: Per-course anonymous discussion threads where students can ask questions, share resources, and discuss exams.

**Why**: Every batch creates WhatsApp groups that are chaotic and ephemeral. An in-app, course-specific discussion board would be more organized.

**How**: Use the existing Supabase backend to create a discussions table with course_code, message, timestamp, and anonymous_id fields.

---

#### 14. Peer Study Group Finder
**What**: Match students in the same courses who want to study together, based on their enrolled courses (from transcript data).

**Why**: Finding study partners is difficult, especially for students who don't know many classmates.

**How**: Opt-in feature where students share their enrolled courses anonymously. Match students with 3+ common courses.

---

#### 15. Campus Map & Room Finder
**What**: Interactive campus map showing building layouts and room locations, searchable by room number from timetable data.

**Why**: New students and those with classes in unfamiliar buildings waste time finding rooms every semester.

**How**: Create SVG-based campus maps per campus. Link room numbers from timetable events to map locations.

---

## Technical Debt & Recommendations

### Immediate (Before Next Release)
1. **Extract Widget Components**: Break home_screen.dart into smaller widgets: ProfileHeader, StatsSection, SmartSyncCard, DangerZone, GpaSnapshot, CourseAttendanceCard.
2. **Fix API Service URL**: The feedback API still points to localhost. Either deploy the backend or use Supabase edge functions.
3. **Add Loading Skeletons**: Replace raw CircularProgressIndicator with shimmer/skeleton loading states for a more polished feel.

### Short-Term (Next 2-3 Releases)
4. **Migrate to Hive/SQLite**: Move from SharedPreferences JSON strings to a proper local database for better performance and querying.
5. **Add Crash Reporting**: Integrate Sentry or Firebase Crashlytics for production error monitoring.
6. **Implement Dark Mode**: The design tokens exist in some screens but aren't applied consistently. Create a proper ThemeData with dark variant.
7. **Add Unit Tests**: Critical calculations (CourseBunkStatus, weightedScore, GPA simulation) should have unit tests to prevent regressions.

### Long-Term (Roadmap)
8. **State Management**: Consider adopting Riverpod or Bloc for complex state as the app grows beyond simple setState patterns.
9. **iOS Support**: The app uses Android-specific packages (Gal for gallery, WebView). Plan for iOS compatibility.
10. **Backend Migration**: As features like chat, group finder, and course registration grow, a proper backend (beyond Supabase) may be needed.

---

## Priority Recommendation

If I had to pick the top 3 features to implement next, they would be:

1. **Required Final Marks Calculator** (Tier 1, #1) — Immediate student value, pure math using existing data
2. **Today's Schedule on Home Screen** (Tier 2, #8) — Makes the home screen a daily utility, uses existing data
3. **CGPA Target Planner** (Tier 2, #6) — Extends the GPA simulator into a planning tool students will use every semester

These three features would transform Flex Connect from a "data viewer" into a "daily academic companion" that students open every day.
