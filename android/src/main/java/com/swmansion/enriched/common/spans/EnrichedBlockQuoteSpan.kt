package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.LineBackgroundSpan
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import com.facebook.react.uimanager.PixelUtil
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedCollapsibleLayoutSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan
import kotlin.math.ceil

// https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/text/style/QuoteSpan.java
open class EnrichedBlockQuoteSpan(
  private val enrichedStyle: EnrichedStyle,
  var quoteDepth: Int = 0,
) : MetricAffectingSpan(),
  LineBackgroundSpan,
  LineHeightSpan,
  LeadingMarginSpan,
  EnrichedBlockSpan,
  EnrichedCollapsibleLayoutSpan {
  override val collapsesInvisibleContent = false

  override fun updateMeasureState(p0: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun getLeadingMargin(p0: Boolean): Int = enrichedStyle.blockquoteStripeWidth + enrichedStyle.blockquoteGapWidth

  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    val spannedText = text as? Spanned ?: return
    val spanStart = spannedText.getSpanStart(this)
    val spanEnd = spannedText.getSpanEnd(this)
    if (spanStart < 0 || spanEnd < 0) {
      return
    }

    val activeBlockQuotes = activeBlockQuotes(text, start, end)
    if (activeBlockQuotes.isEmpty() || activeBlockQuotes.first() !== this) {
      return
    }

    if (collapsesInvisibleContent && !hasVisibleContent(text, start, end)) {
      collapseLineHeight(fm)
      return
    }

    if (!hasNestedLayoutMarker(spannedText, start, end)) {
      val paragraphSpacing = quoteParagraphSpacing()
      if (isFirstLineOfParagraph(text, start)) {
        fm.ascent -= paragraphSpacing
        fm.top -= paragraphSpacing
      }
      if (isLastLineOfParagraph(text, end)) {
        fm.descent += paragraphSpacing
        fm.bottom += paragraphSpacing
      }
    }
  }

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
    // List markers that come before a contained quote are drawn from
    // drawBackground so the marker and quote rail share the same explicit x
    // origin. Android's LeadingMarginSpan callback order can otherwise pass a
    // marker x that has not accumulated the same quote/list margins as the rail.
  }

  override fun drawBackground(
    canvas: Canvas,
    p: Paint,
    left: Int,
    right: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence,
    start: Int,
    end: Int,
    lineNum: Int,
  ) {
    val activeBlockQuotes = drawableActiveBlockQuotes(text, start, end)
    if (activeBlockQuotes.isEmpty() || activeBlockQuotes.last() !== this) {
      return
    }

    val style = p.style
    val color = p.color

    val spannedText = text as? Spanned
    val quoteIndent = enrichedStyle.blockquoteStripeWidth + enrichedStyle.blockquoteGapWidth
    activeBlockQuotes.forEachIndexed { index, blockquoteSpan ->
      val quoteOriginX = left + quoteIndent * index
      val listSpan =
        if (spannedText == null) {
          null
        } else {
          listSpanBeforeQuote(spannedText, start, end, blockquoteSpan)
        }

      if (listSpan != null && listSpan.shouldDrawMarkerFromContainedQuote(spannedText, blockquoteSpan, start, end)) {
        p.style = style
        p.color = color
        listSpan.drawListMarker(
          canvas,
          p,
          quoteOriginX,
          1,
          top,
          baseline,
          bottom,
          text,
          start,
          end,
          true,
          null,
        )
      }

      p.style = Paint.Style.FILL
      p.color = enrichedStyle.blockquoteBorderColor
      val listMargin = listSpan?.getLeadingMargin(true) ?: 0
      drawStripe(canvas, p, quoteOriginX + listMargin, top, bottom)
    }

    p.style = style
    p.color = color
  }

  private fun listSpanBeforeQuote(
    spannedText: Spanned,
    start: Int,
    end: Int,
    quoteSpan: EnrichedBlockQuoteSpan,
  ): EnrichedListSpan? =
    spannedText
      .getSpans(start, end, EnrichedListSpan::class.java)
      .filter { listSpan -> listSpan.reservesMarginBeforeContainedQuote(spannedText, quoteSpan) }
      .maxWithOrNull(
        compareBy<EnrichedListSpan> { listSpan -> listSpan.level }
          .thenBy { listSpan -> spannedText.getSpanStart(listSpan) }
          .thenBy { listSpan -> listSpan.listMarkerIndex(spannedText) },
      )

  private fun activeBlockQuotes(
    text: CharSequence?,
    start: Int,
    end: Int,
  ): List<EnrichedBlockQuoteSpan> {
    val spannedText = text as? Spanned ?: return emptyList()
    val contentIndex = firstVisibleContentIndex(text, start, end)

    return spannedText
      .getSpans(start, end, EnrichedBlockQuoteSpan::class.java)
      .filter { blockquoteSpan ->
        val spanStart = spannedText.getSpanStart(blockquoteSpan)
        val spanEnd = spannedText.getSpanEnd(blockquoteSpan)
        if (spanStart < 0 || spanEnd < 0) {
          return@filter false
        }

        if (contentIndex >= 0) {
          spanStart <= contentIndex && spanEnd > contentIndex
        } else {
          spanStart < end && spanEnd > start
        }
      }.sortedWith { left, right ->
        val leftStart = spannedText.getSpanStart(left)
        val rightStart = spannedText.getSpanStart(right)
        if (leftStart != rightStart) {
          return@sortedWith leftStart - rightStart
        }

        val leftEnd = spannedText.getSpanEnd(left)
        val rightEnd = spannedText.getSpanEnd(right)
        rightEnd - leftEnd
      }
  }

  private fun drawableActiveBlockQuotes(
    text: CharSequence,
    start: Int,
    end: Int,
  ): List<EnrichedBlockQuoteSpan> {
    val activeBlockQuotes = activeBlockQuotes(text, start, end)
    if (activeBlockQuotes.isEmpty() || hasVisibleContent(text, start, end)) {
      return activeBlockQuotes
    }

    val nextContentIndex = nextVisibleContentIndex(text, end)
    if (nextContentIndex < 0) {
      return emptyList()
    }

    val nextActiveBlockQuotes = activeBlockQuotes(text, nextContentIndex, nextContentIndex + 1)
    return activeBlockQuotes
      .zip(nextActiveBlockQuotes)
      .takeWhile { (current, next) -> current === next }
      .map { (current, _) -> current }
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

  private fun collapseLineHeight(fm: Paint.FontMetricsInt) {
    fm.ascent = 0
    fm.top = 0
    fm.descent = 0
    fm.bottom = 0
  }

  private fun hasNestedLayoutMarker(
    text: Spanned,
    start: Int,
    end: Int,
  ): Boolean =
    text.getSpans(start, end, EnrichedListSpan::class.java).isNotEmpty() ||
      text.getSpans(start, end, EnrichedCodeBlockSpan::class.java).isNotEmpty()

  private fun isFirstLineOfParagraph(
    text: CharSequence,
    start: Int,
  ): Boolean = start <= 0 || text[start - 1] == '\n'

  private fun isLastLineOfParagraph(
    text: CharSequence,
    end: Int,
  ): Boolean =
    end >= text.length ||
      (end > 0 && text[end - 1] == '\n') ||
      text[end] == '\n'

  private fun quoteParagraphSpacing(): Int = ceil(PixelUtil.toPixelFromSP(QUOTE_PARAGRAPH_SPACING_SP)).toInt()

  private fun drawStripe(
    canvas: Canvas,
    paint: Paint,
    stripeX: Int,
    top: Int,
    bottom: Int,
  ) {
    val stripeEnd = stripeX + enrichedStyle.blockquoteStripeWidth
    canvas.drawRect(
      minOf(stripeX, stripeEnd).toFloat(),
      top.toFloat(),
      maxOf(stripeX, stripeEnd).toFloat(),
      bottom.toFloat(),
      paint,
    )
  }

  private fun nextVisibleContentIndex(
    text: CharSequence,
    end: Int,
  ): Int {
    var index = end
    while (index < text.length && (text[index] == EnrichedConstants.ZWS || Character.isWhitespace(text[index]))) {
      index++
    }
    return if (index < text.length) index else -1
  }

  override fun updateDrawState(textPaint: TextPaint?) {
    val color = enrichedStyle.blockquoteColor
    if (color != null) {
      textPaint?.color = color
    }
  }

  private companion object {
    private const val QUOTE_PARAGRAPH_SPACING_SP = 12.0
  }
}
