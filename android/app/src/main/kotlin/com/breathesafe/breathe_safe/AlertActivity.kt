package com.breathesafe.breathe_safe

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlertActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(android.app.KeyguardManager::class.java)
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val title = intent.getStringExtra(BreathSafeBleService.EXTRA_ALERT_TITLE)
            ?: "BreatheSafe warning"
        val message = intent.getStringExtra(BreathSafeBleService.EXTRA_ALERT_MESSAGE)
            ?: "Air condition is not safe."
        val reading = intent.getStringExtra(BreathSafeBleService.EXTRA_READING_TEXT)
            ?: "Waiting for latest reading"
        val snoozeMinutes = getSharedPreferences(
            BreathSafeBleService.PREFS_NAME,
            MODE_PRIVATE,
        ).getInt(BreathSafeBleService.PREF_SNOOZE_MINUTES, 15)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(44, 44, 44, 44)
            setBackgroundColor(Color.rgb(15, 23, 42))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        root.addView(text(title, 26f, true))
        root.addView(text(message, 18f, false))
        root.addView(text(reading, 16f, false))

        val button = Button(this).apply {
            text = "OK - snooze $snoozeMinutes min"
            setOnClickListener {
                val intent = Intent(this@AlertActivity, BreathSafeBleService::class.java)
                    .setAction(BreathSafeBleService.ACTION_SNOOZE)
                startService(intent)
                finish()
            }
        }
        root.addView(button)

        setContentView(root)
    }

    private fun text(value: String, size: Float, bold: Boolean): TextView {
        return TextView(this).apply {
            text = value
            textSize = size
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
            if (bold) setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Ensure alarm stops instantly if user closes activity via back button or swipe
        val intent = Intent(this, BreathSafeBleService::class.java)
            .setAction(BreathSafeBleService.ACTION_SNOOZE)
        startService(intent)
    }
}
