#import "LayoutManagerExtension.h"
#import "ColorExtension.h"
#import "EnrichedViewHost.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "WeakBox.h"
#import <objc/runtime.h>

@implementation NSLayoutManager (LayoutManagerExtension)

static void const *kInputKey = &kInputKey;

static BOOL EnrichedListMarkerMatches(NSString *markerFormat,
                                      NSString *baseValue) {
  return markerFormat != nullptr &&
         ([markerFormat isEqualToString:baseValue] ||
          [markerFormat
              hasPrefix:[baseValue stringByAppendingString:@":"]]);
}

static BOOL EnrichedLayoutListMarkerMatches(NSString *markerFormat,
                                            NSString *baseValue) {
  if (markerFormat == nullptr) {
    return NO;
  }

  NSString *continuationBaseValue =
      [baseValue stringByAppendingString:@"Continuation"];
  return EnrichedListMarkerMatches(markerFormat, baseValue) ||
         [markerFormat isEqualToString:continuationBaseValue] ||
         [markerFormat
             hasPrefix:[continuationBaseValue stringByAppendingString:@":"]];
}

static BOOL EnrichedIsListContinuationMarker(NSString *markerFormat) {
  return markerFormat != nullptr &&
         ([markerFormat hasPrefix:@"EnrichedUnorderedListContinuation"] ||
          [markerFormat hasPrefix:@"EnrichedOrderedListContinuation"]);
}

static BOOL EnrichedAnyListMarkerMatches(NSString *markerFormat) {
  return EnrichedLayoutListMarkerMatches(markerFormat,
                                         @"EnrichedUnorderedList") ||
         EnrichedLayoutListMarkerMatches(markerFormat, @"EnrichedOrderedList") ||
         [markerFormat hasPrefix:@"EnrichedCheckbox"];
}

static NSInteger EnrichedListMarkerLevel(NSString *markerFormat) {
  NSRange separator = [markerFormat rangeOfString:@":"];
  if (separator.location == NSNotFound) {
    return 0;
  }
  NSString *levelString =
      [markerFormat substringFromIndex:separator.location + separator.length];
  return MAX(0, [levelString integerValue]);
}

static NSString *EnrichedDeepestListMarker(NSParagraphStyle *pStyle) {
  NSString *markerFormat = nil;
  NSInteger markerLevel = -1;
  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (!EnrichedAnyListMarkerMatches(candidate)) {
      continue;
    }
    NSInteger candidateLevel = EnrichedListMarkerLevel(candidate);
    if (candidateLevel >= markerLevel) {
      markerFormat = candidate;
      markerLevel = candidateLevel;
    }
  }
  return markerFormat;
}

static NSString *EnrichedDeepestDrawableListMarker(NSParagraphStyle *pStyle) {
  NSString *markerFormat = nil;
  NSInteger markerLevel = -1;
  BOOL blockQuoteBeforeMarker = NO;

  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (EnrichedListMarkerMatches(candidate, @"EnrichedBlockQuote")) {
      blockQuoteBeforeMarker = YES;
      continue;
    }

    if (!EnrichedAnyListMarkerMatches(candidate) ||
        EnrichedIsListContinuationMarker(candidate) ||
        blockQuoteBeforeMarker) {
      continue;
    }

    NSInteger candidateLevel = EnrichedListMarkerLevel(candidate);
    if (candidateLevel >= markerLevel) {
      markerFormat = candidate;
      markerLevel = candidateLevel;
    }
  }
  return markerFormat;
}

static CGFloat EnrichedListContentIndentForMarker(id<EnrichedViewHost> host,
                                                  NSString *markerFormat) {
  if (markerFormat == nil) {
    return 0.0;
  }

  NSInteger level = EnrichedListMarkerLevel(markerFormat);
  if (EnrichedLayoutListMarkerMatches(markerFormat,
                                      @"EnrichedUnorderedList")) {
    return [host.config unorderedListMarginLeft] * (level + 1) +
           [host.config unorderedListGapWidth];
  }

  if (EnrichedLayoutListMarkerMatches(markerFormat, @"EnrichedOrderedList")) {
    return [host.config orderedListMarginLeft] * (level + 1) +
           [host.config orderedListGapWidth];
  }

  if ([markerFormat hasPrefix:@"EnrichedCheckbox"]) {
    return [host.config checkboxListMarginLeft] * (level + 1) +
           [host.config checkboxListGapWidth];
  }

  return 0.0;
}

static BOOL EnrichedParagraphHasBlockQuote(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    if (EnrichedListMarkerMatches(textList.markerFormat,
                                  @"EnrichedBlockQuote")) {
      return YES;
    }
  }
  return NO;
}

static NSString *EnrichedBlockQuoteMarker(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (EnrichedListMarkerMatches(markerFormat, @"EnrichedBlockQuote")) {
      return markerFormat;
    }
  }
  return nil;
}

static BOOL EnrichedParagraphHasVisibleContent(NSString *text, NSRange range) {
  if (range.location >= text.length) {
    return NO;
  }

  NSUInteger safeLength = MIN(range.length, text.length - range.location);
  NSString *paragraph =
      [text substringWithRange:NSMakeRange(range.location, safeLength)];
  NSMutableString *normalized = [paragraph mutableCopy];
  [normalized replaceOccurrencesOfString:@"\u200B"
                              withString:@""
                                 options:0
                                   range:NSMakeRange(0, normalized.length)];
  [normalized replaceOccurrencesOfString:@"\uFFFC"
                              withString:@""
                                 options:0
                                   range:NSMakeRange(0, normalized.length)];

  NSString *trimmed = [normalized
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  return trimmed.length > 0;
}

static BOOL EnrichedIsDecorativeEdgeCharacter(unichar character) {
  return [[NSCharacterSet whitespaceAndNewlineCharacterSet]
             characterIsMember:character] ||
         character == 0x200B || character == 0xFFFC;
}

static NSRange EnrichedTrimDecorativeRangeEdges(NSString *text, NSRange range) {
  if (range.location >= text.length || range.length == 0) {
    return NSMakeRange(range.location, 0);
  }

  NSUInteger start = range.location;
  NSUInteger end = MIN(NSMaxRange(range), text.length);
  while (start < end &&
         EnrichedIsDecorativeEdgeCharacter([text characterAtIndex:start])) {
    start++;
  }

  while (end > start &&
         EnrichedIsDecorativeEdgeCharacter([text characterAtIndex:end - 1])) {
    end--;
  }

  return NSMakeRange(start, end - start);
}

static CGFloat EnrichedGlyphContainerX(NSLayoutManager *layoutManager,
                                       CGRect lineRect,
                                       CGRect lineUsedRect,
                                       NSUInteger glyphIndex) {
  CGPoint location = [layoutManager locationForGlyphAtIndex:glyphIndex];
  CGFloat x = lineRect.origin.x + location.x;
  CGFloat minReasonableX = MIN(lineRect.origin.x, lineUsedRect.origin.x) - 4.0;
  CGFloat maxReasonableX =
      MAX(CGRectGetMaxX(lineRect), CGRectGetMaxX(lineUsedRect)) + 4.0;

  // `locationForGlyphAtIndex:` is documented as line-fragment-relative, but
  // keep a defensive fallback for any layout manager that returns container
  // coordinates directly.
  if (x < minReasonableX || x > maxReasonableX) {
    x = location.x;
  }
  return x;
}

static CGRect EnrichedTightGlyphRectForLine(NSLayoutManager *layoutManager,
                                            NSTextContainer *textContainer,
                                            CGRect lineRect,
                                            CGRect lineUsedRect,
                                            NSRange glyphRange) {
  CGRect glyphRect = [layoutManager boundingRectForGlyphRange:glyphRange
                                              inTextContainer:textContainer];
  if (CGRectIsEmpty(glyphRect)) {
    return glyphRect;
  }

  CGFloat minX = EnrichedGlyphContainerX(layoutManager, lineRect, lineUsedRect,
                                         glyphRange.location);
  NSUInteger lastGlyphIndex = NSMaxRange(glyphRange) - 1;
  CGRect lastGlyphRect =
      [layoutManager boundingRectForGlyphRange:NSMakeRange(lastGlyphIndex, 1)
                               inTextContainer:textContainer];
  CGFloat maxX = CGRectGetMaxX(glyphRect);

  if (!CGRectIsEmpty(lastGlyphRect)) {
    maxX = CGRectGetMaxX(lastGlyphRect);
  } else if (lastGlyphIndex + 1 < layoutManager.numberOfGlyphs) {
    maxX = EnrichedGlyphContainerX(layoutManager, lineRect, lineUsedRect,
                                   lastGlyphIndex + 1);
  }

  CGFloat lineMinX = lineUsedRect.origin.x;
  CGFloat lineMaxX = CGRectGetMaxX(lineUsedRect);
  minX = MIN(MAX(minX, lineMinX), lineMaxX);
  maxX = MIN(MAX(maxX, minX), lineMaxX);
  glyphRect.origin.x = minX;
  glyphRect.size.width = maxX - minX;

  return glyphRect;
}

- (id)input {
  WeakBox *box = objc_getAssociatedObject(self, kInputKey);
  return box.value;
}

- (void)setInput:(id)value {
  WeakBox *box = [WeakBox new];
  box.value = value;
  objc_setAssociatedObject(self, kInputKey, box,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class myClass = [NSLayoutManager class];
    SEL originalSelector = @selector(drawBackgroundForGlyphRange:atPoint:);
    SEL swizzledSelector = @selector(my_drawBackgroundForGlyphRange:atPoint:);
    Method originalMethod = class_getInstanceMethod(myClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(myClass, swizzledSelector);

    BOOL didAddMethod = class_addMethod(
        myClass, originalSelector, method_getImplementation(swizzledMethod),
        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
      class_replaceMethod(myClass, swizzledSelector,
                          method_getImplementation(originalMethod),
                          method_getTypeEncoding(originalMethod));
    } else {
      method_exchangeImplementations(originalMethod, swizzledMethod);
    }
  });
}

- (void)my_drawBackgroundForGlyphRange:(NSRange)glyphRange
                               atPoint:(CGPoint)origin {
  [self my_drawBackgroundForGlyphRange:glyphRange atPoint:origin];

  id<EnrichedViewHost> host = self.input;
  if (host == nullptr) {
    return;
  }

  NSRange visibleCharRange = [self characterRangeForGlyphRange:glyphRange
                                              actualGlyphRange:NULL];

  [self drawBlockQuotes:host origin:origin visibleCharRange:visibleCharRange];
  [self drawCodeBlocks:host origin:origin visibleCharRange:visibleCharRange];
  [self drawInlineCodes:host origin:origin visibleCharRange:visibleCharRange];
  [self drawLists:host origin:origin visibleCharRange:visibleCharRange];
}

- (void)drawInlineCodes:(id<EnrichedViewHost>)host
                 origin:(CGPoint)origin
       visibleCharRange:(NSRange)visibleCharRange {
  InlineCodeStyle *inlineCodeStyle =
      host.stylesDict[@([InlineCodeStyle getType])];
  if (inlineCodeStyle == nullptr) {
    return;
  }

  UIColor *bgColor =
      [[host.config inlineCodeBgColor] colorWithAlphaIfNotTransparent:0.4];
  CGFloat horizontalPadding = 3.0;
  CGFloat verticalPadding = 1.0;
  CGFloat radius = 4.0;

  for (StylePair *pair in [inlineCodeStyle all:visibleCharRange]) {
    NSRange codeCharacterRange = EnrichedTrimDecorativeRangeEdges(
        host.textView.textStorage.string, [pair.rangeValue rangeValue]);
    if (codeCharacterRange.length == 0) {
      continue;
    }

    NSArray *nonNewlineRanges =
        [RangeUtils getNonNewlineRangesIn:host.textView
                                    range:codeCharacterRange];
    for (NSValue *value in nonNewlineRanges) {
      NSRange nonNewlineRange = [value rangeValue];
      if (nonNewlineRange.length == 0) {
        continue;
      }

      NSRange codeGlyphRange =
          [self glyphRangeForCharacterRange:nonNewlineRange
                       actualCharacterRange:nullptr];
      [self enumerateLineFragmentsForGlyphRange:codeGlyphRange
                                     usingBlock:^(
                                         CGRect rect, CGRect usedRect,
                                         NSTextContainer *_Nonnull textContainer,
                                         NSRange lineGlyphRange,
                                         BOOL *_Nonnull stop) {
                                       NSRange lineCodeGlyphRange =
                                           NSIntersectionRange(codeGlyphRange,
                                                               lineGlyphRange);
                                       if (lineCodeGlyphRange.length == 0) {
                                         return;
                                       }

                                       CGRect glyphRect =
                                           EnrichedTightGlyphRectForLine(
                                               self, textContainer, rect,
                                               usedRect, lineCodeGlyphRange);
                                       if (CGRectIsEmpty(glyphRect)) {
                                         return;
                                       }

                                       CGRect bgRect =
                                           CGRectInset(glyphRect,
                                                       -horizontalPadding,
                                                       -verticalPadding);
                                       bgRect.origin.x = MAX(0.0,
                                                            bgRect.origin.x);
                                       bgRect.origin.y =
                                           MAX(rect.origin.y, bgRect.origin.y);
                                       bgRect = CGRectOffset(bgRect, origin.x,
                                                            origin.y);

                                       UIBezierPath *path =
                                           [UIBezierPath
                                               bezierPathWithRoundedRect:bgRect
                                                            cornerRadius:
                                                                radius];
                                       [bgColor setFill];
                                       [path fill];
                                     }];
    }
  }
}

- (void)drawCodeBlocks:(id<EnrichedViewHost>)host
                origin:(CGPoint)origin
      visibleCharRange:(NSRange)visibleCharRange {
  CodeBlockStyle *codeBlockStyle = host.stylesDict[@([CodeBlockStyle getType])];
  if (codeBlockStyle == nullptr) {
    return;
  }

  NSArray<StylePair *> *allCodeBlocks = [codeBlockStyle all:visibleCharRange];
  NSArray<StylePair *> *mergedCodeBlocks =
      [self mergeContiguousStylePairs:allCodeBlocks];
  UIColor *bgColor =
      [[host.config codeBlockBgColor] colorWithAlphaIfNotTransparent:1.0];
  UIColor *borderColor =
      [[host.config codeBlockFgColor] colorWithAlphaIfNotTransparent:0.25];
  CGFloat radius = [host.config codeBlockBorderRadius];

  for (StylePair *pair in mergedCodeBlocks) {
    NSRange blockCharacterRange = EnrichedTrimDecorativeRangeEdges(
        host.textView.textStorage.string, [pair.rangeValue rangeValue]);
    if (blockCharacterRange.length == 0)
      continue;

    NSRange blockGlyphRange =
        [self glyphRangeForCharacterRange:blockCharacterRange
                     actualCharacterRange:NULL];
    __block CGRect blockRect = CGRectNull;

    [self
        enumerateLineFragmentsForGlyphRange:blockGlyphRange
                                 usingBlock:^(
                                     CGRect rect, CGRect usedRect,
                                     NSTextContainer *_Nonnull textContainer,
                                     NSRange glyphRange,
                                     BOOL *_Nonnull stop) {
                                   CGFloat horizontalPadding = 12.0;
                                   CGFloat verticalPadding = 6.0;
                                   CGFloat minX = MAX(
                                       0.0,
                                       usedRect.origin.x - horizontalPadding);
                                   CGRect lineBgRect = CGRectMake(
                                       origin.x + minX,
                                       origin.y + usedRect.origin.y -
                                           verticalPadding,
                                       MAX(1.0,
                                           textContainer.size.width - minX -
                                               horizontalPadding),
                                       usedRect.size.height +
                                           verticalPadding * 2);

                                   blockRect =
                                       CGRectIsNull(blockRect)
                                           ? lineBgRect
                                           : CGRectUnion(blockRect, lineBgRect);
                                 }];

    if (!CGRectIsNull(blockRect)) {
      UIBezierPath *path =
          [UIBezierPath bezierPathWithRoundedRect:blockRect
                                     cornerRadius:radius];
      path.lineWidth = 1.0 / UIScreen.mainScreen.scale;
      [bgColor setFill];
      [path fill];
      [borderColor setStroke];
      [path stroke];
    }
  }
}

- (NSArray<StylePair *> *)mergeContiguousStylePairs:
    (NSArray<StylePair *> *)pairs {
  if (pairs.count == 0) {
    return @[];
  }

  NSMutableArray<StylePair *> *mergedPairs = [[NSMutableArray alloc] init];
  StylePair *currentPair = pairs[0];
  NSRange currentRange = [currentPair.rangeValue rangeValue];
  for (NSUInteger i = 1; i < pairs.count; i++) {
    StylePair *nextPair = pairs[i];
    NSRange nextRange = [nextPair.rangeValue rangeValue];

    // The Gap Check:
    // NSMaxRange(currentRange) is where the current block ends.
    // nextRange.location is where the next block starts.
    if (NSMaxRange(currentRange) == nextRange.location) {
      // They touch perfectly (no gap). Merge them.
      currentRange.length += nextRange.length;
    } else {
      // There is a gap (indices don't match).
      // 1. Save the finished block.
      StylePair *mergedPair = [[StylePair alloc] init];
      mergedPair.rangeValue = [NSValue valueWithRange:currentRange];
      mergedPair.styleValue = currentPair.styleValue;
      [mergedPairs addObject:mergedPair];

      // 2. Start a brand new block.
      currentPair = nextPair;
      currentRange = nextRange;
    }
  }

  // Add the final block
  StylePair *lastPair = [[StylePair alloc] init];
  lastPair.rangeValue = [NSValue valueWithRange:currentRange];
  lastPair.styleValue = currentPair.styleValue;
  [mergedPairs addObject:lastPair];

  return mergedPairs;
}

- (NSArray<StylePair *> *)mergeContiguousBlockQuoteStylePairs:
    (NSArray<StylePair *> *)pairs {
  if (pairs.count == 0) {
    return @[];
  }

  NSMutableArray<StylePair *> *mergedPairs = [[NSMutableArray alloc] init];
  StylePair *currentPair = pairs[0];
  NSRange currentRange = [currentPair.rangeValue rangeValue];
  NSString *currentMarker =
      EnrichedBlockQuoteMarker((NSParagraphStyle *)currentPair.styleValue);

  for (NSUInteger i = 1; i < pairs.count; i++) {
    StylePair *nextPair = pairs[i];
    NSRange nextRange = [nextPair.rangeValue rangeValue];
    NSString *nextMarker =
        EnrichedBlockQuoteMarker((NSParagraphStyle *)nextPair.styleValue);
    BOOL sameBlockQuote =
        (currentMarker == nil && nextMarker == nil) ||
        [currentMarker isEqualToString:nextMarker];

    if (NSMaxRange(currentRange) == nextRange.location && sameBlockQuote) {
      currentRange.length += nextRange.length;
    } else {
      StylePair *mergedPair = [[StylePair alloc] init];
      mergedPair.rangeValue = [NSValue valueWithRange:currentRange];
      mergedPair.styleValue = currentPair.styleValue;
      [mergedPairs addObject:mergedPair];

      currentPair = nextPair;
      currentRange = nextRange;
      currentMarker = nextMarker;
    }
  }

  StylePair *lastPair = [[StylePair alloc] init];
  lastPair.rangeValue = [NSValue valueWithRange:currentRange];
  lastPair.styleValue = currentPair.styleValue;
  [mergedPairs addObject:lastPair];

  return mergedPairs;
}

- (void)drawBlockQuotes:(id<EnrichedViewHost>)host
                 origin:(CGPoint)origin
       visibleCharRange:(NSRange)visibleCharRange {
  if (host.stylesDict[@([BlockQuoteStyle getType])] == nullptr) {
    return;
  }

  NSAttributedString *textStorage = host.textView.textStorage;
  NSString *text = textStorage.string;
  if (text.length == 0) {
    return;
  }

  void (^drawQuoteRail)(CGRect, CGFloat, CGFloat) =
      ^(CGRect quoteRect, CGFloat topPadding, CGFloat bottomPadding) {
    CGFloat borderWidth = [host.config blockquoteBorderWidth];
    CGFloat x =
        origin.x + quoteRect.origin.x - [host.config blockquoteGapWidth] -
        borderWidth;
    CGRect lineRect =
        CGRectMake(x, origin.y + quoteRect.origin.y - topPadding, borderWidth,
                   quoteRect.size.height + topPadding + bottomPadding);
    [[host.config blockquoteBorderColor] setFill];
    UIRectFill(lineRect);
  };

  NSMutableArray<NSValue *> *quoteRects = [[NSMutableArray alloc] init];
  __block NSString *currentMarker = nil;
  __block CGRect currentQuoteRect = CGRectNull;

  void (^flushCurrentQuote)(void) = ^{
    if (!CGRectIsNull(currentQuoteRect)) {
      [quoteRects addObject:[NSValue valueWithCGRect:currentQuoteRect]];
    }
    currentQuoteRect = CGRectNull;
    currentMarker = nil;
  };

  NSArray *paragraphs = [RangeUtils getSeparateParagraphsRangesIn:host.textView
                                                            range:visibleCharRange];
  for (NSValue *paragraph in paragraphs) {
    NSRange paragraphRange = [paragraph rangeValue];
    if (paragraphRange.location >= textStorage.length) {
      continue;
    }

    NSUInteger styleIndex =
        MIN(paragraphRange.location, textStorage.length - 1);
    NSParagraphStyle *paragraphStyle =
        [textStorage attribute:NSParagraphStyleAttributeName
                        atIndex:styleIndex
                 effectiveRange:nil];
    NSString *quoteMarker = EnrichedBlockQuoteMarker(paragraphStyle);
    if (quoteMarker == nil) {
      flushCurrentQuote();
      continue;
    }

    if (currentMarker != nil && ![currentMarker isEqualToString:quoteMarker]) {
      flushCurrentQuote();
    }
    currentMarker = quoteMarker;

    if (!EnrichedParagraphHasVisibleContent(text, paragraphRange)) {
      continue;
    }

    NSRange paragraphGlyphRange =
        [self glyphRangeForCharacterRange:paragraphRange
                     actualCharacterRange:nullptr];
    __block CGRect paragraphRect = CGRectNull;

    [self enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                   usingBlock:^(
                                       CGRect rect, CGRect usedRect,
                                       NSTextContainer *_Nonnull textContainer,
                                       NSRange glyphRange,
                                       BOOL *_Nonnull stop) {
                                     NSUInteger charIdx =
                                         [self characterIndexForGlyphAtIndex:
                                                   glyphRange.location];
                                     if (charIdx >= textStorage.length) {
                                       charIdx = textStorage.length - 1;
                                     }
                                     UIFont *font =
                                         [textStorage attribute:NSFontAttributeName
                                                       atIndex:charIdx
                                                effectiveRange:nil];
                                     NSParagraphStyle *lineParagraphStyle =
                                         [textStorage
                                              attribute:
                                                  NSParagraphStyleAttributeName
                                                atIndex:charIdx
                                         effectiveRange:nil];
                                     CGRect textRect =
                                         [self getTextAlignedUsedRect:usedRect
                                                                 font:font];
                                     CGFloat listIndent =
                                         EnrichedListContentIndentForMarker(
                                             host,
                                             EnrichedDeepestListMarker(
                                                 lineParagraphStyle));
                                     if (listIndent > 0.0) {
                                       CGFloat adjustedX =
                                           MAX(0.0,
                                               textRect.origin.x - listIndent);
                                       textRect.size.width +=
                                           textRect.origin.x - adjustedX;
                                       textRect.origin.x = adjustedX;
                                     }
                                     paragraphRect =
                                         CGRectIsNull(paragraphRect)
                                             ? textRect
                                             : CGRectUnion(paragraphRect,
                                                           textRect);
                                   }];

    if (!CGRectIsNull(paragraphRect)) {
      currentQuoteRect = CGRectIsNull(currentQuoteRect)
                             ? paragraphRect
                             : CGRectUnion(currentQuoteRect, paragraphRect);
    }
  }

  flushCurrentQuote();

  CGFloat desiredVerticalPadding = 6.0;
  CGFloat minimumSplitGap = 2.0;
  for (NSUInteger i = 0; i < quoteRects.count; i++) {
    CGRect quoteRect = [quoteRects[i] CGRectValue];
    CGFloat topPadding = desiredVerticalPadding;
    CGFloat bottomPadding = desiredVerticalPadding;

    if (i > 0) {
      CGRect previousRect = [quoteRects[i - 1] CGRectValue];
      CGFloat previousGap = quoteRect.origin.y - CGRectGetMaxY(previousRect);
      topPadding =
          MAX(0.0, MIN(topPadding, previousGap / 2.0 - minimumSplitGap));
    }
    if (i + 1 < quoteRects.count) {
      CGRect nextRect = [quoteRects[i + 1] CGRectValue];
      CGFloat nextGap = nextRect.origin.y - CGRectGetMaxY(quoteRect);
      bottomPadding =
          MAX(0.0, MIN(bottomPadding, nextGap / 2.0 - minimumSplitGap));
    }

    drawQuoteRail(quoteRect, topPadding, bottomPadding);
  }
}

- (void)drawLists:(id<EnrichedViewHost>)host
              origin:(CGPoint)origin
    visibleCharRange:(NSRange)visibleCharRange {
  UnorderedListStyle *ulStyle =
      host.stylesDict[@([UnorderedListStyle getType])];
  OrderedListStyle *olStyle = host.stylesDict[@([OrderedListStyle getType])];
  CheckboxListStyle *cbStyle = host.stylesDict[@([CheckboxListStyle getType])];

  NSMutableArray *allLists = [[NSMutableArray alloc] init];

  if (ulStyle != nullptr) {
    [allLists addObjectsFromArray:[ulStyle all:visibleCharRange]];
  }
  if (olStyle != nullptr) {
    [allLists addObjectsFromArray:[olStyle all:visibleCharRange]];
  }
  if (cbStyle != nullptr) {
    [allLists addObjectsFromArray:[cbStyle all:visibleCharRange]];
  }

  NSMutableSet<NSString *> *drawnParagraphs = [[NSMutableSet alloc] init];

  for (StylePair *pair in allLists) {
    NSRange listRange = [pair.rangeValue rangeValue];
    NSParagraphStyle *pStyle = (NSParagraphStyle *)pair.styleValue;
    NSDictionary *markerAttributes = @{
      NSFontAttributeName : [host.config orderedListMarkerFont],
      NSForegroundColorAttributeName : [host.config orderedListMarkerColor]
    };
    CGFloat indent = pStyle.firstLineHeadIndent;

    NSArray *paragraphs =
        [RangeUtils getSeparateParagraphsRangesIn:host.textView
                                            range:listRange];

    for (NSValue *paragraph in paragraphs) {
      NSRange paragraphRange = [paragraph rangeValue];
      NSString *paragraphKey = NSStringFromRange(paragraphRange);
      if ([drawnParagraphs containsObject:paragraphKey]) {
        continue;
      }

      if (!host.textView.isEditable &&
          !EnrichedParagraphHasVisibleContent(host.textView.textStorage.string,
                                              paragraphRange)) {
        [drawnParagraphs addObject:paragraphKey];
        continue;
      }

      NSRange paragraphGlyphRange =
          [self glyphRangeForCharacterRange:paragraphRange
                       actualCharacterRange:nullptr];

      [self
          enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                   usingBlock:^(CGRect rect, CGRect usedRect,
                                                NSTextContainer *container,
                                                NSRange lineGlyphRange,
                                                BOOL *stop) {
                                     NSUInteger charIdx =
                                         [self characterIndexForGlyphAtIndex:
                                                   lineGlyphRange.location];
                                     UIFont *font = [host.textView.textStorage
                                              attribute:NSFontAttributeName
                                                atIndex:charIdx
                                         effectiveRange:nil];
                                     NSParagraphStyle *lineParagraphStyle =
                                         [host.textView.textStorage
                                              attribute:
                                                  NSParagraphStyleAttributeName
                                                atIndex:charIdx
                                         effectiveRange:nil];
                                     CGRect textUsedRect =
                                         [self getTextAlignedUsedRect:usedRect
                                                                 font:font];
                                     CGRect markerUsedRect = textUsedRect;
                                     CGFloat markerIndent = indent;
                                     if (lineParagraphStyle != nullptr) {
                                       markerIndent =
                                           [lineParagraphStyle firstLineHeadIndent];
                                     }
                                     if (EnrichedParagraphHasBlockQuote(
                                             lineParagraphStyle)) {
                                       markerUsedRect.origin.x -=
                                           [host.config blockquoteBorderWidth] +
                                           [host.config blockquoteGapWidth];
                                     }

                                     NSString *markerFormat =
                                         EnrichedDeepestDrawableListMarker(
                                             lineParagraphStyle ?: pStyle);
                                     if (markerFormat == nil) {
                                       *stop = YES;
                                       return;
                                     }

                                     if ([markerFormat
                                             hasPrefix:
                                                 @"EnrichedOrderedList"]) {
                                       NSString *marker = [self
                                           getDecimalMarkerForList:host
                                                        charIndex:charIdx
                                                     markerFormat:markerFormat
                                                        listRange:listRange];
                                       [self drawDecimal:host
                                                     marker:marker
                                           markerAttributes:markerAttributes
                                                     origin:origin
                                                   usedRect:markerUsedRect
                                                     indent:markerIndent];
                                     } else if ([markerFormat
                                                    hasPrefix:
                                                        @"EnrichedUnorderedLis"
                                                        @"t"]) {
                                       [self drawBullet:host
                                           markerFormat:markerFormat
                                                 origin:origin
                                               usedRect:markerUsedRect
                                                 indent:markerIndent];
                                     } else if ([markerFormat
                                                    hasPrefix:
                                                        @"EnrichedCheckbox"]) {
                                       [self drawCheckbox:host
                                             markerFormat:markerFormat
                                                   origin:origin
                                                 usedRect:markerUsedRect
                                                   indent:markerIndent];
                                     }
                                     // only first line of a list gets its
                                     // marker drawn
                                     *stop = YES;
                                   }];
      [drawnParagraphs addObject:paragraphKey];
    }
  }
}

- (NSString *)getDecimalMarkerForList:(id<EnrichedViewHost>)host
                            charIndex:(NSUInteger)index
                         markerFormat:(NSString *)markerFormat
                             listRange:(NSRange)listRange {
  (void)listRange;
  NSString *fullText = host.textView.textStorage.string;
  NSInteger itemNumber = 1;
  NSInteger currentLevel = EnrichedListMarkerLevel(markerFormat);

  NSRange currentParagraph =
      [fullText paragraphRangeForRange:NSMakeRange(index, 0)];
  if (currentParagraph.location > 0) {
    NSInteger prevParagraphsCount = 0;
    NSInteger recentParagraphLocation =
        [fullText paragraphRangeForRange:NSMakeRange(
                                             currentParagraph.location - 1, 0)]
            .location;

    // seek for previous lists
    while (true) {
      NSRange previousParagraphRange = [fullText
          paragraphRangeForRange:NSMakeRange(recentParagraphLocation, 0)];
      if (!EnrichedParagraphHasVisibleContent(fullText,
                                              previousParagraphRange)) {
        break;
      }

      NSString *previousMarker =
          [self deepestListMarkerForHost:host charIndex:recentParagraphLocation];
      NSString *previousLayoutMarker =
          [self deepestLayoutListMarkerForHost:host
                                     charIndex:recentParagraphLocation];
      if (previousMarker == nil) {
        if (previousLayoutMarker != nil &&
            EnrichedIsListContinuationMarker(previousLayoutMarker) &&
            EnrichedListMarkerLevel(previousLayoutMarker) >= currentLevel) {
          // Continuation paragraphs belong to the previous list item and must
          // not reset ordered-list numbering.
        } else {
          break;
        }
      }

      if (previousMarker != nil) {
        NSInteger previousLevel = EnrichedListMarkerLevel(previousMarker);
        BOOL previousIsOrdered =
            EnrichedListMarkerMatches(previousMarker, @"EnrichedOrderedList");

        if ([previousMarker isEqualToString:markerFormat]) {
          prevParagraphsCount += 1;
        } else if (previousLevel > currentLevel) {
          // Nested list content belongs to the previous same-level item. Skip it
          // while counting siblings at the current ordered-list level.
        } else if (previousIsOrdered && previousLevel == currentLevel) {
          // Same depth but a different ordered-list marker means a distinct list
          // context, so numbering should restart.
          break;
        } else {
          break;
        }
      }

      if (recentParagraphLocation > 0) {
        recentParagraphLocation =
            [fullText
                paragraphRangeForRange:NSMakeRange(recentParagraphLocation - 1,
                                                   0)]
                .location;
      } else {
        break;
      }
    }

    itemNumber = prevParagraphsCount + 1;
  }

  return [NSString stringWithFormat:@"%ld.", (long)(itemNumber)];
}

- (NSString *)deepestListMarkerForHost:(id<EnrichedViewHost>)host
                             charIndex:(NSUInteger)index {
  if (index >= host.textView.textStorage.length) {
    return nil;
  }

  NSParagraphStyle *pStyle =
      [host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                    atIndex:index
                             effectiveRange:nil];
  if (pStyle == nullptr) {
    return nil;
  }

  return EnrichedDeepestDrawableListMarker(pStyle);
}

- (NSString *)deepestLayoutListMarkerForHost:(id<EnrichedViewHost>)host
                                   charIndex:(NSUInteger)index {
  if (index >= host.textView.textStorage.length) {
    return nil;
  }

  NSParagraphStyle *pStyle =
      [host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                    atIndex:index
                             effectiveRange:nil];
  if (pStyle == nullptr) {
    return nil;
  }

  return EnrichedDeepestListMarker(pStyle);
}

// Returns a usedRect adjusted to cover only the text portion of the line.
// When minimumLineHeight expands the line box, extra space is added at the top
// and text stays at the bottom. This strips that padding so markers align with
// the text, not the full line box.
- (CGRect)getTextAlignedUsedRect:(CGRect)usedRect font:(UIFont *)font {
  if (font && usedRect.size.height > font.lineHeight) {
    CGFloat extraSpace = usedRect.size.height - font.lineHeight;
    usedRect.origin.y += extraSpace;
    usedRect.size.height = font.lineHeight;
  }
  return usedRect;
}

- (void)drawCheckbox:(id<EnrichedViewHost>)host
        markerFormat:(NSString *)markerFormat
              origin:(CGPoint)origin
            usedRect:(CGRect)usedRect
              indent:(CGFloat)indent {
  BOOL isChecked = [markerFormat isEqualToString:@"EnrichedCheckbox1"];

  UIImage *image = isChecked ? host.config.checkboxCheckedImage
                             : host.config.checkboxUncheckedImage;
  CGFloat gapWidth = [host.config checkboxListGapWidth];
  CGFloat configuredBoxSize = [host.config checkboxListBoxSize];

  CGFloat boxSize = MIN(configuredBoxSize, usedRect.size.height);
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;
  CGFloat boxX = origin.x + indent - gapWidth - boxSize;
  CGFloat boxY = centerY - boxSize / 2.0;

  [image drawInRect:CGRectMake(boxX, boxY, boxSize, boxSize)];
}

- (void)drawBullet:(id<EnrichedViewHost>)host
      markerFormat:(NSString *)markerFormat
            origin:(CGPoint)origin
          usedRect:(CGRect)usedRect
            indent:(CGFloat)indent {
  CGFloat gapWidth = [host.config unorderedListGapWidth];
  CGFloat bulletSize = [host.config unorderedListBulletSize];
  CGFloat bulletX = origin.x + indent - gapWidth - bulletSize / 2;
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;

  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSaveGState(context);
  {
    NSInteger level = EnrichedListMarkerLevel(markerFormat);
    UIColor *bulletColor = [host.config unorderedListBulletColor];
    [bulletColor setFill];
    [bulletColor setStroke];

    if (level == 1) {
      CGContextSetLineWidth(context, MAX(1.0, bulletSize * 0.16));
      CGContextAddArc(context, bulletX, centerY, bulletSize / 2, 0, 2 * M_PI,
                      YES);
      CGContextStrokePath(context);
    } else if (level >= 2) {
      CGFloat side = bulletSize * 0.8;
      CGRect squareRect = CGRectMake(bulletX - side / 2, centerY - side / 2,
                                     side, side);
      CGContextFillRect(context, squareRect);
    } else {
      CGContextAddArc(context, bulletX, centerY, bulletSize / 2, 0, 2 * M_PI,
                      YES);
      CGContextFillPath(context);
    }
  }
  CGContextRestoreGState(context);
}

- (void)drawDecimal:(id<EnrichedViewHost>)host
              marker:(NSString *)marker
    markerAttributes:(NSDictionary *)markerAttributes
              origin:(CGPoint)origin
            usedRect:(CGRect)usedRect
              indent:(CGFloat)indent {
  CGFloat gapWidth = [host.config orderedListGapWidth];
  CGSize markerSize = [marker sizeWithAttributes:markerAttributes];
  CGFloat markerX = origin.x + indent - gapWidth - markerSize.width / 2;
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;
  CGFloat markerY = centerY - markerSize.height / 2.0;

  [marker drawAtPoint:CGPointMake(markerX, markerY)
       withAttributes:markerAttributes];
}

@end
