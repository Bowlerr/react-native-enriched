package com.swmansion.enriched.common.spans

import com.swmansion.enriched.common.EnrichedStyle

open class EnrichedH4Span(
  enrichedStyle: EnrichedStyle,
) : EnrichedHeadingStyleSpan(enrichedStyle.h4FontSize, enrichedStyle.h4Bold)
