package com.example.android_alarm_remote

/** Category, ongoing and fullscreen are evidence only; none proves Xiaomi is ringing. */
object AlarmEvidence {
    fun candidate(category: String?, groupSummary: Boolean): Boolean = category == "alarm" && !groupSummary
    fun describe(ongoing: Boolean, fullscreen: Boolean, actions: Int): String =
        "category=alarm; ongoing=$ongoing; fullscreen=$fullscreen; actions=$actions; suoneria non confermata"
}
