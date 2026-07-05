package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedBlockQuoteSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputBlockQuoteSpan(
  htmlStyle: HtmlStyle,
  quoteDepth: Int = 0,
) : EnrichedBlockQuoteSpan(htmlStyle, quoteDepth),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = true

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputBlockQuoteSpan = EnrichedInputBlockQuoteSpan(htmlStyle, quoteDepth)
}
