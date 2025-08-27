package com.z9turbo

import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

data class AppUsage(
    val packageName: String,
    val appName: String,
    val fgMinutes: Long,
    val launchCount: Int
)

object UsageRepo {
    fun loadTopApps(context: Context, hoursBack: Int = 24, limit: Int = 30): List<AppUsage> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - hoursBack * 60L * 60L * 1000L

        val stats: List<UsageStats> = try {
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
        } catch (_: SecurityException) {
            emptyList()
        } ?: emptyList()

        val pm: PackageManager = context.packageManager

        // Also estimate launch counts using UsageEvents (best-effort)
        val launchCounts = mutableMapOf<String, Int>()
        try {
            val events = usm.queryEvents(start, end)
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == UsageEvents.Event.ACTIVITY_PAUSED) {
                    val pkg = event.packageName ?: continue
                    launchCounts[pkg] = (launchCounts[pkg] ?: 0) + 1
                }
            }
        } catch (_: SecurityException) {}

        val list = stats
            .filter { it.totalTimeInForeground > 0 }
            .map {
                val pkg = it.packageName
                val appName = appName(pm, pkg)
                val minutes = it.totalTimeInForeground / 60000L
                val launches = launchCounts[pkg] ?: 0
                AppUsage(pkg, appName, minutes, launches)
            }
            .sortedByDescending { it.fgMinutes }
            .take(limit)

        return list
    }

    private fun appName(pm: PackageManager, packageName: String): String {
        return try {
            val ai: ApplicationInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(ai)?.toString() ?: packageName
        } catch (e: Exception) {
            packageName
        }
    }
}