package com.akila.claudepocket

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File

class ClaudeProcess(
    private val context: Context,
    private val onAssistantText: (String) -> Unit,
    private val onResult: (isError: Boolean, result: String) -> Unit,
    private val onStatus: (String) -> Unit,
    private val onError: (String) -> Unit
) {

    private val processLock = Any()
    private val writeLock = Any()
    private var activeProcess: Process? = null
    private var stdinWriter: BufferedWriter? = null

    @Volatile
    private var stopped = false

    fun send(text: String) {
        if (text.isBlank()) return

        Thread {
            try {
                val writer = synchronized(processLock) {
                    check(!stopped) { "Claude process has been stopped." }
                    ensureProcessStartedLocked()
                    stdinWriter ?: error("Claude stdin is unavailable.")
                }

                val inputLine = createUserMessage(text).toString()
                synchronized(writeLock) {
                    writer.write(inputLine)
                    writer.newLine()
                    writer.flush()
                }
            } catch (error: Throwable) {
                if (!stopped) {
                    onError("Claude process error:\n${error.stackTraceToString()}")
                }
            }
        }.start()
    }

    fun stop() {
        stopped = true

        val process = synchronized(processLock) {
            runCatching { stdinWriter?.close() }
            stdinWriter = null

            activeProcess.also {
                activeProcess = null
            }
        }

        process?.destroy()
        if (process?.isAlive == true) {
            process.destroyForcibly()
        }
    }

    private fun ensureProcessStartedLocked() {
        if (activeProcess?.isAlive == true && stdinWriter != null) {
            return
        }

        runCatching { stdinWriter?.close() }
        stdinWriter = null
        activeProcess = null

        val bootstrap = RuntimeBootstrap(context)
        val loaderPath =
            File(context.filesDir, "runtime/lib/ld-musl-aarch64.so.1").absolutePath
        val claudePath = File(context.filesDir, "runtime/claude").absolutePath
        val prootPath = File(context.filesDir, "runtime/bin/proot").absolutePath
        val resolvConfPath =
            File(context.filesDir, "runtime/etc/resolv.conf").absolutePath
        val prootTmpDir =
            File(context.filesDir, "runtime/tmp").apply { mkdirs() }
        val workDir = File(bootstrap.workspacePath())

        val command = mutableListOf(
            prootPath,
            "-b",
            "$resolvConfPath:/etc/resolv.conf",
            loaderPath,
            claudePath,
            "-p",
            "--input-format",
            "stream-json",
            "--output-format",
            "stream-json",
            "--verbose",
            "--permission-mode",
            "bypassPermissions"
        )

        val selectedModel = SettingsActivity.getSelectedModel(context)
        if (selectedModel.isNotBlank()) {
            command += listOf("--model", selectedModel)
        }

        val processBuilder = ProcessBuilder(command)
            .directory(workDir)
            .redirectErrorStream(true)

        val environment = processBuilder.environment()
        environment.remove("LD_PRELOAD")
        environment["PROOT_TMP_DIR"] = prootTmpDir.absolutePath

        val homeDir = File(context.filesDir, "home").apply { mkdirs() }
        environment["HOME"] = homeDir.absolutePath
        environment["USER"] = "claude"
        environment["LOGNAME"] = "claude"

        val authToken = SettingsActivity.getAuthToken(context)
        if (authToken.isNotBlank()) {
            environment["ANTHROPIC_AUTH_TOKEN"] = authToken
            environment["ANTHROPIC_API_KEY"] = ""
        } else {
            environment.remove("ANTHROPIC_AUTH_TOKEN")
            environment["ANTHROPIC_API_KEY"] = SettingsActivity.getApiKey(context)
        }

        val baseUrl = SettingsActivity.getBaseUrl(context)
        if (baseUrl.isNotBlank()) {
            environment["ANTHROPIC_BASE_URL"] = baseUrl
        } else {
            environment.remove("ANTHROPIC_BASE_URL")
        }

        val resolvConf = File(resolvConfPath)
        onStatus("Model: $selectedModel")
        onStatus(
            "DNS bind: $resolvConfPath -> /etc/resolv.conf, " +
                "source exists=${resolvConf.exists()}, " +
                "readable=${resolvConf.canRead()}"
        )

        val process = processBuilder.start()
        activeProcess = process
        stdinWriter = process.outputStream.bufferedWriter()

        startOutputReader(process)
        startExitWatcher(process)
    }

    private fun startOutputReader(process: Process) {
        Thread {
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach(::handleOutputLine)
                }
            } catch (error: Throwable) {
                if (!stopped && process.isAlive) {
                    onError(
                        "Claude output reader failed:\n${error.stackTraceToString()}"
                    )
                }
            }
        }.start()
    }

    private fun startExitWatcher(process: Process) {
        Thread {
            val exitCode = process.waitFor()

            synchronized(processLock) {
                if (activeProcess === process) {
                    runCatching { stdinWriter?.close() }
                    stdinWriter = null
                    activeProcess = null
                }
            }

            if (!stopped) {
                onError("Claude process exited with code $exitCode.")
            }
        }.start()
    }

    private fun handleOutputLine(line: String) {
        if (
            line.isBlank() ||
            line.startsWith(STDIN_WARNING_PREFIX)
        ) {
            return
        }

        val event = try {
            JSONObject(line)
        } catch (_: Exception) {
            onError("Claude emitted non-JSON output: $line")
            return
        }

        when (event.optString("type")) {
            "system" -> {
                // Initialization and other system events are intentionally
                // ignored for now.
            }

            "assistant" -> handleAssistantEvent(event)

            "result" -> {
                onResult(
                    event.optBoolean("is_error", false),
                    event.optString("result", "")
                )
            }

            else -> {
                // Ignore currently unsupported event types so new Claude
                // events do not terminate the session.
            }
        }
    }

    private fun handleAssistantEvent(event: JSONObject) {
        val content = event
            .optJSONObject("message")
            ?.optJSONArray("content")
            ?: return

        for (index in 0 until content.length()) {
            val block = content.optJSONObject(index) ?: continue
            if (block.optString("type") != "text") continue

            val text = block.optString("text", "")
            if (text.isNotEmpty()) {
                onAssistantText(text)
            }
        }
    }

    private fun createUserMessage(text: String): JSONObject {
        val content = JSONArray().put(
            JSONObject()
                .put("type", "text")
                .put("text", text)
        )

        val message = JSONObject()
            .put("role", "user")
            .put("content", content)

        return JSONObject()
            .put("type", "user")
            .put("message", message)
    }

    companion object {
        private const val STDIN_WARNING_PREFIX = "Warning: no stdin data"
    }
}
