# ⚡ Flex Connect

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white&style=for-the-badge)](https://www.android.com)
[![GitHub Release](https://img.shields.io/github/v/release/Muhammad-Umer34/Flex-Connect-App?color=2563EB&style=for-the-badge)](https://github.com/Muhammad-Umer34/Flex-Connect-App/releases)

Flex Connect is a modern, premium academic companion application designed for university students to track and organize their academic lives. It aggregates and formats university portal data to provide intelligent tracking tools—such as attendance safety calculators, marks indicators, dynamic GPA report tools, and parsed class timetables—all wrapped inside a fluid, offline-first user interface.

---

## 📸 App Preview

| 📱 Home Dashboard | 📊 Marks & Grades | 📅 Timetable Schedule |
|:---:|:---:|:---:|
| <img src="screenshots/home_screen.png" width="240" alt="Home Dashboard" /> | <img src="screenshots/marks_screen.png" width="240" alt="Marks screen" /> | <img src="screenshots/timetable_screen.png" width="240" alt="Timetable screen" /> |

| 📇 Attendance Tracker | 📈 GPA Academic Report | ⚙️ More & Settings |
|:---:|:---:|:---:|
| <img src="screenshots/attendance_screen.png" width="240" alt="Attendance Screen" /> | <img src="screenshots/gpa_screen.png" width="240" alt="GPA Report" /> | <img src="screenshots/more_screen.png" width="240" alt="Settings & More" /> |

---

## ✨ Features

### 1. 🏠 Dynamic Home Dashboard
* **Real-time Overview**: Quick access to your current CGPA, SGPA, attendance averages, and syncing status.
* **Progressive Semester Dropdown**: Displays only your enrollment semester for first-time users, dynamically unlocking all parsed semesters from your transcript after the first sync.
* **Background Portal Sync**: Fast, secure background updates with an integrated reCAPTCHA resolver.

### 2. 📳 Attendance & Bunk Calculator
* **Detailed Logs**: Track presence status and duration for every lecture.
* **Bunk Estimator**: Automatically calculates how many upcoming lectures you can safely miss (or must attend) to maintain the required $80\%$ minimum attendance threshold.

### 3. 🔔 Marks Evaluation & Indicators
* **New Marks Badging**: Receive a phone haptic vibration on portal sync and see a red notification dot on the bottom navigation bar when new marks are uploaded.
* **Eval Statistics**: View class averages, highest/lowest marks, standard deviations, and dropped-mark indicators.

### 4. 📅 Parser-Powered Timetable
* **Excel Timetable Importer**: Parses complex university timetables directly into clean local event schedules.
* **Custom Events**: Add personal study groups or exam events to customize your calendar grid.

### 5. 📈 GPA & Academic Goals Planner
* **Interactive Transcript**: View historical course grades, credit hours, and points.
* **Target Calculator**: Plan target CGPA goals and see what grades you need in current courses to hit them.

---

## 🛠️ Technology Stack

* **Mobile App Framework**: Flutter (Dart)
* **Storage**: Shared Preferences (Offline-first data caching)
* **Engine & Scrapers**: Node.js & Playwright/Express (Portal scrapers)
* **Database**: Supabase
* **Distribution Check**: GitHub Releases API (In-app update engine)

---

## 📥 How to Download & Install

1. Go to the official **[Releases Page](https://github.com/Muhammad-Umer34/Flex-Connect-App/releases)**.
2. Under the latest version block, download the **`app-release.apk`** file.
3. Open the downloaded file on your Android device.
4. Select **Install** (if prompted, enable "Install from Unknown Sources" or "Allow installation from this source" in your browser/file explorer settings).

---

## 🔒 Privacy & Safety
* **Local-First Caching**: All credentials, grades, logs, and attendance data are stored **strictly on your local device**. 
* **Zero External Credential Storage**: Login passwords and personal scraping session tokens are never uploaded, shared, or saved on any remote database.
