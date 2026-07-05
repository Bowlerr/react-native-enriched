package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedUnorderedListSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputUnorderedListSpan(
  htmlStyle: HtmlStyle,
  level: Int = 0,
  markerStart: Int = -1,
  enclosingBlockQuoteDepth: Int = 0,
) : EnrichedUnorderedListSpan(
    htmlStyle,
    level,
    markerStart,
    enclosingBlockQuoteDepth,
  ),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = true

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputUnorderedListSpan =
    EnrichedInputUnorderedListSpan(htmlStyle, level, markerStart, enclosingBlockQuoteDepth)
}
