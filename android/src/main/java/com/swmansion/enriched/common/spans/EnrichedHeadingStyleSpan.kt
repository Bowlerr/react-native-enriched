package com.swmansion.enriched.common.spans

import android.graphics.Typeface
import android.text.TextPaint
import android.text.style.AbsoluteSizeSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedHeadingSpan

open class EnrichedHeadingStyleSpan(
  fontSize: Int,
  private val bold: Boolean,
) : AbsoluteSizeSpan(fontSize),
  EnrichedHeadingSpan {
  override fun updateMeasureState(textPaint: TextPaint) {
    super.updateMeasureState(textPaint)
    applyHeadingTypeface(textPaint)
  }

  override fun updateDrawState(textPaint: TextPaint) {
    super.updateDrawState(textPaint)
    applyHeadingTypeface(textPaint)
  }

  private fun applyHeadingTypeface(textPaint: TextPaint) {
    if (bold) {
      textPaint.typeface = Typeface.create(textPaint.typeface, Typeface.BOLD)
    }
  }
}
