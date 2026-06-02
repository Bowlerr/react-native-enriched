package com.swmansion.enriched.common.spans

import com.swmansion.enriched.common.EnrichedStyle

open class EnrichedH1Span(
  enrichedStyle: EnrichedStyle,
) : EnrichedHeadingStyleSpan(enrichedStyle.h1FontSize, enrichedStyle.h1Bold)
