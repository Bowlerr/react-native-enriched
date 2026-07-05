package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedCollapsibleLayoutSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

open class EnrichedOrderedListSpan(
  var index: Int,
  private val enrichedStyle: EnrichedStyle,
  override var level: Int = 0,
  override var markerStart: Int = -1,
  override var enclosingBlockQuoteDepth: Int = 0,
) : MetricAffectingSpan(),
  LeadingMarginSpan,
  EnrichedListSpan,
  EnrichedCollapsibleLayoutSpan {
  override val collapsesInvisibleContent = false

  override fun updateMeasureState(p0: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun updateDrawState(p0: TextPaint?) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun getLeadingMargin(first: Boolean): Int = listMargin() + enrichedStyle.olGapWidth

  override fun drawLeadingMargin(
    canvas: Canvas,
    paint: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    t: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  ) {
    if (shouldDrawListMarker(t, start, end, first)) {
      drawListMarker(
        canvas,
        paint,
        x,
        dir,
        top,
        baseline,
        bottom,
        t,
        start,
        end,
        first,
        layout,
      )
    }
  }

  override fun drawListMarker(
    canvas: Canvas,
    paint: Paint,
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
    val markerText = "$index."
    val width = paint.measureText(markerText)

    val yPosition = baseline.toFloat()
    val xPosition = x + dir * (listMargin() - width / 2)

    val originalColor = paint.color
    val originalTypeface = paint.typeface

    paint.color = enrichedStyle.olMarkerColor ?: originalColor
    paint.typeface = getTypeface(enrichedStyle.olMarkerFontWeight, originalTypeface)
    canvas.drawText(markerText, xPosition, yPosition, paint)

    paint.color = originalColor
    paint.typeface = originalTypeface
  }

  private fun getTypeface(
    fontWeight: Int?,
    originalTypeface: Typeface,
  ): Typeface =
    if (fontWeight == null) {
      originalTypeface
    } else if (Build.VERSION.SDK_INT >= 28) {
      Typeface.create(originalTypeface, fontWeight, false)
    } else {
      // Fallback for API < 28: only bold/normal supported
      if (fontWeight == Typeface.BOLD) {
        Typeface.create(originalTypeface, Typeface.BOLD)
      } else {
        Typeface.create(originalTypeface, Typeface.NORMAL)
      }
    }

  private fun listMargin(): Int = enrichedStyle.olMarginLeft * (level.coerceAtLeast(0) + 1)
}
