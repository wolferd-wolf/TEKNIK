package com.akila.claudepocket

import android.content.Context
import java.io.File

class ClaudeProcess(private val context: Context) {

    private val sendLock = Any()
    private var hasSentMessage = false
    private var activeProcess: Process? = null

    fun send(text: String, onOutputLine: (String) -> Unit) {
        Thread {
            synchronized(sendLock) {
                try {
                    val bootstrap = RuntimeBootstrap(context)
                    val loaderPath =
                        File(context.filesDir, "runtime/lib/ld-musl-aarch64.so.1").absolutePath
                    val claudePath = File(context.filesDir, "runtime/claude").absolutePath
                    val workDir = File(bootstrap.workspacePath())

                    val command = mutableListOf(loaderPath, claudePath, "-p")
                    if (hasSentMessage) command += "-c"
                    command += text

                    val processBuilder = ProcessBuilder(command)
                        .directory(workDir)
                        .redirectErrorStream(true)

                    val environment = processBuilder.environment()
                    environment.remove("LD_PRELOAD")
                    environment["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
                    val baseUrl = SettingsActivity.getBaseUrl(context)
                    if (baseUrl.isNotBlank()) {
                        environment["ANTHROPIC_BASE_URL"] = baseUrl
                    } else {
                        environment.remove("ANTHROPIC_BASE_URL")
                    }

                    val process = processBuilder.start()
                    activeProcess = process
                    val exitCode = process.waitFor()
                    val output = process.inputStream.bufferedReader().use { it.readText() }
                    activeProcess = null

                    if (output.isNotBlank()) {
                        onOutputLine(output.trimEnd())
                    }
                    if (exitCode == 0) {
                        hasSentMessage = true
                    } else {
                        onOutputLine("Claude process failed with exit code $exitCode.")
                    }
                } catch (error: Throwable) {
                    activeProcess = null
                    onOutputLine("Claude process error:\n${error.stackTraceToString()}")
                }
            }
        }.start()
    }

    fun stop() {
        synchronized(sendLock) {
            activeProcess?.destroy()
            activeProcess = null
        }
    }
}
