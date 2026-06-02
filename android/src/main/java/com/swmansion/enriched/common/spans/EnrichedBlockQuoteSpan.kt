package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

// https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/text/style/QuoteSpan.java
open class EnrichedBlockQuoteSpan(
  private val enrichedStyle: EnrichedStyle,
) : MetricAffectingSpan(),
  LeadingMarginSpan,
  EnrichedBlockSpan {
  override fun updateMeasureState(p0: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun getLeadingMargin(p0: Boolean): Int = enrichedStyle.blockquoteStripeWidth + enrichedStyle.blockquoteGapWidth

  override fun drawLeadingMargin(
    c: Canvas,
    p: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  ) {
    val style = p.style
    val color = p.color
    p.style = Paint.Style.FILL
    p.color = enrichedStyle.blockquoteBorderColor
    val stripeX = x - dir * nestedListLeadingMargin(text, start, end, first)
    c.drawRect(stripeX.toFloat(), top.toFloat(), stripeX + dir * enrichedStyle.blockquoteStripeWidth.toFloat(), bottom.toFloat(), p)
    p.style = style
    p.color = color
  }

  private fun nestedListLeadingMargin(
    text: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
  ): Int {
    val spannedText = text as? Spanned ?: return 0
    val blockquoteStart = spannedText.getSpanStart(this)
    if (blockquoteStart < 0) {
      return 0
    }

    return spannedText
      .getSpans(start, end, EnrichedListSpan::class.java)
      .filter { listSpan -> spannedText.getSpanStart(listSpan) >= blockquoteStart }
      .sumOf { listSpan -> (listSpan as? LeadingMarginSpan)?.getLeadingMargin(first) ?: 0 }
  }

  override fun updateDrawState(textPaint: TextPaint?) {
    val color = enrichedStyle.blockquoteColor
    if (color != null) {
      textPaint?.color = color
    }
  }
}
