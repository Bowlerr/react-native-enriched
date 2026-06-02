package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LineBackgroundSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

open class EnrichedCodeBlockSpan(
  private val enrichedStyle: EnrichedStyle,
) : MetricAffectingSpan(),
  LineBackgroundSpan,
  EnrichedBlockSpan {
  override fun updateDrawState(paint: TextPaint) {
    paint.typeface = Typeface.MONOSPACE
    paint.color = enrichedStyle.codeBlockColor
  }

  override fun updateMeasureState(paint: TextPaint) {
    paint.typeface = Typeface.MONOSPACE
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
    val isFirstLineOfSpan = start == spanStart
    val isLastLineOfSpan = end == spanEnd || (spanEnd + 1 == end && text[spanEnd] == '\n')

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
    val rect = RectF(backgroundLeft, top.toFloat(), right.toFloat(), bottom.toFloat())

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
    val listInset = parentListContentIndent(text, start, end)
    if (listInset <= 0) {
      return left.toFloat()
    }

    val insetLeft = left + listInset - CODE_BLOCK_HORIZONTAL_PADDING
    val maxLeft = (right - 1).coerceAtLeast(left)
    return insetLeft.coerceIn(left, maxLeft).toFloat()
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

  companion object {
    private const val CODE_BLOCK_HORIZONTAL_PADDING = 12
  }
}
