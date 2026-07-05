package com.swmansion.enriched.text.spans

import com.swmansion.enriched.common.EnrichedStyle
import com.swmansion.enriched.common.spans.EnrichedUnorderedListSpan
import com.swmansion.enriched.text.EnrichedTextStyle
import com.swmansion.enriched.text.spans.interfaces.EnrichedTextSpan

class EnrichedTextUnorderedListSpan(
  enrichedStyle: EnrichedStyle,
  level: Int = 0,
  markerStart: Int = -1,
  enclosingBlockQuoteDepth: Int = 0,
) : EnrichedUnorderedListSpan(
    enrichedStyle,
    level,
    markerStart,
    enclosingBlockQuoteDepth,
  ),
  EnrichedTextSpan {
  override val dependsOnHtmlStyle = true
  override val drawsMarkerForEmptyContent = false
  override val collapsesInvisibleContent = true

  override fun rebuildWithStyle(style: EnrichedTextStyle) =
    EnrichedTextUnorderedListSpan(style, level, markerStart, enclosingBlockQuoteDepth)
}
