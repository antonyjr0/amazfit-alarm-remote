package com.example.android_alarm_remote

import org.junit.Assert.*
import org.junit.Test

class AlarmEvidenceTest {
    @Test fun rejectsGenericClockNotificationsAndGroupSummaries() {
        assertFalse(AlarmEvidence.candidate(null, false))
        assertFalse(AlarmEvidence.candidate("reminder", false))
        assertFalse(AlarmEvidence.candidate("alarm", true))
        assertTrue(AlarmEvidence.candidate("alarm", false))
    }
    @Test fun evenStrongMetadataDoesNotConfirmRinging() {
        assertTrue(AlarmEvidence.describe(true, true, 2).contains("non confermata"))
    }
}
