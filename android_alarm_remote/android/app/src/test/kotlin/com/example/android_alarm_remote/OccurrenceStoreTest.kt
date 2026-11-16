package com.example.android_alarm_remote

import org.junit.Assert.*
import org.junit.Test

class OccurrenceStoreTest {
    private var sequence = 0
    private fun store() = OccurrenceStore { "fake-${++sequence}" }
    @Test fun notificationUpdatePreservesIdentityAndConsumesAtMostOnce() {
        val s = store()
        assertTrue(s.observe("notification-key", "first"))
        val id = s.snapshot().single()["id"] as String
        assertFalse(s.observe("notification-key", "updated"))
        assertEquals(id, s.snapshot().single()["id"])
        assertEquals("updated", s.snapshot().single()["evidence"])
        assertTrue(s.canControl(id))
        s.consume(id)
        assertFalse(s.canControl(id))
        s.observe("notification-key", "another update")
        assertFalse(s.canControl(id))
    }
    @Test fun removalDoesNotProveExecutedAndNewRingGetsNewId() {
        val s = store(); s.observe("key", "candidate")
        val old = s.snapshot().single()["id"] as String
        assertTrue(s.remove("key")); assertFalse(s.remove("key"))
        assertFalse(s.canControl(old))
        assertEquals("UNKNOWN_REMOVED", s.snapshot().single()["state"])
        s.observe("key", "candidate")
        val fresh = s.snapshot().first()["id"] as String
        assertNotEquals(old, fresh); assertTrue(s.canControl(fresh))
    }
    @Test fun multipleNotificationsRejectAmbiguousCommandAndSnapshotRemovesStale() {
        val s = store(); s.observe("one", "candidate")
        val id = s.snapshot().single()["id"] as String
        s.observe("two", "candidate"); assertFalse(s.canControl(id))
        assertEquals(1, s.retain(setOf("one"))); assertTrue(s.canControl(id))
        assertFalse(s.canControl("obsolete"))
        s.clear(); assertFalse(s.canControl(id)); assertTrue(s.snapshot().isEmpty())
    }
    @Test fun memoryBoundsAndReconciliation() {
        val s = store()
        repeat(40) { s.observe("key-$it", "candidate") }
        assertEquals(32, s.snapshot().size)
        assertEquals(32, s.retain(emptySet()))
        assertEquals(16, s.snapshot().size)
        assertTrue(s.snapshot().all { it["state"] == "UNKNOWN_REMOVED" })
    }
}
