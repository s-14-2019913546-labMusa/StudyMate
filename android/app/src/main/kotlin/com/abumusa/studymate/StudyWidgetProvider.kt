package com.abumusa.studymate

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * হোম স্ক্রিন উইজেট: আজকের পরের টাস্ক, streak আর পরের নামাজের ওয়াক্ত।
 * ডেটা অ্যাপের lib/home_widget_service.dart থেকে আসে।
 */
class StudyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.study_widget).apply {
                setTextViewText(R.id.widget_next_label, widgetData.getString("next_label", "Next task"))
                setTextViewText(R.id.widget_next_task, widgetData.getString("next_task", "Open StudyMate to load tasks"))
                setTextViewText(R.id.widget_next_time, widgetData.getString("next_time", ""))
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "🔥 0"))
                setTextViewText(R.id.widget_prayer, widgetData.getString("prayer", ""))
                setTextViewText(R.id.widget_progress, widgetData.getString("progress", ""))

                val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, open)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
