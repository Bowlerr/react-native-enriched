package com.swmansion.enriched.textinput

import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.TextPaint
import com.facebook.react.bridge.Arguments
import com.swmansion.enriched.common.spans.EnrichedImageSpan
import java.util.concurrent.Executors

class EnrichedTextInputViewLayoutManager(
  private val view: EnrichedTextInputView,
) {
  private var forceHeightRecalculationCounter: Int = 0
  private val mainHandler = Handler(Looper.getMainLooper())

  @Volatile
  private var layoutGeneration = 0

  private val invalidateLayoutRunnable =
    Runnable {
      invalidateLayoutAsync()
    }

  fun invalidateLayout() {
    layoutGeneration++
    mainHandler.removeCallbacks(invalidateLayoutRunnable)
    mainHandler.post(invalidateLayoutRunnable)
  }

  fun cancelPendingLayoutInvalidation() {
    layoutGeneration++
    mainHandler.removeCallbacks(invalidateLayoutRunnable)
  }

  private fun invalidateLayoutAsync() {
    val generation = layoutGeneration
    val viewId = view.id
    val text = view.text?.let { SpannableString(it) }
    val paint = TextPaint(view.paint)

    // Plain style spans are safe to measure from a copied Spannable off-main.
    // Image spans own Drawable state and can mutate bounds during measurement,
    // so keep those measurements on the UI thread.
    if (hasImageSpans(text)) {
      measureAndPublishOnMain(generation, viewId, text, paint)
      return
    }

    measurementExecutor.execute {
      if (generation != layoutGeneration) return@execute

      val result = MeasurementStore.createStoreResult(viewId, text, paint)
      if (generation != layoutGeneration) return@execute

      val needUpdate = MeasurementStore.commitStoreResult(viewId, result)
      if (!needUpdate) return@execute

      mainHandler.post {
        publishHeightUpdate(generation)
      }
    }
  }

  private fun hasImageSpans(text: SpannableString?): Boolean {
    if (text == null) return false
    return text.getSpans(0, text.length, EnrichedImageSpan::class.java).isNotEmpty()
  }

  private fun measureAndPublishOnMain(
    generation: Int,
    viewId: Int,
    text: SpannableString?,
    paint: TextPaint,
  ) {
    if (generation != layoutGeneration) return

    val needUpdate = MeasurementStore.store(viewId, text, paint)
    if (!needUpdate) return

    publishHeightUpdate(generation)
  }

  private fun publishHeightUpdate(generation: Int) {
    if (generation != layoutGeneration) return

    val counter = forceHeightRecalculationCounter
    forceHeightRecalculationCounter++
    val state = Arguments.createMap()
    state.putInt("forceHeightRecalculationCounter", counter)
    view.stateWrapper?.updateState(state)
  }

  fun releaseMeasurementStore() {
    cancelPendingLayoutInvalidation()
    MeasurementStore.release(view.id)
  }

  companion object {
    private val measurementExecutor = Executors.newSingleThreadExecutor()
  }
}
