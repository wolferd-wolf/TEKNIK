package com.akila.claudepocket

import android.graphics.Typeface
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.akila.claudepocket.databinding.ActivitySettingsBinding
import java.util.UUID

class SettingsActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySettingsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.addProfileButton.setOnClickListener {
            showProfileEditor(null)
        }

        renderProfiles()
    }

    private fun renderProfiles() {
        val profiles = ProfileStore.getProfiles(this)
        val activeId = ProfileStore.getActiveProfileId(this)

        binding.profilesContainer.removeAllViews()
        profiles.forEachIndexed { index, profile ->
            binding.profilesContainer.addView(
                createProfileView(profile, profile.id == activeId)
            )

            if (index != profiles.lastIndex) {
                binding.profilesContainer.addView(
                    View(this).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            1.dp
                        ).apply {
                            topMargin = 8.dp
                            bottomMargin = 8.dp
                        }
                        setBackgroundColor(0x33000000)
                    }
                )
            }
        }
    }

    private fun createProfileView(
        profile: ClaudeProfile,
        isActive: Boolean
    ): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(12.dp, 8.dp, 12.dp, 8.dp)
            isClickable = true
            isFocusable = true
            setOnClickListener { showProfileEditor(profile) }
        }

        container.addView(
            TextView(this).apply {
                text = if (isActive) {
                    "${profile.name} (active)"
                } else {
                    profile.name
                }
                setTypeface(typeface, Typeface.BOLD)
                textSize = 17f
            }
        )

        container.addView(
            TextView(this).apply {
                text = profileSummary(profile)
                setPadding(0, 4.dp, 0, 8.dp)
            }
        )

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        actions.addView(
            Button(this).apply {
                text = if (isActive) "Active" else "Use"
                isEnabled = !isActive
                setOnClickListener {
                    ProfileStore.setActiveProfile(
                        this@SettingsActivity,
                        profile.id
                    )
                    renderProfiles()
                }
            }
        )

        actions.addView(
            Button(this).apply {
                text = "Edit"
                setOnClickListener { showProfileEditor(profile) }
            }
        )

        actions.addView(
            Button(this).apply {
                text = "Delete"
                setOnClickListener { confirmDelete(profile) }
            }
        )

        container.addView(actions)
        return container
    }

    private fun profileSummary(profile: ClaudeProfile): String {
        val credentialSummary = when {
            profile.authToken.isNotBlank() -> "Auth token set"
            profile.apiKey.isNotBlank() -> "API key set"
            else -> "No credential set"
        }
        val baseUrl =
            profile.baseUrl.ifBlank { "Default Anthropic base URL" }
        val model =
            profile.model.ifBlank { ClaudeProfile.DEFAULT_MODEL }

        return "$baseUrl\n$credentialSummary\nModel: $model"
    }

    private fun showProfileEditor(existing: ClaudeProfile?) {
        val nameField = profileField("Profile name")
        val baseUrlField = profileField(
            "Base URL (blank for Anthropic default)",
            InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_VARIATION_URI
        )
        val apiKeyField = profileField(
            "API key",
            InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_VARIATION_PASSWORD
        )
        val authTokenField = profileField(
            "Auth token",
            InputType.TYPE_CLASS_TEXT or
                InputType.TYPE_TEXT_VARIATION_PASSWORD
        )
        val modelField = profileField("Model ID")

        if (existing != null) {
            nameField.setText(existing.name)
            baseUrlField.setText(existing.baseUrl)
            apiKeyField.setText(existing.apiKey)
            authTokenField.setText(existing.authToken)
            modelField.setText(existing.model)
        } else {
            modelField.setText(ClaudeProfile.DEFAULT_MODEL)
        }

        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20.dp, 8.dp, 20.dp, 8.dp)
            addView(nameField)
            addView(baseUrlField)
            addView(apiKeyField)
            addView(authTokenField)
            addView(modelField)
        }

        val scrollView = ScrollView(this).apply {
            addView(form)
        }

        val dialog = AlertDialog.Builder(this)
            .setTitle(
                if (existing == null) {
                    "Add profile"
                } else {
                    "Edit profile"
                }
            )
            .setView(scrollView)
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Save", null)
            .create()

        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener {
                    val name = nameField.text.toString().trim()
                    val baseUrl =
                        baseUrlField.text.toString().trim()
                    val apiKey =
                        apiKeyField.text.toString().trim()
                    val authToken =
                        authTokenField.text.toString().trim()
                    val model =
                        modelField.text.toString().trim()

                    when {
                        name.isBlank() -> {
                            Toast.makeText(
                                this,
                                "Profile name is required.",
                                Toast.LENGTH_SHORT
                            ).show()
                        }

                        apiKey.isNotBlank() &&
                            authToken.isNotBlank() -> {
                            Toast.makeText(
                                this,
                                "Use either an API key or an auth token, not both.",
                                Toast.LENGTH_LONG
                            ).show()
                        }

                        model.isBlank() -> {
                            Toast.makeText(
                                this,
                                "Model ID is required.",
                                Toast.LENGTH_SHORT
                            ).show()
                        }

                        else -> {
                            ProfileStore.saveProfile(
                                this,
                                ClaudeProfile(
                                    id = existing?.id
                                        ?: UUID.randomUUID().toString(),
                                    name = name,
                                    baseUrl = baseUrl,
                                    apiKey = apiKey,
                                    authToken = authToken,
                                    model = model
                                )
                            )
                            renderProfiles()
                            dialog.dismiss()
                        }
                    }
                }
        }

        dialog.show()
    }

    private fun confirmDelete(profile: ClaudeProfile) {
        if (ProfileStore.getProfiles(this).size <= 1) {
            Toast.makeText(
                this,
                "At least one profile is required.",
                Toast.LENGTH_SHORT
            ).show()
            return
        }

        AlertDialog.Builder(this)
            .setTitle("Delete ${profile.name}?")
            .setMessage(
                "This removes the profile and its saved credentials."
            )
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Delete") { _, _ ->
                ProfileStore.deleteProfile(this, profile.id)
                renderProfiles()
            }
            .show()
    }

    private fun profileField(
        hintText: String,
        type: Int = InputType.TYPE_CLASS_TEXT
    ) = EditText(this).apply {
        hint = hintText
        inputType = type
        isSingleLine = true
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = 8.dp
        }
    }

    private val Int.dp: Int
        get() = (this * resources.displayMetrics.density).toInt()
}
