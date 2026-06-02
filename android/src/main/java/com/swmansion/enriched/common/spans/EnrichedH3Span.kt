package com.swmansion.enriched.common.spans

import com.swmansion.enriched.common.EnrichedStyle

open class EnrichedH3Span(
  enrichedStyle: EnrichedStyle,
) : EnrichedHeadingStyleSpan(enrichedStyle.h3FontSize, enrichedStyle.h3Bold)
