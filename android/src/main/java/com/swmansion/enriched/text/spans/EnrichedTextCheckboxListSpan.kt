package com.swmansion.enriched.text.spans

import com.swmansion.enriched.common.spans.EnrichedCheckboxListSpan
import com.swmansion.enriched.text.EnrichedTextStyle
import com.swmansion.enriched.text.spans.interfaces.EnrichedTextSpan

class EnrichedTextCheckboxListSpan(
  override var isChecked: Boolean,
  enrichedStyle: EnrichedTextStyle,
  level: Int = 0,
  markerStart: Int = -1,
  enclosingBlockQuoteDepth: Int = 0,
) : EnrichedCheckboxListSpan(
    isChecked,
    enrichedStyle,
    level,
    markerStart,
    enclosingBlockQuoteDepth,
  ),
  EnrichedTextSpan {
  override val dependsOnHtmlStyle: Boolean = true
  override val drawsMarkerForEmptyContent = false
  override val collapsesInvisibleContent = true

  override fun rebuildWithStyle(style: EnrichedTextStyle): EnrichedTextCheckboxListSpan =
    EnrichedTextCheckboxListSpan(isChecked, style, level, markerStart, enclosingBlockQuoteDepth)
}
