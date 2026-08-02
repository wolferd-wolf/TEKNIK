package com.akila.claudepocket

import android.content.Context
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.doAfterTextChanged
import com.akila.claudepocket.databinding.ActivitySettingsBinding

/**
 * Stores authentication, endpoint, and model settings in this app's own
 * SharedPreferences file. Never written outside app-private storage.
 */
class SettingsActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySettingsBinding

    companion object {
        const val PREFS_NAME = "claude_pocket_prefs"
        const val KEY_API_KEY = "api_key"
        const val KEY_AUTH_TOKEN = "auth_token"
        const val KEY_BASE_URL = "base_url"
        const val KEY_SELECTED_MODEL = "selected_model"

        const val DEFAULT_MODEL = "openrouter/free"
        private const val QWEN_MODEL = "qwen/qwen3-coder:free"
        private const val DEEPSEEK_MODEL = "deepseek/deepseek-v4-flash:free"
        private const val GLM_MODEL = "z-ai/glm-4.5-air:free"

        fun getApiKey(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(KEY_API_KEY, "") ?: ""

        fun getAuthToken(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .getString(KEY_AUTH_TOKEN, "") ?: ""

        fun getBaseUrl(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(KEY_BASE_URL, "") ?: ""

        fun getSelectedModel(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .getString(KEY_SELECTED_MODEL, DEFAULT_MODEL)
                ?.trim()
                .orEmpty()
                .ifBlank { DEFAULT_MODEL }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        binding.apiKeyField.setText(prefs.getString(KEY_API_KEY, ""))
        binding.authTokenField.setText(prefs.getString(KEY_AUTH_TOKEN, ""))
        binding.baseUrlField.setText(prefs.getString(KEY_BASE_URL, ""))

        when (val selectedModel = getSelectedModel(this)) {
            QWEN_MODEL -> binding.modelQwenButton.isChecked = true
            DEEPSEEK_MODEL -> binding.modelDeepSeekButton.isChecked = true
            GLM_MODEL -> binding.modelGlmButton.isChecked = true
            DEFAULT_MODEL -> binding.modelAutoRouterButton.isChecked = true
            else -> {
                binding.modelRadioGroup.clearCheck()
                binding.customModelField.setText(selectedModel)
            }
        }

        binding.modelRadioGroup.setOnCheckedChangeListener { _, checkedId ->
            if (checkedId != -1 && binding.customModelField.text.isNotEmpty()) {
                binding.customModelField.text.clear()
            }
        }

        binding.customModelField.doAfterTextChanged { text ->
            if (
                !text.isNullOrBlank() &&
                binding.modelRadioGroup.checkedRadioButtonId != -1
            ) {
                binding.modelRadioGroup.clearCheck()
            }
        }

        binding.saveButton.setOnClickListener {
            val customModel = binding.customModelField.text.toString().trim()
            val selectedModel = if (customModel.isNotBlank()) {
                customModel
            } else {
                when (binding.modelRadioGroup.checkedRadioButtonId) {
                    R.id.modelQwenButton -> QWEN_MODEL
                    R.id.modelDeepSeekButton -> DEEPSEEK_MODEL
                    R.id.modelGlmButton -> GLM_MODEL
                    R.id.modelAutoRouterButton -> DEFAULT_MODEL
                    else -> DEFAULT_MODEL
                }
            }

            prefs.edit()
                .putString(KEY_API_KEY, binding.apiKeyField.text.toString().trim())
                .putString(KEY_AUTH_TOKEN, binding.authTokenField.text.toString().trim())
                .putString(KEY_BASE_URL, binding.baseUrlField.text.toString().trim())
                .putString(KEY_SELECTED_MODEL, selectedModel)
                .apply()
            finish()
        }
    }
}
