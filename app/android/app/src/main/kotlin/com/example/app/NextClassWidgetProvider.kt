package com.example.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONException
import java.util.Calendar

class NextClassWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, NextClassWidgetProvider::class.java)
            )
            if (ids != null && ids.isNotEmpty()) {
                val widgetData = HomeWidgetPlugin.getData(context)
                onUpdate(context, appWidgetManager, ids, widgetData)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        var nextMilestoneEpochMs: Long? = null

        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val result = calculateWidgetLayout(context, widgetData, options)
            appWidgetManager.updateAppWidget(appWidgetId, result.views)
            if (result.nextMilestoneMs != null) {
                if (nextMilestoneEpochMs == null || result.nextMilestoneMs < nextMilestoneEpochMs) {
                    nextMilestoneEpochMs = result.nextMilestoneMs
                }
            }
        }

        if (nextMilestoneEpochMs != null) {
            scheduleNextAlarm(context, nextMilestoneEpochMs)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val result = calculateWidgetLayout(context, widgetData, newOptions)
        appWidgetManager.updateAppWidget(appWidgetId, result.views)
        if (result.nextMilestoneMs != null) {
            scheduleNextAlarm(context, result.nextMilestoneMs)
        }
    }

    private data class ClassItem(
        val time: String,
        val course: String,
        val room: String,
        val startMin: Int,
        val endMin: Int
    )

    private data class WidgetCalculationResult(
        val views: RemoteViews,
        val nextMilestoneMs: Long?
    )

    private fun parseMinutes(timeStr: String): Pair<Int, Int>? {
        try {
            val parts = timeStr.split("-")
            if (parts.size != 2) return null

            val startClean = parts[0].replace("(?i)[ap]m".toRegex(), "").trim()
            val endClean = parts[1].replace("(?i)[ap]m".toRegex(), "").trim()

            val startParts = startClean.split(":")
            val endParts = endClean.split(":")
            if (startParts.size != 2 || endParts.size != 2) return null

            var startH = startParts[0].trim().toInt()
            val startM = startParts[1].trim().toInt()
            var endH = endParts[0].trim().toInt()
            val endM = endParts[1].trim().toInt()

            if (startH in 1..7) startH += 12
            if (endH in 1..7) endH += 12

            val startMinutes = startH * 60 + startM
            val endMinutes = endH * 60 + endM
            return Pair(startMinutes, endMinutes)
        } catch (e: Exception) {
            return null
        }
    }

    private fun parseDatesheetDate(dateStr: String): Triple<Int, Int, Int>? {
        try {
            val clean = dateStr.trim()
            val parts = clean.split(Regex("[-/\\s,]+"))
            if (parts.size >= 3) {
                val day = parts[0].toIntOrNull() ?: 1
                val monthName = parts[1].lowercase()
                val year = parts[2].toIntOrNull() ?: Calendar.getInstance().get(Calendar.YEAR)
                val month = when (monthName.take(3)) {
                    "jan" -> 1
                    "feb" -> 2
                    "mar" -> 3
                    "apr" -> 4
                    "may" -> 5
                    "jun" -> 6
                    "jul" -> 7
                    "aug" -> 8
                    "sep" -> 9
                    "oct" -> 10
                    "nov" -> 11
                    "dec" -> 12
                    else -> 1
                }
                return Triple(year, month, day)
            }
        } catch (e: Exception) {}
        return null
    }

    private fun calculateWidgetLayout(
        context: Context,
        widgetData: SharedPreferences,
        options: Bundle
    ): WidgetCalculationResult {
        val views = RemoteViews(context.packageName, R.layout.next_class_widget)

        // Attach click intent to open the app and navigate to today's timetable when tapping anywhere on the widget
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                data = android.net.Uri.parse("flexconnect://today_timetable")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
        } catch (e: Exception) {
            // Ignore click intent errors
        }

        val cal = Calendar.getInstance()
        val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        val todayWeekdayName = when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "Monday"
            Calendar.TUESDAY -> "Tuesday"
            Calendar.WEDNESDAY -> "Wednesday"
            Calendar.THURSDAY -> "Thursday"
            Calendar.FRIDAY -> "Friday"
            Calendar.SATURDAY -> "Saturday"
            Calendar.SUNDAY -> "Sunday"
            else -> "Monday"
        }

        // Check if there is an exam today from datesheet
        val datesheetJson = widgetData.getString("datesheet_events_json", "[]") ?: "[]"
        var todayExamCourse: String? = null
        var todayExamType: String? = null
        var todayExamTime: String? = null

        try {
            val examArray = JSONArray(datesheetJson)
            if (examArray.length() > 0) {
                val todayYear = cal.get(Calendar.YEAR)
                val todayMonth = cal.get(Calendar.MONTH) + 1
                val todayDay = cal.get(Calendar.DAY_OF_MONTH)

                for (i in 0 until examArray.length()) {
                    val examObj = examArray.getJSONObject(i)
                    val dateStr = examObj.optString("date", "")
                    val parsed = parseDatesheetDate(dateStr)
                    if (parsed != null &&
                        parsed.first == todayYear &&
                        parsed.second == todayMonth &&
                        parsed.third == todayDay
                    ) {
                        todayExamCourse = examObj.optString("courseName", "")
                        todayExamType = examObj.optString("type", "")
                        todayExamTime = examObj.optString("time", "")
                        break
                    }
                }
            }
        } catch (e: Exception) {}

        if (todayExamCourse != null && todayExamCourse.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_layout_off_day, View.GONE)
            views.setViewVisibility(R.id.widget_layout_class_info, View.VISIBLE)

            views.setTextViewText(R.id.widget_status_badge, "EXAM")
            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_live)
            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#FDE047"))

            views.setTextViewText(R.id.widget_hero_course, "$todayExamCourse ($todayExamType)")
            views.setTextViewText(R.id.widget_hero_time, todayExamTime ?: "Exam Session")
            views.setTextViewText(R.id.widget_hero_room, "Exam Hall")
            views.setViewVisibility(R.id.widget_secondary_strip, View.GONE)
            views.setViewVisibility(R.id.widget_today_schedule_container, View.GONE)

            val midnightCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            return WidgetCalculationResult(views, midnightCal.timeInMillis)
        }

        // Get today's classes from weekly schedule (or fallback to today's schedule)
        val weeklyJson = widgetData.getString("weekly_schedule_json", "{}") ?: "{}"
        val todayClasses = mutableListOf<ClassItem>()

        try {
            val weeklyObj = JSONObject(weeklyJson)
            if (weeklyObj.has(todayWeekdayName)) {
                val dayArray = weeklyObj.getJSONArray(todayWeekdayName)
                for (i in 0 until dayArray.length()) {
                    val obj = dayArray.getJSONObject(i)
                    val timeStr = obj.optString("time", "")
                    val courseStr = obj.optString("course", "")
                    val roomStr = obj.optString("room", "")
                    val range = parseMinutes(timeStr)
                    if (range != null) {
                        todayClasses.add(ClassItem(timeStr, courseStr, roomStr, range.first, range.second))
                    }
                }
            }
        } catch (e: Exception) {
            val fallbackJson = widgetData.getString("todays_schedule_json", "[]") ?: "[]"
            try {
                val array = JSONArray(fallbackJson)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val timeStr = obj.optString("time", "")
                    val courseStr = obj.optString("course", "")
                    val roomStr = obj.optString("room", "")
                    val range = parseMinutes(timeStr)
                    if (range != null) {
                        todayClasses.add(ClassItem(timeStr, courseStr, roomStr, range.first, range.second))
                    }
                }
            } catch (e2: Exception) {}
        }

        // Sort today's classes by start time
        todayClasses.sortBy { it.startMin }

        var nextMilestoneMinutes: Int? = null

        if (todayClasses.isEmpty()) {
            // Off Day
            views.setViewVisibility(R.id.widget_layout_off_day, View.VISIBLE)
            views.setViewVisibility(R.id.widget_layout_class_info, View.GONE)
            views.setTextViewText(R.id.widget_off_day_badge, "DAY OFF")
            views.setTextViewText(R.id.widget_off_day_title, "No Classes Today")
            views.setTextViewText(R.id.widget_off_day_subtitle, "No schedule recorded for today.")

            val midnightCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            return WidgetCalculationResult(views, midnightCal.timeInMillis)
        }

        var ongoingClass: ClassItem? = null
        var nextClass: ClassItem? = null
        var maxEndMinutes = 0

        for (item in todayClasses) {
            if (item.endMin > maxEndMinutes) maxEndMinutes = item.endMin

            if (currentMinutes >= item.startMin && currentMinutes < item.endMin) {
                ongoingClass = item
            } else if (currentMinutes < item.startMin && nextClass == null) {
                nextClass = item
            }
        }

        val isAllCompleted = (ongoingClass == null && nextClass == null && currentMinutes >= maxEndMinutes)

        if (isAllCompleted) {
            views.setViewVisibility(R.id.widget_layout_off_day, View.VISIBLE)
            views.setViewVisibility(R.id.widget_layout_class_info, View.GONE)
            views.setTextViewText(R.id.widget_off_day_badge, "COMPLETED")
            views.setTextViewText(R.id.widget_off_day_title, "All Classes Completed")
            views.setTextViewText(R.id.widget_off_day_subtitle, "No more classes scheduled for today.")

            val midnightCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            return WidgetCalculationResult(views, midnightCal.timeInMillis)
        }

        // Active class display
        views.setViewVisibility(R.id.widget_layout_off_day, View.GONE)
        views.setViewVisibility(R.id.widget_layout_class_info, View.VISIBLE)

        if (ongoingClass != null) {
            // Hero is Ongoing class
            val minsLeft = (ongoingClass.endMin - currentMinutes).coerceAtLeast(1)
            val countdownBadge = if (minsLeft <= 1) "1M LEFT" else "${minsLeft}M LEFT"
            views.setTextViewText(R.id.widget_status_badge, "IN PROGRESS • $countdownBadge")
            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_live)
            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#6EE7B7"))

            views.setTextViewText(R.id.widget_hero_course, ongoingClass.course)
            views.setTextViewText(R.id.widget_hero_time, ongoingClass.time)
            views.setTextViewText(R.id.widget_hero_room, ongoingClass.room.ifEmpty { "TBA" })

            // Live Attendance & Bunk Safety Indicator
            val attendanceObj = findCourseAttendance(widgetData, ongoingClass.course)
            if (attendanceObj != null) {
                views.setViewVisibility(R.id.widget_hero_attendance_container, View.VISIBLE)
                val pct = attendanceObj.optDouble("percentage", 0.0)
                val bunks = attendanceObj.optInt("maxMissable", 0)
                val isBelow80 = attendanceObj.optBoolean("isBelow80", false)
                val minAttend = attendanceObj.optInt("minConsecutiveToAttend", 0)

                if (!isBelow80 && bunks > 0) {
                    val bunkLabel = if (bunks == 1) "bunk" else "bunks"
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • %d %s available", pct, bunks, bunkLabel)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#6EE7B7"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_bunk)
                } else if (!isBelow80 && bunks == 0) {
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • On border (0 bunks)", pct)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#FDE047"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_urgent)
                } else {
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • Short (Attend next %d)", pct, minAttend)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#FCA5A5"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_danger)
                }
            } else {
                views.setViewVisibility(R.id.widget_hero_attendance_container, View.GONE)
            }

            if (nextClass != null) {
                views.setViewVisibility(R.id.widget_secondary_strip, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_secondary_text,
                    "${nextClass.course} • ${nextClass.time} • ${nextClass.room}"
                )
            } else {
                views.setViewVisibility(R.id.widget_secondary_strip, View.GONE)
            }

            nextMilestoneMinutes = ongoingClass.endMin
        } else if (nextClass != null) {
            // Between classes: Ongoing is finished, Hero is Next Up
            val minsUntil = (nextClass.startMin - currentMinutes).coerceAtLeast(1)
            val countdownBadge = if (minsUntil < 60) "${minsUntil}M" else "${minsUntil / 60}H ${minsUntil % 60}M"

            if (minsUntil <= 15) {
                views.setTextViewText(R.id.widget_status_badge, "STARTS IN $countdownBadge")
                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_urgent)
                views.setTextColor(R.id.widget_status_badge, Color.parseColor("#FDE047"))
            } else {
                views.setTextViewText(R.id.widget_status_badge, "UP NEXT • IN $countdownBadge")
                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_next)
                views.setTextColor(R.id.widget_status_badge, Color.parseColor("#93C5FD"))
            }

            views.setTextViewText(R.id.widget_hero_course, nextClass.course)
            views.setTextViewText(R.id.widget_hero_time, nextClass.time)
            views.setTextViewText(R.id.widget_hero_room, nextClass.room.ifEmpty { "TBA" })

            // Live Attendance & Bunk Safety Indicator
            val attendanceObj = findCourseAttendance(widgetData, nextClass.course)
            if (attendanceObj != null) {
                views.setViewVisibility(R.id.widget_hero_attendance_container, View.VISIBLE)
                val pct = attendanceObj.optDouble("percentage", 0.0)
                val bunks = attendanceObj.optInt("maxMissable", 0)
                val isBelow80 = attendanceObj.optBoolean("isBelow80", false)
                val minAttend = attendanceObj.optInt("minConsecutiveToAttend", 0)

                if (!isBelow80 && bunks > 0) {
                    val bunkLabel = if (bunks == 1) "bunk" else "bunks"
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • %d %s available", pct, bunks, bunkLabel)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#6EE7B7"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_bunk)
                } else if (!isBelow80 && bunks == 0) {
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • On border (0 bunks)", pct)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#FDE047"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_urgent)
                } else {
                    views.setTextViewText(
                        R.id.widget_hero_attendance_text,
                        String.format("%.1f%% • Short (Attend next %d)", pct, minAttend)
                    )
                    views.setTextColor(R.id.widget_hero_attendance_text, Color.parseColor("#FCA5A5"))
                    views.setInt(R.id.widget_hero_attendance_container, "setBackgroundResource", R.drawable.widget_badge_danger)
                }
            } else {
                views.setViewVisibility(R.id.widget_hero_attendance_container, View.GONE)
            }

            views.setViewVisibility(R.id.widget_secondary_strip, View.GONE)

            nextMilestoneMinutes = nextClass.startMin
        }

        // Expanded schedule handling (when widget is resized vertically)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        val isExpanded = minHeight >= 170

        if (isExpanded) {
            views.setViewVisibility(R.id.widget_today_schedule_container, View.VISIBLE)

            val rowIds = arrayOf(
                R.id.widget_class_row_1,
                R.id.widget_class_row_2,
                R.id.widget_class_row_3,
                R.id.widget_class_row_4,
                R.id.widget_class_row_5
            )
            val timeIds = arrayOf(
                R.id.widget_row_time_1,
                R.id.widget_row_time_2,
                R.id.widget_row_time_3,
                R.id.widget_row_time_4,
                R.id.widget_row_time_5
            )
            val courseIds = arrayOf(
                R.id.widget_row_course_1,
                R.id.widget_row_course_2,
                R.id.widget_row_course_3,
                R.id.widget_row_course_4,
                R.id.widget_row_course_5
            )
            val roomIds = arrayOf(
                R.id.widget_row_room_1,
                R.id.widget_row_room_2,
                R.id.widget_row_room_3,
                R.id.widget_row_room_4,
                R.id.widget_row_room_5
            )

            for (i in 0 until 5) {
                if (i < todayClasses.size) {
                    val classObj = todayClasses[i]
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setTextViewText(timeIds[i], classObj.time)
                    views.setTextViewText(courseIds[i], classObj.course)
                    views.setTextViewText(roomIds[i], classObj.room.ifEmpty { "TBA" })
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }
        } else {
            views.setViewVisibility(R.id.widget_today_schedule_container, View.GONE)
        }

        val currentEpoch = System.currentTimeMillis()
        val refreshIntervalMs = 5 * 60 * 1000L
        val nextPeriodicMs = currentEpoch + refreshIntervalMs

        val milestoneEpochMs = if (nextMilestoneMinutes != null && nextMilestoneMinutes > currentMinutes) {
            val targetCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, nextMilestoneMinutes / 60)
                set(Calendar.MINUTE, nextMilestoneMinutes % 60)
                set(Calendar.SECOND, 1)
                set(Calendar.MILLISECOND, 0)
            }
            val targetMs = targetCal.timeInMillis
            if (targetMs in (currentEpoch + 1)..nextPeriodicMs) targetMs else nextPeriodicMs
        } else {
            val midnightCal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            midnightCal.timeInMillis
        }

        return WidgetCalculationResult(views, milestoneEpochMs)
    }

    private fun findCourseAttendance(widgetData: SharedPreferences, courseName: String): JSONObject? {
        try {
            val jsonStr = widgetData.getString("attendance_data_json", "{}") ?: "{}"
            val map = JSONObject(jsonStr)
            val cleanCourse = courseName.lowercase().replace(Regex("[^a-z0-9]"), " ").trim()
            if (cleanCourse.isEmpty()) return null

            if (map.has(cleanCourse)) {
                return map.getJSONObject(cleanCourse)
            }

            val keys = map.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val cleanKey = key.lowercase().replace(Regex("[^a-z0-9]"), " ").trim()
                if (cleanKey.isEmpty()) continue
                if (cleanCourse.contains(cleanKey) || cleanKey.contains(cleanCourse)) {
                    return map.getJSONObject(key)
                }
            }
        } catch (e: Exception) {}
        return null
    }

    private fun scheduleNextAlarm(context: Context, nextEpochMs: Long) {
        if (nextEpochMs <= System.currentTimeMillis()) return

        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, NextClassWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, NextClassWidgetProvider::class.java)
                )
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextEpochMs,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    nextEpochMs,
                    pendingIntent
                )
            }
        } catch (e: Exception) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, NextClassWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val ids = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, NextClassWidgetProvider::class.java)
                    )
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1001,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.set(AlarmManager.RTC_WAKEUP, nextEpochMs, pendingIntent)
            } catch (e2: Exception) {}
        }
    }
}
