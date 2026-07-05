package com.swmansion.enriched.textinput.spans

import com.swmansion.enriched.common.spans.EnrichedOrderedListSpan
import com.swmansion.enriched.textinput.spans.interfaces.EnrichedInputSpan
import com.swmansion.enriched.textinput.styles.HtmlStyle

class EnrichedInputOrderedListSpan(
  index: Int,
  htmlStyle: HtmlStyle,
  level: Int = 0,
  markerStart: Int = -1,
  enclosingBlockQuoteDepth: Int = 0,
) : EnrichedOrderedListSpan(
    index,
    htmlStyle,
    level,
    markerStart,
    enclosingBlockQuoteDepth,
  ),
  EnrichedInputSpan {
  override val dependsOnHtmlStyle: Boolean = true

  override fun rebuildWithStyle(htmlStyle: HtmlStyle): EnrichedInputOrderedListSpan =
    EnrichedInputOrderedListSpan(index, htmlStyle, level, markerStart, enclosingBlockQuoteDepth)

  fun getListIndex(): Int = index

  fun setListIndex(i: Int) {
    index = i
  }
}
