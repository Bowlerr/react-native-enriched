package com.swmansion.enriched.textinput.styles

import android.text.Editable
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan
import com.swmansion.enriched.textinput.EnrichedTextInputView
import com.swmansion.enriched.textinput.spans.EnrichedInputCheckboxListSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputOrderedListSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputUnorderedListSpan
import com.swmansion.enriched.textinput.spans.EnrichedSpans
import com.swmansion.enriched.textinput.utils.getParagraphBounds
import com.swmansion.enriched.textinput.utils.getSafeSpanBoundaries
import com.swmansion.enriched.textinput.utils.removeZWS

class ListStyles(
  private val view: EnrichedTextInputView,
) {
  private fun <T> getPreviousParagraphSpan(
    spannable: Spannable,
    s: Int,
    type: Class<T>,
  ): T? {
    if (s <= 0) return null

    val (previousParagraphStart, previousParagraphEnd) = spannable.getParagraphBounds(s - 1)
    val spans = spannable.getSpans(previousParagraphStart, previousParagraphEnd, type)

    if (spans.isNotEmpty()) {
      return spans.last()
    }

    return null
  }

  private fun getOrderedListIndex(
    spannable: Spannable,
    s: Int,
    level: Int = 0,
  ): Int {
    val span = getPreviousParagraphSpan(spannable, s, EnrichedInputOrderedListSpan::class.java)
    val index =
      if (span?.level == level) {
        span.getListIndex()
      } else {
        0
      }
    return index + 1
  }

  private fun getListLevel(span: Any?): Int = (span as? EnrichedListSpan)?.level ?: 0

  private fun getDeepestListSpan(spans: Array<out Any>): EnrichedListSpan? =
    spans
      .filterIsInstance<EnrichedListSpan>()
      .maxByOrNull { it.level }

  private fun setSpan(
    spannable: Spannable,
    name: String,
    start: Int,
    end: Int,
    isChecked: Boolean? = false,
    level: Int = 0,
  ) {
    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)

    when (name) {
      EnrichedSpans.UNORDERED_LIST -> {
        val span = EnrichedInputUnorderedListSpan(view.htmlStyle, level)
        spannable.setSpan(span, safeStart, safeEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }

      EnrichedSpans.ORDERED_LIST -> {
        val index = getOrderedListIndex(spannable, safeStart, level)
        val span = EnrichedInputOrderedListSpan(index, view.htmlStyle, level)
        spannable.setSpan(span, safeStart, safeEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }

      EnrichedSpans.CHECKBOX_LIST -> {
        val span = EnrichedInputCheckboxListSpan(isChecked ?: false, view.htmlStyle, level)
        spannable.setSpan(span, safeStart, safeEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        // Invalidate layout to update checkbox drawing in case checkbox is bigger than line height
        view.layoutManager.invalidateLayout()
      }
    }
  }

  private fun <T> removeSpansForRange(
    spannable: Spannable,
    start: Int,
    end: Int,
    clazz: Class<T>,
  ): Boolean {
    val ssb = spannable as SpannableStringBuilder
    val spans = ssb.getSpans(start, end, clazz)
    if (spans.isEmpty()) return false

    for (span in spans) {
      ssb.removeSpan(span)
    }

    ssb.removeZWS(start, end)
    return true
  }

  fun updateOrderedListIndexes(
    text: Spannable,
    position: Int,
  ) {
    val counters = mutableMapOf<Int, Int>()
    var paragraphStart = 0

    while (paragraphStart < text.length) {
      val (start, end) = text.getParagraphBounds(paragraphStart)
      val orderedSpans =
        text
          .getSpans(start, end, EnrichedInputOrderedListSpan::class.java)
          .filter { text.getSpanStart(it) == start }

      if (orderedSpans.isEmpty()) {
        counters.clear()
      } else {
        val span = orderedSpans.maxByOrNull { it.level } ?: orderedSpans[0]
        val level = span.level.coerceAtLeast(0)
        counters.keys.filter { it > level }.forEach { counters.remove(it) }
        val nextIndex = (counters[level] ?: 0) + 1
        counters[level] = nextIndex
        span.setListIndex(nextIndex)
      }

      if (end >= text.length) {
        break
      }
      paragraphStart = end + 1
    }
  }

  private fun toggleStyle(
    name: String,
    checkboxState: Boolean?,
  ) {
    if (view.selection == null) return
    val config = EnrichedSpans.listSpans[name] ?: return
    val spannable = view.text as SpannableStringBuilder
    val (start, end) = view.selection.getParagraphSelection()
    val styleStart = view.spanState?.getStart(name)

    if (styleStart != null) {
      view.spanState.setStart(name, null)
      removeSpansForRange(spannable, start, end, config.clazz)
      view.selection.validateStyles()

      return
    }

    if (start == end) {
      spannable.insert(start, EnrichedConstants.ZWS_STRING)
      view.spanState?.setStart(name, start + 1)
      removeSpansForRange(spannable, start, end, config.clazz)
      setSpan(spannable, name, start, end + 1, checkboxState)

      return
    }

    var currentStart = start
    val paragraphs = spannable.substring(start, end).split("\n")
    removeSpansForRange(spannable, start, end, config.clazz)

    for (paragraph in paragraphs) {
      spannable.insert(currentStart, EnrichedConstants.ZWS_STRING)
      val currentEnd = currentStart + paragraph.length + 1
      setSpan(spannable, name, currentStart, currentEnd, checkboxState)

      currentStart = currentEnd + 1
    }

    view.spanState?.setStart(name, currentStart)
  }

  fun toggleStyle(name: String) {
    toggleStyle(name, false)
  }

  fun toggleCheckboxListStyle(checked: Boolean) {
    toggleStyle(EnrichedSpans.CHECKBOX_LIST, checked)
  }

  private fun handleAfterTextChanged(
    s: Editable,
    name: String,
    endCursorPosition: Int,
    previousTextLength: Int,
  ) {
    val config = EnrichedSpans.listSpans[name] ?: return
    val cursorPosition = endCursorPosition.coerceAtMost(s.length)
    val (start, end) = s.getParagraphBounds(cursorPosition)

    val isBackspace = previousTextLength > s.length
    val isNewLine = cursorPosition > 0 && s[cursorPosition - 1] == '\n'
    val isShortcut = config.shortcut?.let { s.substring(start, end).startsWith(it) } ?: false
    val spans = s.getSpans(start, end, config.clazz)

    // Remove spans if cursor is at the start of the paragraph and spans exist
    if (isBackspace && start == cursorPosition && spans.isNotEmpty()) {
      removeSpansForRange(s, start, end, config.clazz)
      return
    }

    if (!isBackspace && isShortcut) {
      s.replace(start, cursorPosition, EnrichedConstants.ZWS_STRING)
      setSpan(s, name, start, start + 1)
      // Inform that new span has been added
      view.selection?.validateStyles()
      return
    }

    val previousListSpan = getPreviousParagraphSpan(s, start, config.clazz)
    if (!isBackspace && isNewLine && previousListSpan != null) {
      // Check if the span from the previous line "leaked" into this one
      if (spans.isNotEmpty()) {
        val existingSpan = spans[0]
        val spanStart = s.getSpanStart(existingSpan)

        // If the span started before the current paragraph (belongs to the previous item)
        // update it to end at the newline (start - 1)
        if (spanStart < start) {
          val spanFlags = s.getSpanFlags(existingSpan)
          s.setSpan(existingSpan, spanStart, start - 1, spanFlags)
        }
      }

      s.insert(cursorPosition, EnrichedConstants.ZWS_STRING)
      val previousChecked =
        if (previousListSpan is EnrichedInputCheckboxListSpan) {
          previousListSpan.isChecked
        } else {
          false
        }
      setSpan(s, name, start, end + 1, previousChecked, getListLevel(previousListSpan))
      // Inform that new span has been added
      view.selection?.validateStyles()
      return
    }

    if (name === EnrichedSpans.CHECKBOX_LIST) {
      if (spans.isNotEmpty()) {
        val previousSpan =
          spans
            .filterIsInstance<EnrichedInputCheckboxListSpan>()
            .maxByOrNull { it.level } ?: spans[0] as EnrichedInputCheckboxListSpan
        val isChecked = previousSpan.isChecked
        val level = previousSpan.level

        for (span in spans) {
          s.removeSpan(span)
        }

        setSpan(s, EnrichedSpans.CHECKBOX_LIST, start, end, isChecked, level)
      }

      return
    }

    if (spans.isNotEmpty()) {
      val level = getDeepestListSpan(spans)?.level ?: 0
      for (span in spans) {
        s.removeSpan(span)
      }

      setSpan(s, name, start, end, false, level)
    }
  }

  fun afterTextChanged(
    s: Editable,
    endCursorPosition: Int,
    previousTextLength: Int,
  ) {
    handleAfterTextChanged(s, EnrichedSpans.ORDERED_LIST, endCursorPosition, previousTextLength)
    handleAfterTextChanged(s, EnrichedSpans.UNORDERED_LIST, endCursorPosition, previousTextLength)
    handleAfterTextChanged(s, EnrichedSpans.CHECKBOX_LIST, endCursorPosition, previousTextLength)
  }

  fun getStyleRange(): Pair<Int, Int> = view.selection?.getParagraphSelection() ?: Pair(0, 0)

  private fun getSelectedParagraphRanges(spannable: SpannableStringBuilder): List<Pair<Int, Int>> {
    val selection = view.selection ?: return emptyList()
    val (selectionStart, selectionEnd) = selection.getParagraphSelection()
    if (spannable.isEmpty()) return emptyList()

    val ranges = mutableListOf<Pair<Int, Int>>()
    var current = selectionStart.coerceAtLeast(0).coerceAtMost(spannable.length)
    val finalEnd = selectionEnd.coerceAtLeast(current).coerceAtMost(spannable.length)

    while (current <= finalEnd) {
      val (paragraphStart, paragraphEnd) = spannable.getParagraphBounds(current)
      ranges.add(Pair(paragraphStart, paragraphEnd))

      if (paragraphEnd >= finalEnd || paragraphEnd >= spannable.length) {
        break
      }

      current = paragraphEnd + 1
    }

    return ranges
  }

  private fun getParagraphListSpans(
    spannable: SpannableStringBuilder,
    paragraphStart: Int,
    paragraphEnd: Int,
  ): Array<EnrichedListSpan> =
    listOf(
      *spannable.getSpans(paragraphStart, paragraphEnd, EnrichedInputUnorderedListSpan::class.java),
      *spannable.getSpans(paragraphStart, paragraphEnd, EnrichedInputOrderedListSpan::class.java),
      *spannable.getSpans(paragraphStart, paragraphEnd, EnrichedInputCheckboxListSpan::class.java),
    ).filterIsInstance<EnrichedListSpan>()
      .toTypedArray()

  private fun adjustListLevel(delta: Int): Boolean {
    val spannable = view.text as? SpannableStringBuilder ?: return false
    val ranges = getSelectedParagraphRanges(spannable)
    if (ranges.isEmpty()) return false

    var changed = false
    var firstChangedStart = Int.MAX_VALUE

    for ((paragraphStart, paragraphEnd) in ranges) {
      val span = getDeepestListSpan(getParagraphListSpans(spannable, paragraphStart, paragraphEnd)) ?: continue
      val nextLevel = (span.level + delta).coerceAtLeast(0)
      if (nextLevel == span.level) continue

      span.level = nextLevel
      firstChangedStart = minOf(firstChangedStart, paragraphStart)
      changed = true
    }

    if (!changed) return false

    if (firstChangedStart != Int.MAX_VALUE) {
      updateOrderedListIndexes(spannable, firstChangedStart)
    }
    view.selection?.validateStyles()
    view.layoutManager.invalidateLayout()
    view.spanWatcher?.emitEvent(spannable, null)
    return true
  }

  fun increaseListLevel(): Boolean = adjustListLevel(1)

  fun decreaseListLevel(): Boolean = adjustListLevel(-1)

  fun removeStyle(
    name: String,
    start: Int,
    end: Int,
  ): Boolean {
    val config = EnrichedSpans.listSpans[name] ?: return false
    val spannable = view.text as Spannable
    return removeSpansForRange(spannable, start, end, config.clazz)
  }
}
