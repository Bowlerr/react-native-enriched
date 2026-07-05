package com.swmansion.enriched.text.spans

import com.swmansion.enriched.common.spans.EnrichedBlockQuoteSpan
import com.swmansion.enriched.text.EnrichedTextStyle
import com.swmansion.enriched.text.spans.interfaces.EnrichedTextSpan

class EnrichedTextBlockQuoteSpan(
  enrichedStyle: EnrichedTextStyle,
  quoteDepth: Int = 0,
) : EnrichedBlockQuoteSpan(enrichedStyle, quoteDepth),
  EnrichedTextSpan {
  override val collapsesInvisibleContent = true
  override val dependsOnHtmlStyle = true

  override fun rebuildWithStyle(style: EnrichedTextStyle) = EnrichedTextBlockQuoteSpan(style, quoteDepth)
}
