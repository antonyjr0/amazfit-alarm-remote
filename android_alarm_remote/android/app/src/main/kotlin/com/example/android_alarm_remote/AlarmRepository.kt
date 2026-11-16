package com.example.android_alarm_remote

import android.content.Context
import android.content.SharedPreferences

object AlarmRepository {
    private lateinit var preferences: SharedPreferences
    var selected = ""
        private set
    var connected = false
        private set
    var changed: (() -> Unit)? = null
    private val occurrences = OccurrenceStore()
    private val logs = ArrayDeque<Map<String, Any>>()
    private var lastCommand = "Nessuno"
    fun initialize(context: Context) {
        if (::preferences.isInitialized) return
        preferences = context.getSharedPreferences("alarm_remote", Context.MODE_PRIVATE)
        selected = preferences.getString("clockPackage", "") ?: ""
    }
    fun select(value: String) {
        selected = value
        preferences.edit().putString("clockPackage", value).apply()
        occurrences.clear()
        log("Pacchetto Orologio selezionato; stato invalidato")
    }
    fun connection(value: Boolean) {
        connected = value
        if (!value) occurrences.clear()
        log(if(value) "Listener connesso; riconciliazione" else "Listener disconnesso; stato invalidato")
    }
    fun observe(key: String, evidence: String) {
        if (occurrences.observe(key, evidence)) {
            log("Notifica candidata UNKNOWN; non equivale a RINGING")
        } else changed?.invoke()
    }
    fun retain(keys: Set<String>) {
        if (occurrences.retain(keys) > 0) log("Snapshot riconciliato; notifiche rimosse senza conferma di cessazione")
    }
    fun remove(key: String) {
        if (!occurrences.remove(key)) return
        log("Notifica rimossa; suoneria e risultato del comando non verificabili")
    }
    fun canControl(id: String?): Boolean = connected && occurrences.canControl(id)
    fun consume(id: String) { occurrences.consume(id) }
    fun outcome(status: String, reason: String): String {
        lastCommand = "$status · $reason"
        log(lastCommand)
        return lastCommand
    }
    fun log(event: String) {
        logs.addLast(mapOf("time" to System.currentTimeMillis(), "event" to event))
        while(logs.size > 100) logs.removeFirst()
        changed?.invoke()
    }
    fun clearLogs() { logs.clear(); changed?.invoke() }
    fun snapshot(permission: Boolean): Map<String, Any> = mapOf(
        "permission" to permission, "connected" to (permission && connected),
        "package" to selected, "lastCommand" to lastCommand,
        "alarms" to occurrences.snapshot(),
        "logs" to logs.toList())
}
