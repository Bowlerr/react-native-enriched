package com.swmansion.enriched.common.spans

import android.text.Spanned
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

internal const val CONTINUATION_MARKER_START = -2

internal fun EnrichedListSpan.shouldDrawListMarker(
  text: CharSequence?,
  start: Int,
  end: Int,
  first: Boolean,
): Boolean {
  val spannedText = text as? Spanned ?: return false
  if (markerStart == CONTINUATION_MARKER_START) {
    return false
  }

  val listStart = spannedText.getSpanStart(this)
  if (listStart < 0) {
    return false
  }

  val markerIndex = listMarkerIndex(spannedText)
  if (markerIndex >= 0) {
    if (!drawsMarkerForEmptyContent && !hasVisibleContent(text, start, end)) {
      return false
    }
    if (isMarkerDrawnByContainedQuote(spannedText, start, end)) {
      return false
    }
    return markerIndex >= start && markerIndex < end
  }

  if (!drawsMarkerForEmptyContent || !first) {
    return false
  }
  return listStart >= start && listStart <= end
}

internal fun EnrichedListSpan.shouldDrawMarkerFromContainedQuote(
  text: CharSequence?,
  quoteSpan: EnrichedBlockQuoteSpan,
  start: Int,
  end: Int,
): Boolean {
  if (!ownsMarkerForContainedQuote(text, quoteSpan)) {
    return false
  }

  val markerIndex = listMarkerIndex(text)
  return markerIndex >= start && markerIndex < end
}

internal fun EnrichedListSpan.ownsMarkerForContainedQuote(
  text: CharSequence?,
  quoteSpan: EnrichedBlockQuoteSpan,
): Boolean {
  val spannedText = text as? Spanned ?: return false
  if (markerStart == CONTINUATION_MARKER_START) {
    return false
  }

  val listStart = spannedText.getSpanStart(this)
  val listEnd = spannedText.getSpanEnd(this)
  val quoteStart = spannedText.getSpanStart(quoteSpan)
  val quoteEnd = spannedText.getSpanEnd(quoteSpan)
  if (listStart < 0 || listEnd < 0 || quoteStart < 0 || quoteEnd < 0) {
    return false
  }

  if (!reservesMarginBeforeContainedQuote(spannedText, quoteSpan)) {
    return false
  }

  val markerIndex = listMarkerIndex(spannedText)
  if (markerIndex < quoteStart || markerIndex >= quoteEnd || markerIndex >= listEnd) {
    return false
  }

  return outermostContainedBlockQuoteAt(spannedText, markerIndex, listStart) === quoteSpan
}

internal fun EnrichedListSpan.reservesMarginBeforeContainedQuote(
  text: CharSequence?,
  quoteSpan: EnrichedBlockQuoteSpan,
): Boolean {
  val spannedText = text as? Spanned ?: return false
  val listStart = spannedText.getSpanStart(this)
  val listEnd = spannedText.getSpanEnd(this)
  val quoteStart = spannedText.getSpanStart(quoteSpan)
  val quoteEnd = spannedText.getSpanEnd(quoteSpan)
  if (listStart < 0 || listEnd < 0 || quoteStart < 0 || quoteEnd < 0) {
    return false
  }

  // Only list -> quote needs a manual offset. For quote -> list, Android's
  // normal LeadingMarginSpan progression already puts the list marker after
  // the quote rail.
  return listStartsBeforeQuote(listStart, quoteStart, quoteSpan) && listEnd >= quoteEnd
}

internal fun EnrichedListSpan.listMarkerIndex(text: CharSequence?): Int {
  val spannedText = text as? Spanned ?: return -1
  val listStart = spannedText.getSpanStart(this)
  val listEnd = spannedText.getSpanEnd(this)
  if (listStart < 0 || listEnd < 0) {
    return -1
  }

  return markerStart
    .takeIf { it >= listStart && it < listEnd }
    ?: firstVisibleContentIndex(text, listStart, listEnd)
}

private fun EnrichedListSpan.isMarkerDrawnByContainedQuote(
  spannedText: Spanned,
  start: Int,
  end: Int,
): Boolean =
  spannedText
    .getSpans(start, end, EnrichedBlockQuoteSpan::class.java)
    .any { blockquoteSpan -> ownsMarkerForContainedQuote(spannedText, blockquoteSpan) }

private fun EnrichedListSpan.outermostContainedBlockQuoteAt(
  spannedText: Spanned,
  index: Int,
  listStart: Int,
): EnrichedBlockQuoteSpan? {
  if (index < 0 || index >= spannedText.length) {
    return null
  }

  return spannedText
    .getSpans(
      index,
      (index + 1).coerceAtMost(spannedText.length),
      EnrichedBlockQuoteSpan::class.java,
    ).filter { blockquoteSpan ->
      val spanStart = spannedText.getSpanStart(blockquoteSpan)
      val spanEnd = spannedText.getSpanEnd(blockquoteSpan)
      listStartsBeforeQuote(listStart, spanStart, blockquoteSpan) &&
        spanStart <= index &&
        spanEnd > index
    }.sortedWith { left, right ->
      val leftStart = spannedText.getSpanStart(left)
      val rightStart = spannedText.getSpanStart(right)
      if (leftStart != rightStart) {
        return@sortedWith leftStart - rightStart
      }

      val leftEnd = spannedText.getSpanEnd(left)
      val rightEnd = spannedText.getSpanEnd(right)
      rightEnd - leftEnd
    }.firstOrNull()
}

private fun EnrichedListSpan.listStartsBeforeQuote(
  listStart: Int,
  quoteStart: Int,
  quoteSpan: EnrichedBlockQuoteSpan,
): Boolean {
  if (listStart < quoteStart) {
    return true
  }

  if (listStart > quoteStart) {
    return false
  }

  return enclosingBlockQuoteDepth < quoteSpan.quoteDepth
}

internal fun EnrichedListSpan.blockQuoteContinuationMarkerCount(
  text: CharSequence?,
  start: Int,
  end: Int,
): Int {
  val spannedText = text as? Spanned ?: return 0
  val listStart = spannedText.getSpanStart(this)
  val listEnd = spannedText.getSpanEnd(this)
  if (listStart < 0 || listEnd < 0) {
    return 0
  }

  return spannedText
    .getSpans(start, end, EnrichedBlockQuoteSpan::class.java)
    .count { blockquoteSpan ->
      val blockquoteStart = spannedText.getSpanStart(blockquoteSpan)
      val blockquoteEnd = spannedText.getSpanEnd(blockquoteSpan)
      if (blockquoteStart < 0 || blockquoteEnd < 0 || blockquoteEnd <= start) {
        return@count false
      }

      val blockquoteOwnershipStart =
        firstVisibleContentIndex(text, blockquoteStart, blockquoteEnd).takeIf { it >= 0 }
          ?: blockquoteStart
      blockquoteOwnershipStart >= listStart &&
        blockquoteOwnershipStart < listEnd &&
        blockquoteStart <= start &&
        blockquoteOwnershipStart <= start
    }
}

private fun hasVisibleContent(
  text: CharSequence,
  start: Int,
  end: Int,
): Boolean {
  val safeEnd = end.coerceAtMost(text.length)
  for (index in start until safeEnd) {
    if (text[index] != EnrichedConstants.ZWS && !Character.isWhitespace(text[index])) {
      return true
    }
  }
  return false
}

private fun firstVisibleContentIndex(
  text: CharSequence,
  start: Int,
  end: Int,
): Int {
  val safeEnd = end.coerceAtMost(text.length)
  for (index in start until safeEnd) {
    if (text[index] != EnrichedConstants.ZWS && !Character.isWhitespace(text[index])) {
      return index
    }
  }
  return -1
}
