package com.example.android_alarm_remote

import java.util.UUID

/** In-memory evidence, never authoritative ringing state or a remote command ledger. */
class OccurrenceStore(private val newId: () -> String = { "phone-${UUID.randomUUID()}" }) {
    data class Occurrence(val id: String, var evidence: String, var state: String = "UNKNOWN", var consumed: Boolean = false)
    private val current = linkedMapOf<String, Occurrence>()
    private val history = ArrayDeque<Occurrence>()
    fun clear() { current.clear(); history.clear() }
    fun observe(key: String, evidence: String): Boolean {
        current[key]?.let { it.evidence = evidence; return false }
        if (current.size >= 32) return false
        current[key] = Occurrence(newId(), evidence)
        return true
    }
    fun remove(key: String): Boolean {
        val old = current.remove(key) ?: return false
        old.state = "UNKNOWN_REMOVED"
        history.addLast(old)
        while (history.size > 16) history.removeFirst()
        return true
    }
    fun retain(keys: Set<String>): Int = current.keys.toList().count { it !in keys && remove(it) }
    fun canControl(id: String?): Boolean = current.size == 1 && current.values.any { it.id == id && !it.consumed }
    fun consume(id: String) { current.values.firstOrNull { it.id == id }?.consumed = true }
    fun snapshot(): List<Map<String, Any>> = (current.values + history).map {
        mapOf("id" to it.id, "state" to it.state, "evidence" to it.evidence, "consumed" to it.consumed)
    }
}
