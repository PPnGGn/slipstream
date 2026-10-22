package com.slipstream.sync

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class SubscriptionSyncSchedulerImpl(private val context: Context) : SubscriptionSyncScheduler {

    companion object {
        private const val WORK_NAME = "subscription-sync"
    }

    // UPDATE keeps one job and its place in the period, so scheduling again on
    // every app start does not push the next run back.
    override fun schedule(intervalMinutes: Long) {
        val request =
                PeriodicWorkRequestBuilder<SubscriptionSyncWorker>(intervalMinutes, TimeUnit.MINUTES)
                        .setConstraints(
                                Constraints.Builder()
                                        .setRequiredNetworkType(NetworkType.CONNECTED)
                                        .build(),
                        )
                        .build()
        WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    override fun cancel() {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}
