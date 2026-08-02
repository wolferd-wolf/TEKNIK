package com.akila.claudepocket

import android.content.Context
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.akila.claudepocket.databinding.ActivitySettingsBinding

/**
 * Stores ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, and ANTHROPIC_BASE_URL in
 * this app's own SharedPreferences file. Never written outside app-private storage.
 */
class SettingsActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySettingsBinding

    companion object {
        const val PREFS_NAME = "claude_pocket_prefs"
        const val KEY_API_KEY = "api_key"
        const val KEY_AUTH_TOKEN = "auth_token"
        const val KEY_BASE_URL = "base_url"

        fun getApiKey(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(KEY_API_KEY, "") ?: ""

        fun getAuthToken(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .getString(KEY_AUTH_TOKEN, "") ?: ""

        fun getBaseUrl(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(KEY_BASE_URL, "") ?: ""
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        binding.apiKeyField.setText(prefs.getString(KEY_API_KEY, ""))
        binding.authTokenField.setText(prefs.getString(KEY_AUTH_TOKEN, ""))
        binding.baseUrlField.setText(prefs.getString(KEY_BASE_URL, ""))

        binding.saveButton.setOnClickListener {
            prefs.edit()
                .putString(KEY_API_KEY, binding.apiKeyField.text.toString().trim())
                .putString(KEY_AUTH_TOKEN, binding.authTokenField.text.toString().trim())
                .putString(KEY_BASE_URL, binding.baseUrlField.text.toString().trim())
                .apply()
            finish()
        }
    }
}
