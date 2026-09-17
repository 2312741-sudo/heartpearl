package com.heartpearl.heartpearl

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.net.URL
import kotlin.concurrent.thread

class TamChauWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.tam_chau_widget)
            val latestPhotoUrl = widgetData.getString("latestPhotoUrl", null)

            if (!latestPhotoUrl.isNullOrEmpty()) {
                thread {
                    try {
                        val stream = URL(latestPhotoUrl).openStream()
                        val bitmap = BitmapFactory.decodeStream(stream)
                        views.setImageViewBitmap(R.id.widget_image, bitmap)
                        views.setViewVisibility(R.id.widget_title, View.GONE)
                        appWidgetManager.updateAppWidget(widgetId, views)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else {
                views.setViewVisibility(R.id.widget_title, View.VISIBLE)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }
}
