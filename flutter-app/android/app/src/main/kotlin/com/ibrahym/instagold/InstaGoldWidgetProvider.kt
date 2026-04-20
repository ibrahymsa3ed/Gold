package com.ibrahym.instagold

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.LayoutDirection
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Android home-screen widget for InstaGold.
 *
 * Reads sell prices written by the Flutter side via the `home_widget` plugin
 * (App Group equivalent on Android = a SharedPreferences file owned by the
 * plugin) and renders them in a single resizable RemoteViews layout.
 *
 * Stays intentionally minimal: dark theme only, one layout, three rows
 * (21K / 24K / Ounce), no configuration screen. Tap anywhere opens the app.
 *
 * The Flutter call sites already target this exact FQN — see
 * lib/screens/dashboard_screen.dart::_afterPricesLoaded and
 * lib/services/price_watcher.dart — so the plugin will route updates to
 * `onUpdate` automatically once this class exists.
 */
class InstaGoldWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        // Western digits in both locales (matches iOS widget + product spec).
        val priceFormatter = NumberFormat.getNumberInstance(Locale.US).apply {
            maximumFractionDigits = 0
            isGroupingUsed = true
        }

        val price21k = readDouble(widgetData, "price_21k")
        val price24k = readDouble(widgetData, "price_24k")
        val priceOunce = readDouble(widgetData, "price_ounce")
        val updatedAt = widgetData.getString("updated_at", null)
        val locale = widgetData.getString("locale", "en") ?: "en"
        val isAr = locale == "ar"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.instagold_widget)

            // Header
            views.setTextViewText(R.id.widget_brand, "InstaGold")
            val timeText = updatedAt?.let { formatTimeShort(it) }
            if (timeText != null) {
                views.setTextViewText(R.id.widget_time, timeText)
                views.setViewVisibility(R.id.widget_time, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_time, View.GONE)
            }

            // Three price rows
            views.setTextViewText(R.id.widget_label_21, karatLabel(21, isAr))
            views.setTextViewText(R.id.widget_value_21, formatValue(price21k, "", priceFormatter))

            views.setTextViewText(R.id.widget_label_24, karatLabel(24, isAr))
            views.setTextViewText(R.id.widget_value_24, formatValue(price24k, "", priceFormatter))

            views.setTextViewText(R.id.widget_label_ounce, ounceLabel(isAr))
            views.setTextViewText(
                R.id.widget_value_ounce,
                formatValue(priceOunce, "$", priceFormatter)
            )

            // Mirror layout for Arabic so labels sit on the right and prices
            // on the left, matching native RTL reading flow.
            views.setInt(
                R.id.widget_root,
                "setLayoutDirection",
                if (isAr) LayoutDirection.RTL else LayoutDirection.LTR
            )

            // Tap-to-open: route the entire widget to MainActivity.
            views.setOnClickPendingIntent(R.id.widget_root, buildLaunchIntent(context))

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    // home_widget stores Flutter `double` values as Long bits in some versions
    // and as Float in others. Try both shapes so the widget never silently
    // shows "—" when data actually exists.
    private fun readDouble(prefs: SharedPreferences, key: String): Double? {
        if (!prefs.contains(key)) return null
        val raw = prefs.all[key]
        return when (raw) {
            is Double -> raw
            is Float -> raw.toDouble()
            is Long -> Double.fromBits(raw)
            is Int -> raw.toDouble()
            is String -> raw.toDoubleOrNull()
            else -> null
        }
    }

    private fun karatLabel(karat: Int, isAr: Boolean): String =
        if (isAr) "عيار $karat" else "${karat}K"

    private fun ounceLabel(isAr: Boolean): String =
        if (isAr) "الأونصه" else "Ounce"

    private fun formatValue(
        value: Double?,
        prefix: String,
        formatter: NumberFormat
    ): String {
        if (value == null) return "—"
        return prefix + formatter.format(value.toLong())
    }

    private fun formatTimeShort(iso: String): String? {
        // Try the with-fractional-seconds shape first, then plain ISO 8601.
        val parsers = listOf("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", "yyyy-MM-dd'T'HH:mm:ssXXX")
        var date: Date? = null
        for (pattern in parsers) {
            try {
                val sdf = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                date = sdf.parse(iso)
                if (date != null) break
            } catch (_: Exception) {
                // Try next pattern.
            }
        }
        val parsed = date ?: return null
        return try {
            SimpleDateFormat("HH:mm", Locale.US).format(parsed)
        } catch (_: Exception) {
            null
        }
    }

    private fun buildLaunchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        // PendingIntent.FLAG_IMMUTABLE is required on Android 12 (API 31)+ and
        // safe everywhere else.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(context, 0, intent, flags)
    }
}
