package com.swmansion.enriched.common.spans

import android.text.Spanned
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

internal fun EnrichedListSpan.shouldDrawListMarker(
  text: CharSequence?,
  start: Int,
  end: Int,
  first: Boolean,
): Boolean {
  if (!first) {
    return false
  }

  val spannedText = text as? Spanned ?: return false
  val listStart = spannedText.getSpanStart(this)
  if (listStart == start) {
    return true
  }
  if (listStart < 0 || listStart >= start) {
    return false
  }

  return isBlockQuoteContinuationMarker(text, start, end)
}

internal fun EnrichedListSpan.isBlockQuoteContinuationMarker(
  text: CharSequence?,
  start: Int,
  end: Int,
): Boolean {
  val spannedText = text as? Spanned ?: return false
  val listStart = spannedText.getSpanStart(this)
  if (listStart < 0 || listStart >= start) {
    return false
  }

  return spannedText
    .getSpans(start, end, EnrichedBlockQuoteSpan::class.java)
    .any { blockquoteSpan ->
      val blockquoteStart = spannedText.getSpanStart(blockquoteSpan)
      blockquoteStart > listStart && blockquoteStart <= start
    }
}
