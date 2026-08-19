package com.example.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException
import java.util.Calendar

class NextClassWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val views = calculateWidgetLayout(context, widgetData, options)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = calculateWidgetLayout(context, widgetData, newOptions)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun parseMinutes(timeStr: String): Pair<Int, Int>? {
        try {
            val parts = timeStr.split("-")
            if (parts.size != 2) return null

            val startParts = parts[0].trim().split(":")
            val endParts = parts[1].trim().split(":")
            if (startParts.size != 2 || endParts.size != 2) return null

            var startH = startParts[0].toInt()
            val startM = startParts[1].toInt()
            var endH = endParts[0].toInt()
            val endM = endParts[1].toInt()

            if (startH in 1..7) startH += 12
            if (endH in 1..7) endH += 12

            val startMinutes = startH * 60 + startM
            val endMinutes = endH * 60 + endM
            return Pair(startMinutes, endMinutes)
        } catch (e: Exception) {
            return null
        }
    }

    private fun calculateWidgetLayout(
        context: Context,
        widgetData: SharedPreferences,
        options: Bundle
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.next_class_widget)

        // Attach click intent to open the app when tapping anywhere on the widget
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
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

        val isOffDay = widgetData.getBoolean("is_off_day", true)
        val todaysScheduleJson = widgetData.getString("todays_schedule_json", "[]") ?: "[]"

        // Dynamic Real-time Calculation based on phone's current clock
        val cal = Calendar.getInstance()
        val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        var ongoingCourse = ""
        var ongoingTime = ""
        var ongoingRoom = ""
        var nextCourse = ""
        var nextTime = ""
        var nextRoom = ""
        var allClassesDone = false

        try {
            val jsonArray = JSONArray(todaysScheduleJson)
            if (jsonArray.length() > 0) {
                var maxEndMinutes = 0
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val timeStr = obj.optString("time", "")
                    val courseStr = obj.optString("course", "")
                    val roomStr = obj.optString("room", "")

                    val range = parseMinutes(timeStr)
                    if (range != null) {
                        val (startMin, endMin) = range
                        if (endMin > maxEndMinutes) maxEndMinutes = endMin

                        if (currentMinutes >= startMin && currentMinutes < endMin) {
                            ongoingCourse = courseStr
                            ongoingTime = timeStr
                            ongoingRoom = roomStr
                        } else if (currentMinutes < startMin && nextCourse.isEmpty()) {
                            nextCourse = courseStr
                            nextTime = timeStr
                            nextRoom = roomStr
                        }
                    }
                }

                if (ongoingCourse.isEmpty() && nextCourse.isEmpty() && currentMinutes >= maxEndMinutes) {
                    allClassesDone = true
                }
            }
        } catch (e: Exception) {
            // Fallback to cached string values if needed
            ongoingCourse = widgetData.getString("ongoing_course", "") ?: ""
            ongoingTime = widgetData.getString("ongoing_time", "") ?: ""
            ongoingRoom = widgetData.getString("ongoing_room", "") ?: ""
            nextCourse = widgetData.getString("next_course", "") ?: ""
            nextTime = widgetData.getString("next_time", "") ?: ""
            nextRoom = widgetData.getString("next_room", "") ?: ""
        }

        val isAllCompleted = allClassesDone || ongoingCourse.contains("Finished") || ongoingCourse.contains("Completed")

        if (isOffDay || isAllCompleted) {
            views.setViewVisibility(R.id.widget_layout_off_day, View.VISIBLE)
            views.setViewVisibility(R.id.widget_layout_class_info, View.GONE)

            if (isAllCompleted) {
                views.setTextViewText(R.id.widget_off_day_badge, "🎉 DONE")
                views.setTextViewText(R.id.widget_off_day_title, "All Classes Done Today")
                views.setTextViewText(R.id.widget_off_day_subtitle, "Great job! Relax or prepare for tomorrow.")
            } else {
                views.setTextViewText(R.id.widget_off_day_badge, "☕ OFF DAY")
                views.setTextViewText(R.id.widget_off_day_title, "No Classes Today ✨")
                views.setTextViewText(R.id.widget_off_day_subtitle, "Enjoy your day off or review past courses.")
            }
        } else {
            views.setViewVisibility(R.id.widget_layout_off_day, View.GONE)
            views.setViewVisibility(R.id.widget_layout_class_info, View.VISIBLE)

            if (ongoingCourse.isNotEmpty()) {
                // Ongoing class is the hero
                views.setTextViewText(R.id.widget_status_badge, "● IN PROGRESS")
                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_live)
                views.setTextColor(R.id.widget_status_badge, Color.parseColor("#6EE7B7"))

                views.setTextViewText(R.id.widget_hero_course, ongoingCourse)
                views.setTextViewText(R.id.widget_hero_time, "🕒 $ongoingTime")
                views.setTextViewText(R.id.widget_hero_room, "📍 $ongoingRoom")

                if (nextCourse.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_secondary_strip, View.VISIBLE)
                    views.setTextViewText(
                        R.id.widget_secondary_text,
                        "$nextCourse • $nextTime • $nextRoom"
                    )
                } else {
                    views.setViewVisibility(R.id.widget_secondary_strip, View.GONE)
                }
            } else if (nextCourse.isNotEmpty()) {
                // Next class is the hero
                views.setTextViewText(R.id.widget_status_badge, "⏱ NEXT UP")
                views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_next)
                views.setTextColor(R.id.widget_status_badge, Color.parseColor("#93C5FD"))

                views.setTextViewText(R.id.widget_hero_course, nextCourse)
                views.setTextViewText(R.id.widget_hero_time, "🕒 $nextTime")
                views.setTextViewText(R.id.widget_hero_room, "📍 $nextRoom")

                views.setViewVisibility(R.id.widget_secondary_strip, View.GONE)
            } else {
                // Classes finished fallback
                views.setViewVisibility(R.id.widget_layout_off_day, View.VISIBLE)
                views.setViewVisibility(R.id.widget_layout_class_info, View.GONE)
                views.setTextViewText(R.id.widget_off_day_badge, "🎉 DONE")
                views.setTextViewText(R.id.widget_off_day_title, "All Classes Done Today")
                views.setTextViewText(R.id.widget_off_day_subtitle, "Great job! Relax or prepare for tomorrow.")
            }

            // Expanded schedule handling (when resized taller)
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

                try {
                    val jsonArray = JSONArray(todaysScheduleJson)
                    for (i in 0 until 5) {
                        if (i < jsonArray.length()) {
                            val classObj = jsonArray.getJSONObject(i)
                            views.setViewVisibility(rowIds[i], View.VISIBLE)
                            views.setTextViewText(timeIds[i], classObj.optString("time", ""))
                            views.setTextViewText(courseIds[i], classObj.optString("course", ""))
                            views.setTextViewText(roomIds[i], "📍 " + classObj.optString("room", ""))
                        } else {
                            views.setViewVisibility(rowIds[i], View.GONE)
                        }
                    }
                } catch (e: JSONException) {
                    for (rowId in rowIds) {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                }
            } else {
                views.setViewVisibility(R.id.widget_today_schedule_container, View.GONE)
            }
        }

        return views
    }
}
