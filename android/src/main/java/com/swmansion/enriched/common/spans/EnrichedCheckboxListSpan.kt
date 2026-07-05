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
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.interfaces.EnrichedCollapsibleLayoutSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedListSpan

open class EnrichedCheckboxListSpan(
  open var isChecked: Boolean,
  private val enrichedStyle: EnrichedStyle,
  override var level: Int = 0,
  override var markerStart: Int = -1,
  override var enclosingBlockQuoteDepth: Int = 0,
) : MetricAffectingSpan(),
  LineHeightSpan,
  LeadingMarginSpan,
  EnrichedListSpan,
  EnrichedCollapsibleLayoutSpan {
  override val collapsesInvisibleContent = false

  private val checkboxDrawable =
    CheckboxDrawable(
      enrichedStyle.ulCheckboxBoxSize,
      enrichedStyle.ulCheckboxBoxColor,
      isChecked,
    ).apply {
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
    if (collapsesInvisibleContent && !hasVisibleContent(text, start, end)) {
      collapseLineHeight(fm)
      return
    }

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
      drawListMarker(
        canvas,
        paint,
        x,
        dir,
        top,
        baseline,
        bottom,
        text,
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
    checkboxDrawable.update(isChecked)

    val fm = paint.fontMetricsInt
    val textCenter = baseline + (fm.ascent + fm.descent) / 2f
    val drawableTop = textCenter - (enrichedStyle.ulCheckboxBoxSize / 2f)

    canvas.withTranslation(x.toFloat() + dir * listMargin(), drawableTop) {
      checkboxDrawable.draw(this)
    }
  }

  private fun listMargin(): Int = enrichedStyle.ulCheckboxMarginLeft * (level.coerceAtLeast(0) + 1)

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

  private fun collapseLineHeight(fm: Paint.FontMetricsInt) {
    fm.ascent = 0
    fm.top = 0
    fm.descent = 0
    fm.bottom = 0
  }
}
