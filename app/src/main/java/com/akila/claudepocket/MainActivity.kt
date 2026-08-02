package com.akila.claudepocket

import android.graphics.Typeface
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.GravityCompat
import com.akila.claudepocket.databinding.ActivityMainBinding
import java.io.File
import java.text.DateFormat
import java.util.Date

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var claudeProcess: ClaudeProcess
    private lateinit var profileSettingsController:
        ProfileSettingsController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                File(filesDir, CRASH_FILE_NAME).writeText(throwable.stackTraceToString())
            } catch (_: Exception) {
                // The process is already crashing; preserve the original failure path.
            } finally {
                if (previousHandler != null) {
                    previousHandler.uncaughtException(thread, throwable)
                } else {
                    android.os.Process.killProcess(android.os.Process.myPid())
                }
            }
        }

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val crashFile = File(filesDir, CRASH_FILE_NAME)
        if (crashFile.isFile) {
            val crashText = runCatching { crashFile.readText() }
                .getOrElse { "Could not read saved crash report: ${it.stackTraceToString()}" }
            appendOutput("Previous crash report:")
            appendOutput(crashText)
            crashFile.delete()
        }

        claudeProcess = ClaudeProcess(
            context = this,
            onAssistantText = { text ->
                runOnUiThread {
                    appendOutput(text)
                }
            },
            onResult = { isError, result ->
                runOnUiThread {
                    if (isError) {
                        appendOutput(
                            result.ifBlank { "Claude request failed." }
                        )
                    } else {
                        appendOutput("Done.")
                    }
                }
            },
            onStatus = { status ->
                runOnUiThread {
                    appendOutput(status)
                }
            },
            onError = { error ->
                runOnUiThread {
                    appendOutput(error)
                }
            }
        )

        profileSettingsController = ProfileSettingsController(
            activity = this,
            profilesContainer = binding.profilesContainer,
            addProfileButton = binding.addProfileButton
        )

        val bootstrap = RuntimeBootstrap(this)

        refreshStatus(bootstrap)

        binding.setupButton.setOnClickListener {
            binding.statusText.text = "Setting up..."
            bootstrap.install(
                onProgress = { msg ->
                    runOnUiThread {
                        if (
                            msg == "Runtime file diagnostic:" ||
                            msg.startsWith("runtime/") ||
                            msg.startsWith("Runtime diagnostic total:")
                        ) {
                            appendOutput(msg)
                        } else {
                            binding.statusText.text = msg
                        }
                    }
                },
                onDone = { _, msg ->
                    runOnUiThread {
                        binding.statusText.text = msg
                    }
                }
            )
        }

        binding.settingsDrawerButton.setOnClickListener {
            profileSettingsController.renderProfiles()
            binding.drawerLayout.openDrawer(GravityCompat.START)
        }

        binding.sessionsDrawerButton.setOnClickListener {
            renderSessions()
            binding.drawerLayout.openDrawer(GravityCompat.END)
        }

        binding.sendButton.setOnClickListener {
            val text = binding.inputField.text.toString()
            if (text.isNotBlank()) {
                appendOutput("> $text")
                appendOutput("Running...")
                claudeProcess.send(text)
                binding.inputField.setText("")
            }
        }
    }

    override fun onDestroy() {
        claudeProcess.stop()
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        refreshStatus(RuntimeBootstrap(this))
    }

    private fun refreshStatus(bootstrap: RuntimeBootstrap) {
        binding.statusText.text = if (bootstrap.isInstalled())
            "Ready. Workspace: ${bootstrap.workspacePath()}"
        else
            "Not set up yet. Tap Setup."
    }

    private fun renderSessions() {
        val sessions = SessionStore.getSessions(this)
        binding.sessionsContainer.removeAllViews()

        if (sessions.isEmpty()) {
            binding.sessionsContainer.addView(
                TextView(this).apply {
                    text = "No saved sessions yet."
                    textSize = 14f
                    setPadding(0, 8.dp, 0, 8.dp)
                }
            )
            return
        }

        sessions.forEachIndexed { index, session ->
            binding.sessionsContainer.addView(
                createSessionView(session)
            )

            if (index != sessions.lastIndex) {
                binding.sessionsContainer.addView(
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

    private fun createSessionView(
        session: ClaudeSession
    ): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(12.dp, 10.dp, 12.dp, 10.dp)
            isClickable = true
            isFocusable = true
            setOnClickListener {
                binding.drawerLayout.closeDrawer(GravityCompat.END)
                binding.outputText.text = ""
                appendOutput("Resuming session: ${session.label}")
                claudeProcess.resumeSession(session.sessionId)
            }
        }

        container.addView(
            TextView(this).apply {
                text = session.label
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
            }
        )

        container.addView(
            TextView(this).apply {
                text = DateFormat.getDateTimeInstance(
                    DateFormat.MEDIUM,
                    DateFormat.SHORT
                ).format(Date(session.timestamp))
                textSize = 13f
                setPadding(0, 4.dp, 0, 0)
            }
        )

        container.addView(
            TextView(this).apply {
                text = session.sessionId
                textSize = 11f
                setPadding(0, 2.dp, 0, 0)
            }
        )

        return container
    }

    private fun appendOutput(line: String) {
        binding.outputText.append(line + "\n")
    }

    private val Int.dp: Int
        get() = (
            this * resources.displayMetrics.density
        ).toInt()

    companion object {
        private const val CRASH_FILE_NAME = "crash.txt"
    }
}
