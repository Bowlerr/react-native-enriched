package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import androidx.core.graphics.withTranslation
import com.swmansion.enriched.common.CheckboxDrawable
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

open class EnrichedCheckboxListSpan(
  open var isChecked: Boolean,
  private val enrichedStyle: EnrichedStyle,
  override var level: Int = 0,
) : MetricAffectingSpan(),
  LineHeightSpan,
  LeadingMarginSpan,
  EnrichedListSpan {
  private val checkboxDrawable =
    CheckboxDrawable(enrichedStyle.ulCheckboxBoxSize, enrichedStyle.ulCheckboxBoxColor, isChecked).apply {
      setBounds(0, 0, enrichedStyle.ulCheckboxBoxSize, enrichedStyle.ulCheckboxBoxSize)
    }

  override fun updateMeasureState(tp: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  override fun updateDrawState(tp: TextPaint) {
    // Do nothing, but inform layout that this span affects text metrics
  }

  // Include checkbox size in text measurements to avoid clipping
  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    val checkboxSize = enrichedStyle.ulCheckboxBoxSize
    val currentLineHeight = fm.descent - fm.ascent

    if (checkboxSize > currentLineHeight) {
      val extraSpace = checkboxSize - currentLineHeight
      val halfExtra = extraSpace / 2

      fm.ascent -= halfExtra
      fm.descent += (extraSpace - halfExtra)

      fm.top -= halfExtra
      fm.bottom += (extraSpace - halfExtra)
    }
  }

  override fun getLeadingMargin(first: Boolean): Int = enrichedStyle.ulCheckboxBoxSize + listMargin() + enrichedStyle.ulCheckboxGapWidth

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
    if (shouldDrawListMarker(text, start, end, first)) {
      checkboxDrawable.update(isChecked)

      val fm = paint.fontMetricsInt
      val textCenter = baseline + (fm.ascent + fm.descent) / 2f
      val drawableTop = textCenter - (enrichedStyle.ulCheckboxBoxSize / 2f)
      val continuationOffset = blockquoteContinuationOffset(text, start, end)

      canvas.withTranslation(x.toFloat() + listMargin() - continuationOffset, drawableTop) {
        checkboxDrawable.draw(this)
      }
    }
  }

  private fun blockquoteContinuationOffset(
    text: CharSequence,
    start: Int,
    end: Int,
  ): Int =
    if (isBlockQuoteContinuationMarker(text, start, end)) {
      enrichedStyle.blockquoteStripeWidth + enrichedStyle.blockquoteGapWidth
    } else {
      0
    }

  private fun listMargin(): Int = enrichedStyle.ulCheckboxMarginLeft * (level.coerceAtLeast(0) + 1)
}
