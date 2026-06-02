package com.swmansion.enriched.common.spans

import com.swmansion.enriched.common.EnrichedStyle

open class EnrichedH5Span(
  enrichedStyle: EnrichedStyle,
) : EnrichedHeadingStyleSpan(enrichedStyle.h5FontSize, enrichedStyle.h5Bold)
