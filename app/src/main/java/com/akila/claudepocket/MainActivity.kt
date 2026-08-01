package com.akila.claudepocket

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.akila.claudepocket.databinding.ActivityMainBinding
import java.io.File

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var claudeProcess: ClaudeProcess

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

        claudeProcess = ClaudeProcess(this)
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
                onDone = { ok, msg ->
                    runOnUiThread {
                        binding.statusText.text = msg
                        if (ok) claudeProcess.start { line ->
                            runOnUiThread { appendOutput(line) }
                        }
                    }
                }
            )
        }

        binding.settingsButton.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }

        binding.sendButton.setOnClickListener {
            val text = binding.inputField.text.toString()
            if (text.isNotBlank()) {
                appendOutput("> $text")
                claudeProcess.send(text)
                binding.inputField.setText("")
            }
        }
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

    private fun appendOutput(line: String) {
        binding.outputText.append(line + "\n")
    }

    companion object {
        private const val CRASH_FILE_NAME = "crash.txt"
    }
}
