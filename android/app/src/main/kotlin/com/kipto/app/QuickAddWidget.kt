package com.kipto.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: this month's spending, written by the app whenever it
 * changes, and a + button that opens the app straight on the add-expense form.
 */
class QuickAddWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
            setTextViewText(
                R.id.widget_label,
                widgetData.getString("label", null) ?: context.getString(R.string.widget_label_default),
            )
            setTextViewText(
                R.id.widget_total,
                widgetData.getString("total", null) ?: context.getString(R.string.widget_total_default),
            )
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("kipto://home")),
            )
            setOnClickPendingIntent(
                R.id.widget_add,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("kipto://add")),
            )
        }
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
