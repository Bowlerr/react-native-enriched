package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.LineBackgroundSpan
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

open class EnrichedCodeBlockSpan(
  private val enrichedStyle: EnrichedStyle,
) : MetricAffectingSpan(),
  LeadingMarginSpan,
  LineHeightSpan,
  LineBackgroundSpan,
  EnrichedBlockSpan {
  override fun updateDrawState(paint: TextPaint) {
    paint.typeface = Typeface.MONOSPACE
    paint.color = enrichedStyle.codeBlockColor
  }

  override fun updateMeasureState(paint: TextPaint) {
    paint.typeface = Typeface.MONOSPACE
  }

  override fun getLeadingMargin(first: Boolean): Int = CODE_BLOCK_HORIZONTAL_PADDING

  override fun drawLeadingMargin(
    c: Canvas,
    p: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence,
    start: Int,
    end: Int,
    first: Boolean,
    layout: android.text.Layout?,
  ) {
    // LeadingMarginSpan is used only to create internal codeblock padding.
  }

  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    if (text !is Spanned) {
      return
    }

    val spanStart = text.getSpanStart(this)
    val spanEnd = text.getSpanEnd(this)
    if (spanStart < 0 || spanEnd < 0) {
      return
    }

    if (isFirstLineOfSpan(start, spanStart)) {
      fm.ascent -= CODE_BLOCK_VERTICAL_MARGIN + CODE_BLOCK_VERTICAL_PADDING
      fm.top -= CODE_BLOCK_VERTICAL_MARGIN + CODE_BLOCK_VERTICAL_PADDING
    }

    if (isLastLineOfSpan(text, end, spanEnd)) {
      fm.descent += CODE_BLOCK_VERTICAL_MARGIN + CODE_BLOCK_VERTICAL_PADDING
      fm.bottom += CODE_BLOCK_VERTICAL_MARGIN + CODE_BLOCK_VERTICAL_PADDING
    }
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
    if (text !is Spanned) {
      return
    }

    val previousColor = p.color
    p.color = enrichedStyle.codeBlockBackgroundColor

    val radius = enrichedStyle.codeBlockRadius

    val spanStart = text.getSpanStart(this)
    val spanEnd = text.getSpanEnd(this)
    val isFirstLineOfSpan = isFirstLineOfSpan(start, spanStart)
    val isLastLineOfSpan = isLastLineOfSpan(text, end, spanEnd)

    val path = Path()
    val radii = floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f)

    if (isFirstLineOfSpan) {
      // Top-Left and Top-Right corners
      radii[0] = radius
      radii[1] = radius
      radii[2] = radius
      radii[3] = radius
    }

    if (isLastLineOfSpan) {
      // Bottom-Right and Bottom-Left corners
      radii[4] = radius
      radii[5] = radius
      radii[6] = radius
      radii[7] = radius
    }

    val backgroundLeft = codeBlockBackgroundLeft(text, start, end, left, right)
    val backgroundTop =
      if (isFirstLineOfSpan) {
        top + CODE_BLOCK_VERTICAL_MARGIN
      } else {
        top
      }
    val backgroundBottom =
      if (isLastLineOfSpan) {
        bottom - CODE_BLOCK_VERTICAL_MARGIN
      } else {
        bottom
      }

    if (backgroundBottom <= backgroundTop) {
      p.color = previousColor
      return
    }

    val rect =
      RectF(backgroundLeft, backgroundTop.toFloat(), right.toFloat(), backgroundBottom.toFloat())

    path.addRoundRect(rect, radii, Path.Direction.CW)
    canvas.drawPath(path, p)
    p.color = previousColor
  }

  private fun codeBlockBackgroundLeft(
    text: Spanned,
    start: Int,
    end: Int,
    left: Int,
    right: Int,
  ): Float {
    val blockInset =
      parentBlockQuoteContentIndent(text, start, end) + parentListContentIndent(text, start, end)
    val maxLeft = (right - 1).coerceAtLeast(left)
    if (blockInset <= 0) {
      return (left - CODE_BLOCK_HORIZONTAL_PADDING).coerceIn(0, maxLeft).toFloat()
    }

    val insetLeft = left + blockInset - CODE_BLOCK_HORIZONTAL_PADDING * 2
    return insetLeft.coerceIn(0, maxLeft).toFloat()
  }

  private fun parentBlockQuoteContentIndent(
    text: Spanned,
    start: Int,
    end: Int,
  ): Int {
    val codeBlockStart = text.getSpanStart(this)
    if (codeBlockStart < 0) {
      return 0
    }

    return text
      .getSpans(start, end, EnrichedBlockQuoteSpan::class.java)
      .filter { blockQuoteSpan -> text.getSpanStart(blockQuoteSpan) in 0..codeBlockStart }
      .sumOf { enrichedStyle.blockquoteStripeWidth + enrichedStyle.blockquoteGapWidth }
  }

  private fun parentListContentIndent(
    text: Spanned,
    start: Int,
    end: Int,
  ): Int {
    val codeBlockStart = text.getSpanStart(this)
    if (codeBlockStart < 0) {
      return 0
    }

    return text
      .getSpans(start, end, EnrichedListSpan::class.java)
      .filter { listSpan -> text.getSpanStart(listSpan) in 0..codeBlockStart }
      .maxOfOrNull { listSpan -> listContentIndent(listSpan) }
      ?: 0
  }

  private fun listContentIndent(listSpan: EnrichedListSpan): Int {
    val level = listSpan.level.coerceAtLeast(0) + 1
    return when (listSpan) {
      is EnrichedCheckboxListSpan -> {
        enrichedStyle.ulCheckboxMarginLeft * level + enrichedStyle.ulCheckboxGapWidth +
          enrichedStyle.ulCheckboxBoxSize
      }

      is EnrichedOrderedListSpan -> {
        enrichedStyle.olMarginLeft * level + enrichedStyle.olGapWidth
      }

      is EnrichedUnorderedListSpan -> {
        enrichedStyle.ulMarginLeft * level + enrichedStyle.ulGapWidth + enrichedStyle.ulBulletSize
      }

      else -> {
        0
      }
    }
  }

  private fun isFirstLineOfSpan(
    start: Int,
    spanStart: Int,
  ): Boolean = start == spanStart

  private fun isLastLineOfSpan(
    text: CharSequence,
    end: Int,
    spanEnd: Int,
  ): Boolean = end == spanEnd || (spanEnd < text.length && spanEnd + 1 == end && text[spanEnd] == '\n')

  companion object {
    private const val CODE_BLOCK_HORIZONTAL_PADDING = 12
    private const val CODE_BLOCK_VERTICAL_MARGIN = 3
    private const val CODE_BLOCK_VERTICAL_PADDING = 6
  }
}
