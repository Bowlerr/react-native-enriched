package com.swmansion.enriched.common.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan

class EnrichedCollapsedLineHeightSpan : LineHeightSpan {
  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    fm.ascent = 0
    fm.top = 0
    fm.descent = 0
    fm.bottom = 0
  }
}
