package com.swmansion.enriched.common.spans.interfaces

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.style.LeadingMarginSpan

interface EnrichedListSpan :
  EnrichedParagraphSpan,
  LeadingMarginSpan {
  var level: Int
  var markerStart: Int
  var enclosingBlockQuoteDepth: Int

  val drawsMarkerForEmptyContent: Boolean
    get() = true

  fun drawListMarker(
    canvas: Canvas,
    paint: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  )
}
