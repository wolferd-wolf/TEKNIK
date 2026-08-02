package com.akila.claudepocket

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class ClaudeProfile(
    val id: String,
    val name: String,
    val baseUrl: String,
    val apiKey: String,
    val authToken: String,
    val model: String
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("name", name)
        .put("baseUrl", baseUrl)
        .put("apiKey", apiKey)
        .put("authToken", authToken)
        .put("model", model)

    companion object {
        const val DEFAULT_MODEL = "openrouter/free"

        fun fromJson(json: JSONObject): ClaudeProfile = ClaudeProfile(
            id = json.optString("id")
                .ifBlank { UUID.randomUUID().toString() },
            name = json.optString("name", "Unnamed"),
            baseUrl = json.optString("baseUrl"),
            apiKey = json.optString("apiKey"),
            authToken = json.optString("authToken"),
            model = json.optString("model", DEFAULT_MODEL)
                .ifBlank { DEFAULT_MODEL }
        )
    }
}

object ProfileStore {
    private const val PREFS_NAME = "claude_pocket_prefs"
    private const val KEY_PROFILES_JSON = "profiles_json"
    private const val KEY_ACTIVE_PROFILE_ID = "active_profile_id"

    private const val LEGACY_API_KEY = "api_key"
    private const val LEGACY_AUTH_TOKEN = "auth_token"
    private const val LEGACY_BASE_URL = "base_url"
    private const val LEGACY_SELECTED_MODEL = "selected_model"

    private val lock = Any()

    fun getProfiles(context: Context): List<ClaudeProfile> =
        synchronized(lock) {
            loadOrInitialize(context).first
        }

    fun getActiveProfileId(context: Context): String =
        synchronized(lock) {
            loadOrInitialize(context).second
        }

    fun getActiveProfile(context: Context): ClaudeProfile =
        synchronized(lock) {
            val (profiles, activeId) = loadOrInitialize(context)
            profiles.firstOrNull { it.id == activeId } ?: profiles.first()
        }

    fun saveProfile(
        context: Context,
        profile: ClaudeProfile
    ) = synchronized(lock) {
        val (currentProfiles, activeId) = loadOrInitialize(context)
        val profiles = currentProfiles.toMutableList()
        val index = profiles.indexOfFirst { it.id == profile.id }

        if (index >= 0) {
            profiles[index] = profile
        } else {
            profiles += profile
        }

        persist(context, profiles, activeId)
    }

    fun setActiveProfile(
        context: Context,
        profileId: String
    ): Boolean = synchronized(lock) {
        val (profiles, activeId) = loadOrInitialize(context)
        if (profiles.none { it.id == profileId }) {
            false
        } else {
            persist(context, profiles, profileId)
            activeId != profileId
        }
    }

    fun deleteProfile(
        context: Context,
        profileId: String
    ): Boolean = synchronized(lock) {
        val (profiles, activeId) = loadOrInitialize(context)
        if (profiles.size <= 1) {
            return@synchronized false
        }

        val remaining = profiles.filterNot { it.id == profileId }
        if (remaining.size == profiles.size) {
            return@synchronized false
        }

        val nextActiveId = if (activeId == profileId) {
            remaining.first().id
        } else {
            activeId
        }

        persist(context, remaining, nextActiveId)
        true
    }

    fun getNextUntriedProfile(
        context: Context,
        currentProfileId: String,
        triedProfileIds: Set<String>
    ): ClaudeProfile? = synchronized(lock) {
        val profiles = loadOrInitialize(context).first
        val currentIndex =
            profiles.indexOfFirst { it.id == currentProfileId }

        for (offset in 1..profiles.size) {
            val index = if (currentIndex >= 0) {
                (currentIndex + offset) % profiles.size
            } else {
                offset - 1
            }

            val candidate = profiles[index]
            if (candidate.id !in triedProfileIds) {
                return@synchronized candidate
            }
        }

        null
    }

    private fun loadOrInitialize(
        context: Context
    ): Pair<List<ClaudeProfile>, String> {
        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val storedJson = prefs.getString(KEY_PROFILES_JSON, null)

        if (storedJson != null) {
            val profiles = parseProfiles(storedJson)
            if (profiles.isNotEmpty()) {
                val storedActiveId =
                    prefs.getString(KEY_ACTIVE_PROFILE_ID, null)
                val activeId = storedActiveId
                    ?.takeIf { id -> profiles.any { it.id == id } }
                    ?: profiles.first().id

                if (activeId != storedActiveId) {
                    prefs.edit()
                        .putString(KEY_ACTIVE_PROFILE_ID, activeId)
                        .apply()
                }

                return profiles to activeId
            }
        }

        val legacyProfile = legacyProfile(prefs)
        val templates = defaultTemplates()
        val profiles = if (legacyProfile != null) {
            listOf(legacyProfile) + templates
        } else {
            templates
        }
        val activeId = legacyProfile?.id ?: profiles.first().id

        persist(context, profiles, activeId)
        return profiles to activeId
    }

    private fun legacyProfile(
        prefs: SharedPreferences
    ): ClaudeProfile? {
        val apiKey =
            prefs.getString(LEGACY_API_KEY, "").orEmpty().trim()
        val authToken =
            prefs.getString(LEGACY_AUTH_TOKEN, "").orEmpty().trim()
        val baseUrl =
            prefs.getString(LEGACY_BASE_URL, "").orEmpty().trim()
        val model = prefs.getString(
            LEGACY_SELECTED_MODEL,
            ClaudeProfile.DEFAULT_MODEL
        ).orEmpty()
            .trim()
            .ifBlank { ClaudeProfile.DEFAULT_MODEL }

        if (
            apiKey.isBlank() &&
            authToken.isBlank() &&
            baseUrl.isBlank() &&
            !prefs.contains(LEGACY_SELECTED_MODEL)
        ) {
            return null
        }

        return ClaudeProfile(
            id = UUID.randomUUID().toString(),
            name = "Default",
            baseUrl = baseUrl,
            apiKey = apiKey,
            authToken = authToken,
            model = model
        )
    }

    private fun defaultTemplates(): List<ClaudeProfile> = listOf(
        ClaudeProfile(
            id = UUID.randomUUID().toString(),
            name = "OpenRouter",
            baseUrl = "https://openrouter.ai/api",
            apiKey = "",
            authToken = "",
            model = "openrouter/free"
        ),
        ClaudeProfile(
            id = UUID.randomUUID().toString(),
            name = "DeepSeek",
            baseUrl = "https://api.deepseek.com/anthropic",
            apiKey = "",
            authToken = "",
            model = "deepseek-v4-flash"
        )
    )

    private fun parseProfiles(
        serialized: String
    ): List<ClaudeProfile> = runCatching {
        val array = JSONArray(serialized)
        val profiles = mutableListOf<ClaudeProfile>()

        for (index in 0 until array.length()) {
            val json = array.optJSONObject(index) ?: continue
            profiles += ClaudeProfile.fromJson(json)
        }

        profiles
    }.getOrDefault(emptyList())

    private fun persist(
        context: Context,
        profiles: List<ClaudeProfile>,
        activeId: String
    ) {
        val array = JSONArray()
        profiles.forEach { array.put(it.toJson()) }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PROFILES_JSON, array.toString())
            .putString(KEY_ACTIVE_PROFILE_ID, activeId)
            .apply()
    }
}
