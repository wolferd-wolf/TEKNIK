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

    private data class PendingTurn(
        val text: String,
        val triedProfileIds: MutableSet<String>
    )

    private val processLock = Any()
    private val writeLock = Any()
    private var activeProcess: Process? = null
    private var stdinWriter: BufferedWriter? = null
    private var runningProfileId: String? = null
    private var runningProfilesRevision: Long? = null
    private var runningSessionId: String? = null
    private var currentSessionId: String? = null
    private var pendingNewSessionLabel: String? = null
    private var pendingTurn: PendingTurn? = null

    @Volatile
    private var stopped = false

    fun send(text: String) {
        if (text.isBlank()) return

        Thread {
            try {
                synchronized(processLock) {
                    check(!stopped) {
                        "Claude process has been stopped."
                    }
                    check(pendingTurn == null) {
                        "A Claude request is already in progress."
                    }

                    val profile =
                        ProfileStore.getActiveProfile(context)
                    val profilesRevision =
                        ProfileStore.getProfilesRevision(context)
                    val resumeSessionId = currentSessionId

                    if (
                        resumeSessionId == null &&
                        pendingNewSessionLabel == null
                    ) {
                        pendingNewSessionLabel =
                            createSessionLabel(text)
                    }

                    val turn = PendingTurn(
                        text = text,
                        triedProfileIds = linkedSetOf(profile.id)
                    )
                    pendingTurn = turn

                    try {
                        ensureProcessStartedLocked(
                            profile,
                            profilesRevision,
                            resumeSessionId
                        )
                        writeUserMessageLocked(text)
                    } catch (error: Throwable) {
                        if (pendingTurn === turn) {
                            pendingTurn = null
                        }
                        throw error
                    }
                }
            } catch (error: Throwable) {
                if (!stopped) {
                    onError(
                        "Claude process error:\n" +
                            error.stackTraceToString()
                    )
                }
            }
        }.start()
    }

    fun resumeSession(sessionId: String) {
        val normalizedSessionId = sessionId.trim()
        if (normalizedSessionId.isBlank()) return

        Thread {
            try {
                synchronized(processLock) {
                    check(!stopped) {
                        "Claude process has been stopped."
                    }
                    check(pendingTurn == null) {
                        "A Claude request is already in progress."
                    }

                    val profile =
                        ProfileStore.getActiveProfile(context)
                    val profilesRevision =
                        ProfileStore.getProfilesRevision(context)

                    stopActiveProcessLocked()
                    currentSessionId = normalizedSessionId
                    pendingNewSessionLabel = null

                    ensureProcessStartedLocked(
                        profile,
                        profilesRevision,
                        normalizedSessionId
                    )
                }
            } catch (error: Throwable) {
                if (!stopped) {
                    onError(
                        "Claude session resume error:\n" +
                            error.stackTraceToString()
                    )
                }
            }
        }.start()
    }

    fun stop() {
        stopped = true

        synchronized(processLock) {
            pendingTurn = null
            currentSessionId = null
            pendingNewSessionLabel = null
            stopActiveProcessLocked()
        }
    }

    private fun ensureProcessStartedLocked(
        profile: ClaudeProfile,
        profilesRevision: Long,
        resumeSessionId: String?
    ) {
        if (
            activeProcess?.isAlive == true &&
            stdinWriter != null &&
            runningProfileId == profile.id &&
            runningProfilesRevision == profilesRevision &&
            runningSessionId == resumeSessionId
        ) {
            return
        }

        stopActiveProcessLocked()

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

        if (!resumeSessionId.isNullOrBlank()) {
            command += listOf("-r", resumeSessionId)
        }

        if (profile.model.isNotBlank()) {
            command += listOf("--model", profile.model)
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

        if (profile.authToken.isNotBlank()) {
            environment["ANTHROPIC_AUTH_TOKEN"] = profile.authToken
            environment["ANTHROPIC_API_KEY"] = ""
        } else {
            environment.remove("ANTHROPIC_AUTH_TOKEN")
            environment["ANTHROPIC_API_KEY"] = profile.apiKey
        }

        if (profile.baseUrl.isNotBlank()) {
            environment["ANTHROPIC_BASE_URL"] = profile.baseUrl
        } else {
            environment.remove("ANTHROPIC_BASE_URL")
        }

        val resolvConf = File(resolvConfPath)
        onStatus("Profile: ${profile.name}")
        onStatus("Model: ${profile.model}")
        onStatus(
            "DNS bind: $resolvConfPath -> /etc/resolv.conf, " +
                "source exists=${resolvConf.exists()}, " +
                "readable=${resolvConf.canRead()}"
        )

        val process = processBuilder.start()
        activeProcess = process
        runningProfileId = profile.id
        runningProfilesRevision = profilesRevision
        runningSessionId = resumeSessionId
        stdinWriter = process.outputStream.bufferedWriter()

        startOutputReader(process)
        startExitWatcher(process)
    }

    private fun stopActiveProcessLocked() {
        val process = activeProcess
        runCatching { stdinWriter?.close() }
        stdinWriter = null
        activeProcess = null
        runningProfileId = null
        runningProfilesRevision = null
        runningSessionId = null

        process?.destroy()
        if (process?.isAlive == true) {
            process.destroyForcibly()
        }
    }

    private fun writeUserMessageLocked(text: String) {
        val writer =
            stdinWriter ?: error("Claude stdin is unavailable.")
        val inputLine = createUserMessage(text).toString()

        synchronized(writeLock) {
            writer.write(inputLine)
            writer.newLine()
            writer.flush()
        }
    }

    private fun startOutputReader(process: Process) {
        Thread {
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line ->
                        handleOutputLine(process, line)
                    }
                }
            } catch (error: Throwable) {
                val shouldReport = synchronized(processLock) {
                    !stopped &&
                        activeProcess === process &&
                        process.isAlive
                }

                if (shouldReport) {
                    onError(
                        "Claude output reader failed:\n" +
                            error.stackTraceToString()
                    )
                }
            }
        }.start()
    }

    private fun startExitWatcher(process: Process) {
        Thread {
            val exitCode = process.waitFor()

            val shouldReport = synchronized(processLock) {
                if (activeProcess !== process) {
                    false
                } else {
                    runCatching { stdinWriter?.close() }
                    stdinWriter = null
                    activeProcess = null
                    runningProfileId = null
                    runningProfilesRevision = null
                    runningSessionId = null
                    pendingTurn = null

                    if (currentSessionId == null) {
                        pendingNewSessionLabel = null
                    }

                    !stopped
                }
            }

            if (shouldReport) {
                onError(
                    "Claude process exited with code $exitCode."
                )
            }
        }.start()
    }

    private fun handleOutputLine(
        process: Process,
        line: String
    ) {
        val isCurrentProcess = synchronized(processLock) {
            activeProcess === process
        }
        if (!isCurrentProcess) return

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
            "system" -> handleSystemEvent(process, event)
            "assistant" -> handleAssistantEvent(event)
            "result" -> handleResultEvent(process, event)

            else -> {
                // Ignore currently unsupported event types so new Claude
                // events do not terminate the session.
            }
        }
    }

    private fun handleSystemEvent(
        process: Process,
        event: JSONObject
    ) {
        if (event.optString("subtype") != "init") return

        val sessionId = event.optString("session_id").trim()
        if (sessionId.isBlank()) return

        val newSession = synchronized(processLock) {
            if (activeProcess !== process) {
                return@synchronized null
            }

            currentSessionId = sessionId
            runningSessionId = sessionId

            val label = pendingNewSessionLabel
            pendingNewSessionLabel = null

            label?.let {
                ClaudeSession(
                    sessionId = sessionId,
                    label = it,
                    timestamp = System.currentTimeMillis()
                )
            }
        }

        if (newSession != null) {
            SessionStore.addIfMissing(context, newSession)
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

    private fun handleResultEvent(
        process: Process,
        event: JSONObject
    ) {
        val isError = event.optBoolean("is_error", false)
        val result = event.optString("result", "")
        val apiErrorStatus = readApiErrorStatus(event)

        if (
            isError &&
            apiErrorStatus != null &&
            apiErrorStatus in RETRYABLE_API_STATUSES &&
            retryPendingTurn(process, apiErrorStatus)
        ) {
            return
        }

        val shouldDeliver = synchronized(processLock) {
            if (activeProcess !== process) {
                false
            } else {
                pendingTurn = null
                true
            }
        }

        if (shouldDeliver) {
            onResult(isError, result)
        }
    }

    private fun retryPendingTurn(
        failedProcess: Process,
        apiErrorStatus: Int
    ): Boolean = synchronized(processLock) {
        if (activeProcess !== failedProcess) {
            return@synchronized false
        }

        val turn =
            pendingTurn ?: return@synchronized false
        val currentProfileId =
            runningProfileId ?: return@synchronized false
        val nextProfile = ProfileStore.getNextUntriedProfile(
            context = context,
            currentProfileId = currentProfileId,
            triedProfileIds = turn.triedProfileIds
        ) ?: return@synchronized false

        turn.triedProfileIds += nextProfile.id
        ProfileStore.setActiveProfile(context, nextProfile.id)
        val profilesRevision =
            ProfileStore.getProfilesRevision(context)
        onStatus(
            "API status $apiErrorStatus; " +
                "switching to profile: ${nextProfile.name}"
        )

        return@synchronized try {
            ensureProcessStartedLocked(
                nextProfile,
                profilesRevision,
                currentSessionId
            )
            writeUserMessageLocked(turn.text)
            true
        } catch (error: Throwable) {
            pendingTurn = null
            onError(
                "Profile failover failed:\n" +
                    error.stackTraceToString()
            )
            false
        }
    }

    private fun readApiErrorStatus(
        event: JSONObject
    ): Int? = when (val value = event.opt("api_error_status")) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }

    private fun createSessionLabel(text: String): String {
        val normalized = text
            .trim()
            .replace(Regex("\\s+"), " ")

        return if (normalized.length <= SESSION_LABEL_MAX_LENGTH) {
            normalized
        } else {
            normalized
                .take(SESSION_LABEL_MAX_LENGTH - 3)
                .trimEnd() + "..."
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
        private const val STDIN_WARNING_PREFIX =
            "Warning: no stdin data"
        private const val SESSION_LABEL_MAX_LENGTH = 60
        private val RETRYABLE_API_STATUSES =
            setOf(401, 402, 403, 429)
    }
}
