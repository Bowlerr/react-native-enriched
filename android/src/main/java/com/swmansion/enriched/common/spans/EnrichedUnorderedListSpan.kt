package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

// https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/text/style/BulletSpan.java
open class EnrichedUnorderedListSpan(
  private val enrichedStyle: EnrichedStyle,
  override var level: Int = 0,
) : MetricAffectingSpan(),
  LeadingMarginSpan,
  EnrichedListSpan {
  override fun updateMeasureState(p0: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun updateDrawState(p0: TextPaint?) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun getLeadingMargin(p0: Boolean): Int = enrichedStyle.ulBulletSize + enrichedStyle.ulGapWidth + listMargin()

  override fun drawLeadingMargin(
    canvas: Canvas,
    paint: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  ) {
    val spannedText = text as Spanned

    if (spannedText.getSpanStart(this) == start) {
      val style = paint.style
      val oldColor = paint.color
      paint.color = enrichedStyle.ulBulletColor
      paint.style = Paint.Style.FILL

      val bulletRadius = enrichedStyle.ulBulletSize / 2f
      val fm = paint.fontMetricsInt
      val yPosition = baseline + (fm.ascent + fm.descent) / 2f
      val xPosition = x + dir * (bulletRadius + listMargin())

      canvas.drawCircle(xPosition, yPosition, bulletRadius, paint)

      paint.color = oldColor
      paint.style = style
    }
  }

  private fun listMargin(): Int = enrichedStyle.ulMarginLeft * (level.coerceAtLeast(0) + 1)
}
