package com.breathesafe.breathe_safe

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BreathSafeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val enabled = context.getSharedPreferences(
            BreathSafeBleService.PREFS_NAME,
            Context.MODE_PRIVATE,
        ).getBoolean(BreathSafeBleService.PREF_ENABLED, true)

        if (!enabled) return

        val serviceIntent = Intent(context, BreathSafeBleService::class.java)
            .setAction(BreathSafeBleService.ACTION_START)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
