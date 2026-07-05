package com.swmansion.enriched.common.spans

import android.graphics.Paint
import android.graphics.Typeface
import android.text.Spanned
import android.text.TextPaint
import android.text.style.AbsoluteSizeSpan
import android.text.style.LineHeightSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedHeadingSpan
import kotlin.math.ceil
import kotlin.math.floor

open class EnrichedHeadingStyleSpan(
  private val fontSize: Int,
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

  fun createLineHeightSpan(): LineHeightSpan = EnrichedHeadingLineHeightSpan(fontSize)

  private fun applyHeadingTypeface(textPaint: TextPaint) {
    if (bold) {
      val currentStyle = textPaint.typeface?.style ?: Typeface.NORMAL
      textPaint.typeface = Typeface.create(textPaint.typeface, currentStyle or Typeface.BOLD)
    }
  }
}

private class EnrichedHeadingLineHeightSpan(
  private val fontSize: Int,
) : LineHeightSpan {
  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    if (fontSize <= 0) return
    if (hasNestedLineHeightOwner(text, start, end)) return

    val targetLineHeight = ceil(fontSize * LINE_HEIGHT_MULTIPLIER).toInt()
    val currentLineHeight = -fm.ascent + fm.descent
    val delta = targetLineHeight - currentLineHeight
    fm.ascent -= ceil(delta / 2f).toInt()
    fm.descent += floor(delta / 2f).toInt()
    clampOuterFontPadding(fm)
  }

  private fun clampOuterFontPadding(fm: Paint.FontMetricsInt) {
    fm.top = fm.top.coerceAtLeast(fm.ascent)
    fm.bottom = fm.bottom.coerceAtMost(fm.descent)
  }

  private fun hasNestedLineHeightOwner(
    text: CharSequence,
    start: Int,
    end: Int,
  ): Boolean {
    val spannedText = text as? Spanned ?: return false
    return spannedText.getSpans(start, end, EnrichedBlockQuoteSpan::class.java).isNotEmpty() ||
      spannedText.getSpans(start, end, EnrichedCodeBlockSpan::class.java).isNotEmpty() ||
      spannedText.getSpans(start, end, EnrichedCheckboxListSpan::class.java).isNotEmpty()
  }

  companion object {
    private const val LINE_HEIGHT_MULTIPLIER = 1.18f
  }
}
