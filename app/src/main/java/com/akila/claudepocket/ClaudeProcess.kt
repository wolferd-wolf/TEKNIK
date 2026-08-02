package com.akila.claudepocket

import android.content.Context
import java.io.File
import java.util.concurrent.TimeUnit

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
                    val homeDir = File(context.filesDir, "home").apply { mkdirs() }
                    environment["HOME"] = homeDir.absolutePath
                    environment["USER"] = "claude"
                    environment["LOGNAME"] = "claude"
                    environment["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
                    val baseUrl = SettingsActivity.getBaseUrl(context)
                    if (baseUrl.isNotBlank()) {
                        environment["ANTHROPIC_BASE_URL"] = baseUrl
                    } else {
                        environment.remove("ANTHROPIC_BASE_URL")
                    }

                    val process = processBuilder.start()
                    activeProcess = process
                    val finished = process.waitFor(PROCESS_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                    if (!finished) {
                        process.destroyForcibly()
                        process.waitFor()
                        activeProcess = null
                        onOutputLine("Timed out after ${PROCESS_TIMEOUT_SECONDS}s")
                        return@synchronized
                    }

                    val exitCode = process.exitValue()
                    val output = process.inputStream.bufferedReader().use { it.readText() }
                    val outputLength = output.toByteArray(Charsets.UTF_8).size
                    activeProcess = null

                    onOutputLine("Exit code: $exitCode, output length: $outputLength bytes")
                    if (output.isNotEmpty()) {
                        onOutputLine(output)
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

    companion object {
        private const val PROCESS_TIMEOUT_SECONDS = 30L
    }
}
