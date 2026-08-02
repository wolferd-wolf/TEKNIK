package com.akila.claudepocket

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class ClaudeSession(
    val sessionId: String,
    val label: String,
    val timestamp: Long
) {
    fun toJson(): JSONObject = JSONObject()
        .put("sessionId", sessionId)
        .put("label", label)
        .put("timestamp", timestamp)

    companion object {
        fun fromJson(json: JSONObject): ClaudeSession? {
            val sessionId = json.optString("sessionId").trim()
            if (sessionId.isBlank()) return null

            return ClaudeSession(
                sessionId = sessionId,
                label = json.optString("label", sessionId),
                timestamp = json.optLong("timestamp", 0L)
            )
        }
    }
}

object SessionStore {
    private const val PREFS_NAME = "claude_pocket_prefs"
    private const val KEY_SESSIONS_JSON = "sessions_json"

    private val lock = Any()

    fun getSessions(context: Context): List<ClaudeSession> =
        synchronized(lock) {
            load(context).sortedByDescending { it.timestamp }
        }

    fun addIfMissing(
        context: Context,
        session: ClaudeSession
    ): Boolean = synchronized(lock) {
        val sessions = load(context)
        if (sessions.any { it.sessionId == session.sessionId }) {
            return@synchronized false
        }

        persist(context, sessions + session)
        true
    }

    private fun load(context: Context): List<ClaudeSession> {
        val serialized = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        ).getString(KEY_SESSIONS_JSON, null) ?: return emptyList()

        return runCatching {
            val array = JSONArray(serialized)
            val sessions = mutableListOf<ClaudeSession>()

            for (index in 0 until array.length()) {
                val json = array.optJSONObject(index) ?: continue
                ClaudeSession.fromJson(json)?.let(sessions::add)
            }

            sessions
        }.getOrDefault(emptyList())
    }

    private fun persist(
        context: Context,
        sessions: List<ClaudeSession>
    ) {
        val array = JSONArray()
        sessions.forEach { array.put(it.toJson()) }

        context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        ).edit()
            .putString(KEY_SESSIONS_JSON, array.toString())
            .apply()
    }
}
