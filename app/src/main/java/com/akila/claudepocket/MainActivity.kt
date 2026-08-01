package com.akila.claudepocket

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.akila.claudepocket.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var claudeProcess: ClaudeProcess

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        claudeProcess = ClaudeProcess(this)
        val bootstrap = RuntimeBootstrap(this)

        refreshStatus(bootstrap)

        binding.setupButton.setOnClickListener {
            binding.statusText.text = "Setting up..."
            bootstrap.install(
                onProgress = { msg -> runOnUiThread { binding.statusText.text = msg } },
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
}
