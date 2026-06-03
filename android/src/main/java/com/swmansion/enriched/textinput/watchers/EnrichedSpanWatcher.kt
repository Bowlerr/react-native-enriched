package com.swmansion.enriched.textinput.watchers

import android.os.Handler
import android.os.Looper
import android.text.SpanWatcher
import android.text.Spannable
import android.text.SpannableString
import android.text.style.MetricAffectingSpan
import android.text.style.ParagraphStyle
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.swmansion.enriched.common.parser.EnrichedParser
import com.swmansion.enriched.common.spans.interfaces.EnrichedHeadingSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan
import com.swmansion.enriched.textinput.EnrichedTextInputView
import com.swmansion.enriched.textinput.events.OnChangeHtmlEvent
import com.swmansion.enriched.textinput.spans.EnrichedInputOrderedListSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.utils.getSafeSpanBoundaries
import java.util.concurrent.Executors

class EnrichedSpanWatcher(
  private val view: EnrichedTextInputView,
) : SpanWatcher {
  private var previousHtml: String? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  @Volatile
  private var htmlGeneration = 0

  private val emitHtmlRunnable =
    Runnable {
      emitLatestHtmlAsync()
    }

  override fun onSpanAdded(
    text: Spannable,
    what: Any,
    start: Int,
    end: Int,
  ) {
    updateNextLineLayout(what, text, end)
    updateUnorderedListSpans(what, text, end)
    emitEvent(text, what)
  }

  override fun onSpanRemoved(
    text: Spannable,
    what: Any,
    start: Int,
    end: Int,
  ) {
    updateNextLineLayout(what, text, end)
    updateUnorderedListSpans(what, text, end)
    emitEvent(text, what)
  }

  override fun onSpanChanged(
    text: Spannable,
    what: Any,
    ostart: Int,
    oend: Int,
    nstart: Int,
    nend: Int,
  ) {
    // Do nothing for now
  }

  private fun updateUnorderedListSpans(
    what: Any,
    text: Spannable,
    end: Int,
  ) {
    if (what is EnrichedInputOrderedListSpan) {
      view.listStyles?.updateOrderedListIndexes(text, end)
    }
  }

  // After adding/removing heading or inline MetricAffectingSpan spans, we have to manually set empty paragraph span to the following text
  // This allows us to update the layout (as it's not updated automatically - looks like an Android issue)
  private fun updateNextLineLayout(
    what: Any,
    text: Spannable,
    end: Int,
  ) {
    class EmptySpan : ParagraphStyle

    if (what is EnrichedHeadingSpan || (what is EnrichedInlineSpan && what is MetricAffectingSpan)) {
      val finalStart = (end + 1)
      val finalEnd = text.length
      val (safeStart, safeEnd) = text.getSafeSpanBoundaries(finalStart, finalEnd)
      text.setSpan(EmptySpan(), safeStart, safeEnd, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
  }

  fun emitEvent(
    s: Spannable,
    what: Any?,
  ) {
    // Do not parse spannable and emit event if onChangeHtml is not provided
    if (!view.shouldEmitHtml) return

    // Emit event only if we change one of ours spans
    if (what != null && what !is EnrichedInputSpan) return

    scheduleHtmlEvent()
  }

  fun cancelPendingHtmlEvent() {
    htmlGeneration++
    mainHandler.removeCallbacks(emitHtmlRunnable)
  }

  private fun scheduleHtmlEvent() {
    htmlGeneration++
    mainHandler.removeCallbacks(emitHtmlRunnable)
    mainHandler.postDelayed(emitHtmlRunnable, HTML_EMIT_DEBOUNCE_MS)
  }

  private fun emitLatestHtmlAsync() {
    val generation = htmlGeneration
    val snapshot = SpannableString(view.text ?: return)

    htmlExecutor.execute {
      if (generation != htmlGeneration) return@execute

      val html = EnrichedParser.toHtml(snapshot)

      mainHandler.post {
        if (generation != htmlGeneration) return@post
        if (html == previousHtml) return@post

        previousHtml = html
        dispatchHtmlEvent(html)
      }
    }
  }

  private fun dispatchHtmlEvent(html: String) {
    val context = view.context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(context)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
    dispatcher?.dispatchEvent(
      OnChangeHtmlEvent(
        surfaceId,
        view.id,
        html,
        view.experimentalSynchronousEvents,
      ),
    )
  }

  companion object {
    private const val HTML_EMIT_DEBOUNCE_MS = 80L
    private val htmlExecutor = Executors.newSingleThreadExecutor()
  }
}
