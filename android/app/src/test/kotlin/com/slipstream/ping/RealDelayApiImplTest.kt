package com.slipstream.ping

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RealDelayApiImplTest {

    private val request =
            RealDelayRequest(
                    configJson = "{}",
                    geoAssetDir = "/geo",
                    url = "https://example.com/204",
                    timeoutMs = 8000,
            )

    // Runs the work right away on the same thread, so a test sees the answer
    // as soon as measure returns.
    private fun api(
            measure: (String, String, String, Int) -> Long,
            threads: MutableList<String> = mutableListOf(),
    ) =
            RealDelayApiImpl(
                    measure = measure,
                    runInBackground = { work ->
                        threads.add("background")
                        work()
                    },
                    onMain = { work ->
                        threads.add("main")
                        work()
                    },
            )

    private fun run(api: RealDelayApiImpl): RealDelayResult {
        var result: Result<RealDelayResult>? = null
        api.measure(request) { result = it }
        return result!!.getOrThrow()
    }

    @Test
    fun theTimeFromTheCoreComesBackAsMilliseconds() {
        val result = run(api(measure = { _, _, _, _ -> 312L }))

        assertEquals(312L, result.latencyMs)
        assertNull(result.error)
    }

    @Test
    fun theRequestReachesTheCoreFieldByField() {
        var got: List<Any>? = null
        run(api(measure = { config, dir, url, timeout ->
            got = listOf(config, dir, url, timeout)
            1L
        }))

        assertEquals(listOf("{}", "/geo", "https://example.com/204", 8000), got)
    }

    @Test
    fun aFailureOfTheCoreIsAnAnswerNotAnException() {
        // The Dart side shows "failed", it must not get a platform error.
        val result = run(api(measure = { _, _, _, _ -> throw Exception("measure: timed out") }))

        assertNull(result.latencyMs)
        assertEquals("measure: timed out", result.error)
    }

    @Test
    fun anErrorWithoutATextStillHasOne() {
        val result = run(api(measure = { _, _, _, _ -> throw Exception() }))

        assertTrue(!result.error.isNullOrEmpty())
    }

    @Test
    fun theCoreRunsInTheBackgroundAndTheAnswerGoesBackOnTheMainThread() {
        val order = mutableListOf<String>()
        run(api(measure = { _, _, _, _ -> order.add("core"); 1L }, threads = order))

        assertEquals(listOf("background", "core", "main"), order)
    }

    @Test
    fun theCoreIsNotCalledBeforeTheBackgroundThreadStarts() {
        var called = false
        var started: (() -> Unit)? = null
        val api =
                RealDelayApiImpl(
                        measure = { _, _, _, _ -> called = true; 1L },
                        runInBackground = { work -> started = work },
                        onMain = { it() },
                )

        api.measure(request) {}

        assertTrue(!called)
        started!!()
        assertTrue(called)
    }
}
