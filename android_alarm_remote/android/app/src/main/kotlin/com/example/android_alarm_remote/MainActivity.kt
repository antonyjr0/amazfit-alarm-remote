package com.example.android_alarm_remote

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.AlarmClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var foreground = false
    override fun onResume() { super.onResume(); foreground = true }
    override fun onPause() { foreground = false; super.onPause() }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        AlarmRepository.initialize(applicationContext)
        EventChannel(engine.dartExecutor.binaryMessenger, "alarm_remote/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                AlarmRepository.changed = { runOnUiThread { sink.success(snapshot()) } }
                sink.success(snapshot())
            }
            override fun onCancel(arguments: Any?) { AlarmRepository.changed = null }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger, "alarm_remote/native").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "snapshot" -> result.success(snapshot())
                    "apps" -> result.success(clockApps())
                    "select" -> {
                        val selected = call.argument<String>("package")
                        require(clockApps().any { it["package"] == selected })
                        AlarmRepository.select(selected!!)
                        AlarmListener.instance?.reconcile()
                        result.success(null)
                    }
                    "clearLogs" -> { AlarmRepository.clearLogs(); result.success(null) }
                    "settings" -> {
                        val intent = if (call.argument<String>("target") == "notifications")
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        startActivity(intent); result.success(null)
                    }
                    "command" -> result.success(control(call.argument<String>("command"), call.argument<String>("alarmId")))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("FAILED", "Operazione Android non disponibile", null) }
        }
    }
    private fun snapshot(): Map<String, Any> {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        val component = ComponentName(this, AlarmListener::class.java)
        val permission = enabled.split(':').any { ComponentName.unflattenFromString(it) == component }
        return AlarmRepository.snapshot(permission)
    }
    @Suppress("DEPRECATION")
    private fun clockApps(): List<Map<String, String>> = listOf(AlarmClock.ACTION_SHOW_ALARMS, AlarmClock.ACTION_DISMISS_ALARM, AlarmClock.ACTION_SNOOZE_ALARM)
        .flatMap { packageManager.queryIntentActivities(Intent(it), 0) }
        .filter { it.activityInfo.exported }
        .distinctBy { it.activityInfo.packageName }
        .map { mapOf("package" to it.activityInfo.packageName, "label" to it.loadLabel(packageManager).toString()) }
        .sortedBy { it["label"] }

    private fun control(command: String?, id: String?): String {
        if (command !in listOf("DISMISS", "SNOOZE")) return "UNSUPPORTED"
        // Local commands require a visible Activity and explicit user confirmation.
        if (!foreground || !AlarmRepository.connected) return AlarmRepository.outcome("FAILED", "Listener o schermata non attivi")
        val listener = AlarmListener.instance ?: return AlarmRepository.outcome("FAILED", "Listener assente")
        listener.reconcile()
        if (!AlarmRepository.canControl(id)) return AlarmRepository.outcome("FAILED", "Occorrenza terminata, ambigua o già utilizzata")
        val intent = Intent(if (command == "DISMISS") AlarmClock.ACTION_DISMISS_ALARM else AlarmClock.ACTION_SNOOZE_ALARM)
            .setPackage(AlarmRepository.selected)
        if (Build.VERSION.SDK_INT < 23 || intent.resolveActivity(packageManager) == null)
            return AlarmRepository.outcome("UNSUPPORTED", "Intent non gestito dall’app selezionata")
        // Consume before launching; uncertain outcomes must never be retried automatically.
        AlarmRepository.consume(id!!)
        return try {
            startActivity(intent)
            AlarmRepository.outcome("UNVERIFIED", "$command inviato; nessuna conferma autorevole di esecuzione")
        } catch (_: Exception) { AlarmRepository.outcome("FAILED", "Avvio Intent rifiutato") }
    }
}
