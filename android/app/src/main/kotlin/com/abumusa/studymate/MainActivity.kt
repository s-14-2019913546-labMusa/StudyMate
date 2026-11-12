package com.abumusa.studymate

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pomodoro ফোকাস চলার সময় স্ক্রিন জাগিয়ে রাখার জন্য
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "studymate/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // পড়ার সময় অন্য অ্যাপের নোটিফিকেশন নীরব (Do Not Disturb)।
        // ফোনের সেটিংসে ব্যবহারকারী নিজে অনুমতি দিলে তবেই কাজ করে।
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "studymate/dnd")
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "hasAccess" -> result.success(nm.isNotificationPolicyAccessGranted)
                    "openSettings" -> {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    "isOn" -> result.success(
                        nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
                    )
                    "set" -> {
                        if (!nm.isNotificationPolicyAccessGranted) {
                            result.success(false)
                        } else {
                            val on = call.argument<Boolean>("on") ?: false
                            nm.setInterruptionFilter(
                                if (on) NotificationManager.INTERRUPTION_FILTER_PRIORITY
                                else NotificationManager.INTERRUPTION_FILTER_ALL
                            )
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
