package com.example.android_alarm_remote

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class AlarmListener : NotificationListenerService() {
    companion object { var instance: AlarmListener? = null; private set }
    override fun onCreate() { super.onCreate(); AlarmRepository.initialize(applicationContext) }
    override fun onListenerConnected() {
        instance = this
        AlarmRepository.connection(true)
        reconcile()
    }
    override fun onListenerDisconnected() {
        instance = null
        AlarmRepository.connection(false)
    }
    override fun onDestroy() {
        if(instance === this) { instance = null; AlarmRepository.connection(false) }
        super.onDestroy()
    }
    private fun candidate(s: StatusBarNotification): Boolean = s.packageName == AlarmRepository.selected &&
        AlarmEvidence.candidate(s.notification.category, s.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0)
    private fun observe(s: StatusBarNotification) {
        val n = s.notification
        AlarmRepository.observe(s.key, AlarmEvidence.describe(s.isOngoing, n.fullScreenIntent != null, n.actions?.size ?: 0))
    }
    fun reconcile() {
        if(instance !== this) return
        try {
            val relevant = activeNotifications.filter { candidate(it) }
            AlarmRepository.retain(relevant.map { it.key }.toSet())
            relevant.forEach { observe(it) }
        } catch (_: SecurityException) { AlarmRepository.connection(false) }
    }
    override fun onNotificationPosted(s: StatusBarNotification) {
        // Never inspect extras, titles or action labels, especially from other packages.
        if(s.packageName != AlarmRepository.selected) return
        if(candidate(s)) observe(s) else AlarmRepository.remove(s.key)
    }
    override fun onNotificationRemoved(s: StatusBarNotification) {
        if(s.packageName == AlarmRepository.selected) AlarmRepository.remove(s.key)
    }
}
