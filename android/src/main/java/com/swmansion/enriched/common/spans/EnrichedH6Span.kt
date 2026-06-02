package com.swmansion.enriched.common.spans

import com.swmansion.enriched.common.EnrichedStyle

open class EnrichedH6Span(
  enrichedStyle: EnrichedStyle,
) : EnrichedHeadingStyleSpan(enrichedStyle.h6FontSize, enrichedStyle.h6Bold)
