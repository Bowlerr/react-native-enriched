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
          [markerFormat hasPrefix:[baseValue stringByAppendingString:@":"]]);
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
          [markerFormat hasPrefix:@"EnrichedOrderedListContinuation"] ||
          [markerFormat hasPrefix:@"EnrichedCheckboxContinuation"]);
}

static NSString *EnrichedMarkerByReplacingPrefix(NSString *markerFormat,
                                                 NSString *sourcePrefix,
                                                 NSString *targetPrefix) {
  if (markerFormat == nil) {
    return nil;
  }

  if ([markerFormat isEqualToString:sourcePrefix]) {
    return targetPrefix;
  }

  NSString *sourcePrefixWithSeparator =
      [sourcePrefix stringByAppendingString:@":"];
  if (![markerFormat hasPrefix:sourcePrefixWithSeparator]) {
    return nil;
  }

  NSString *suffix = [markerFormat substringFromIndex:sourcePrefix.length];
  return [targetPrefix stringByAppendingString:suffix];
}

static NSString *EnrichedDrawableMarkerForContinuation(NSString *markerFormat) {
  NSString *unorderedMarker = EnrichedMarkerByReplacingPrefix(
      markerFormat, @"EnrichedUnorderedListContinuation",
      @"EnrichedUnorderedList");
  if (unorderedMarker != nil) {
    return unorderedMarker;
  }

  NSString *orderedMarker = EnrichedMarkerByReplacingPrefix(
      markerFormat, @"EnrichedOrderedListContinuation", @"EnrichedOrderedList");
  if (orderedMarker != nil) {
    return orderedMarker;
  }

  // Checkbox continuations need list indentation but must not draw a second
  // box.
  return nil;
}

static BOOL EnrichedAnyListMarkerMatches(NSString *markerFormat) {
  return EnrichedLayoutListMarkerMatches(markerFormat,
                                         @"EnrichedUnorderedList") ||
         EnrichedLayoutListMarkerMatches(markerFormat,
                                         @"EnrichedOrderedList") ||
         [markerFormat hasPrefix:@"EnrichedCheckbox"];
}

static NSInteger EnrichedListMarkerLevel(NSString *markerFormat) {
  if (markerFormat == nil) {
    return 0;
  }

  NSRange separator = [markerFormat rangeOfString:@":"];
  if (separator.location == NSNotFound) {
    return 0;
  }
  NSString *levelString =
      [markerFormat substringFromIndex:separator.location + separator.length];
  return MAX(0, [levelString integerValue]);
}

static BOOL EnrichedMarkerIsBlockQuote(NSString *markerFormat) {
  return EnrichedLayoutListMarkerMatches(markerFormat, @"EnrichedBlockQuote");
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

  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (EnrichedMarkerIsBlockQuote(candidate)) {
      continue;
    }

    if (!EnrichedAnyListMarkerMatches(candidate) ||
        EnrichedIsListContinuationMarker(candidate)) {
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

static NSString *
EnrichedDeepestDrawableCheckboxMarker(NSParagraphStyle *pStyle) {
  NSString *markerFormat = nil;
  NSInteger markerLevel = -1;

  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (![candidate hasPrefix:@"EnrichedCheckbox0"] &&
        ![candidate hasPrefix:@"EnrichedCheckbox1"]) {
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

static NSString *
EnrichedDeepestDrawableContinuationListMarker(NSParagraphStyle *pStyle) {
  NSString *markerFormat = nil;
  NSInteger markerLevel = -1;

  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (EnrichedMarkerIsBlockQuote(candidate)) {
      continue;
    }

    NSString *drawableCandidate =
        EnrichedDrawableMarkerForContinuation(candidate);
    if (drawableCandidate == nil) {
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

static BOOL EnrichedBlockQuotePrecedesMarker(NSParagraphStyle *pStyle,
                                             NSString *targetMarkerFormat) {
  if (pStyle == nil || targetMarkerFormat == nil) {
    return NO;
  }

  BOOL hasSeenBlockQuote = NO;
  for (NSTextList *textList in pStyle.textLists) {
    NSString *candidate = textList.markerFormat;
    if (EnrichedMarkerIsBlockQuote(candidate)) {
      hasSeenBlockQuote = YES;
      continue;
    }

    if (hasSeenBlockQuote && [candidate isEqualToString:targetMarkerFormat]) {
      return YES;
    }
  }

  return NO;
}

static CGFloat EnrichedListContentIndentForMarker(id<EnrichedViewHost> host,
                                                  NSString *markerFormat) {
  if (markerFormat == nil) {
    return 0.0;
  }

  NSInteger level = EnrichedListMarkerLevel(markerFormat);
  if (EnrichedLayoutListMarkerMatches(markerFormat, @"EnrichedUnorderedList")) {
    return [host.config unorderedListMarginLeft] * (level + 1) +
           [host.config unorderedListGapWidth];
  }

  if (EnrichedLayoutListMarkerMatches(markerFormat, @"EnrichedOrderedList")) {
    return [host.config orderedListMarginLeft] * (level + 1) +
           [host.config orderedListGapWidth];
  }

  if ([markerFormat hasPrefix:@"EnrichedCheckbox"]) {
    return [host.config checkboxListMarginLeft] * (level + 1) +
           [host.config checkboxListGapWidth] +
           [host.config checkboxListBoxSize];
  }

  return 0.0;
}

static CGFloat
EnrichedLayoutIndentNestedInsideBlockQuote(id<EnrichedViewHost> host,
                                           NSParagraphStyle *pStyle) {
  CGFloat indent = 0.0;
  BOOL hasBlockQuote = NO;
  BOOL hasSeenBlockQuote = NO;

  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (EnrichedMarkerIsBlockQuote(markerFormat)) {
      hasBlockQuote = YES;
      hasSeenBlockQuote = YES;
      continue;
    }

    if (!hasSeenBlockQuote) {
      continue;
    }

    if (EnrichedAnyListMarkerMatches(markerFormat)) {
      indent =
          MAX(indent, EnrichedListContentIndentForMarker(host, markerFormat));
    } else if ([markerFormat isEqualToString:@"EnrichedCodeBlock"]) {
      indent = MAX(indent, 12.0);
    }
  }

  return hasBlockQuote ? indent : 0.0;
}

static BOOL EnrichedParagraphHasBlockQuote(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    if (EnrichedMarkerIsBlockQuote(textList.markerFormat)) {
      return YES;
    }
  }
  return NO;
}

static BOOL EnrichedParagraphHasCodeBlock(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    if ([textList.markerFormat isEqualToString:@"EnrichedCodeBlock"]) {
      return YES;
    }
  }
  return NO;
}

static CGFloat EnrichedBlockQuoteIndentForParagraph(id<EnrichedViewHost> host,
                                                    NSParagraphStyle *pStyle) {
  if (pStyle == nil) {
    return 0.0;
  }

  NSInteger quoteLevel = -1;
  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (!EnrichedMarkerIsBlockQuote(markerFormat)) {
      continue;
    }
    quoteLevel = MAX(quoteLevel, EnrichedListMarkerLevel(markerFormat));
  }

  if (quoteLevel < 0) {
    return 0.0;
  }

  CGFloat indentUnit =
      [host.config blockquoteBorderWidth] + [host.config blockquoteGapWidth];
  return indentUnit * (quoteLevel + 1);
}

static NSString *EnrichedBlockQuoteMarker(NSParagraphStyle *pStyle) {
  NSString *marker = nil;
  NSInteger markerLevel = -1;

  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (!EnrichedMarkerIsBlockQuote(markerFormat)) {
      continue;
    }

    NSInteger currentLevel = EnrichedListMarkerLevel(markerFormat);
    if (currentLevel >= markerLevel) {
      marker = markerFormat;
      markerLevel = currentLevel;
    }
  }

  return marker;
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
                                       CGRect lineRect, CGRect lineUsedRect,
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

static CGFloat
EnrichedMeasuredWidthForGlyphRange(NSLayoutManager *layoutManager,
                                   NSTextStorage *textStorage,
                                   NSRange glyphRange) {
  if (textStorage == nil || glyphRange.length == 0) {
    return 0.0;
  }

  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                     actualGlyphRange:NULL];
  if (characterRange.location == NSNotFound || characterRange.length == 0 ||
      NSMaxRange(characterRange) > textStorage.length) {
    return 0.0;
  }

  NSMutableAttributedString *lineSlice =
      [[textStorage attributedSubstringFromRange:characterRange] mutableCopy];
  NSRange trailingCharacterRange =
      NSMakeRange(lineSlice.length > 0 ? lineSlice.length - 1 : 0, 1);
  if (lineSlice.length > 0) {
    [lineSlice removeAttribute:NSKernAttributeName
                         range:trailingCharacterRange];
  }

  CGSize size = [lineSlice size];
  return MAX(0.0, size.width);
}

static CGRect EnrichedTightGlyphRectForLine(NSLayoutManager *layoutManager,
                                            NSTextStorage *textStorage,
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

  CGFloat measuredWidth = EnrichedMeasuredWidthForGlyphRange(
      layoutManager, textStorage, glyphRange);
  if (measuredWidth > 0.0) {
    maxX = minX + measuredWidth;
  }

  CGFloat lineMinX = lineUsedRect.origin.x;
  CGFloat lineMaxX = CGRectGetMaxX(lineUsedRect);
  minX = MIN(MAX(minX, lineMinX), lineMaxX);
  maxX = MIN(MAX(maxX, minX), lineMaxX);
  glyphRect.origin.x = minX;
  glyphRect.size.width = maxX - minX;

  return glyphRect;
}

static CGRect EnrichedInlineBackgroundRect(CGRect glyphRect, CGRect lineRect,
                                           CGFloat leadingPadding,
                                           CGFloat trailingPadding,
                                           CGFloat verticalPadding) {
  CGRect bgRect = glyphRect;
  bgRect.origin.x -= leadingPadding;
  bgRect.size.width += leadingPadding + trailingPadding;
  bgRect = CGRectInset(bgRect, 0.0, -verticalPadding);
  CGFloat lineInset = 2.0;
  CGFloat minY = CGRectGetMinY(lineRect) + lineInset;
  CGFloat maxY = CGRectGetMaxY(lineRect) - lineInset;
  CGFloat maxHeight = MAX(1.0, maxY - minY);

  if (bgRect.size.height > maxHeight) {
    bgRect.size.height = maxHeight;
    bgRect.origin.y = minY;
  } else {
    CGFloat centeredY = CGRectGetMidY(glyphRect) - (bgRect.size.height / 2.0);
    bgRect.origin.y = MIN(MAX(centeredY, minY), maxY - bgRect.size.height);
  }

  return bgRect;
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

  [self drawCodeBlocks:host origin:origin visibleCharRange:visibleCharRange];
  [self drawBlockQuotes:host origin:origin visibleCharRange:visibleCharRange];
  [self drawInlineCodes:host origin:origin visibleCharRange:visibleCharRange];
  [self drawMentions:host origin:origin visibleCharRange:visibleCharRange];
  [self drawLists:host origin:origin visibleCharRange:visibleCharRange];
}

- (void)drawTightInlineBackgroundForRange:(NSRange)characterRange
                                    color:(UIColor *)bgColor
                                   origin:(CGPoint)origin
                           leadingPadding:(CGFloat)leadingPadding
                          trailingPadding:(CGFloat)trailingPadding
                          verticalPadding:(CGFloat)verticalPadding
                                   radius:(CGFloat)radius
                                     host:(id<EnrichedViewHost>)host {
  NSRange trimmedRange = EnrichedTrimDecorativeRangeEdges(
      host.textView.textStorage.string, characterRange);
  if (trimmedRange.length == 0) {
    return;
  }

  NSArray *nonNewlineRanges = [RangeUtils getNonNewlineRangesIn:host.textView
                                                          range:trimmedRange];
  for (NSValue *value in nonNewlineRanges) {
    NSRange nonNewlineRange = [value rangeValue];
    if (nonNewlineRange.length == 0) {
      continue;
    }

    NSRange glyphRange = [self glyphRangeForCharacterRange:nonNewlineRange
                                      actualCharacterRange:nullptr];
    [self
        enumerateLineFragmentsForGlyphRange:glyphRange
                                 usingBlock:^(
                                     CGRect rect, CGRect usedRect,
                                     NSTextContainer *_Nonnull textContainer,
                                     NSRange lineGlyphRange,
                                     BOOL *_Nonnull stop) {
                                   NSRange lineInlineGlyphRange =
                                       NSIntersectionRange(glyphRange,
                                                           lineGlyphRange);
                                   if (lineInlineGlyphRange.length == 0) {
                                     return;
                                   }

                                   CGRect glyphRect =
                                       EnrichedTightGlyphRectForLine(
                                           self, host.textView.textStorage,
                                           textContainer, rect, usedRect,
                                           lineInlineGlyphRange);
                                   if (CGRectIsEmpty(glyphRect)) {
                                     return;
                                   }

                                   CGRect bgRect = EnrichedInlineBackgroundRect(
                                       glyphRect, rect, leadingPadding,
                                       trailingPadding, verticalPadding);
                                   bgRect =
                                       CGRectOffset(bgRect, origin.x, origin.y);

                                   UIBezierPath *path = [UIBezierPath
                                       bezierPathWithRoundedRect:bgRect
                                                    cornerRadius:radius];
                                   [bgColor setFill];
                                   [path fill];
                                 }];
  }
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
  CGFloat leadingPadding = 5.0;
  CGFloat trailingPadding = 3.0;
  CGFloat verticalPadding = 1.0;
  CGFloat radius = 4.0;

  for (StylePair *pair in [inlineCodeStyle all:visibleCharRange]) {
    [self drawTightInlineBackgroundForRange:[pair.rangeValue rangeValue]
                                      color:bgColor
                                     origin:origin
                             leadingPadding:leadingPadding
                            trailingPadding:trailingPadding
                            verticalPadding:verticalPadding
                                     radius:radius
                                       host:host];
  }
}

- (void)drawMentions:(id<EnrichedViewHost>)host
              origin:(CGPoint)origin
    visibleCharRange:(NSRange)visibleCharRange {
  MentionStyle *mentionStyle = host.stylesDict[@([MentionStyle getType])];
  if (mentionStyle == nullptr) {
    return;
  }

  CGFloat padding = 3.0;
  CGFloat verticalPadding = 1.0;
  CGFloat radius = 4.0;

  for (StylePair *pair in [mentionStyle all:visibleCharRange]) {
    MentionParams *params = (MentionParams *)pair.styleValue;
    if (params == nullptr) {
      continue;
    }

    MentionStyleProps *styleProps =
        [host.config mentionStylePropsForIndicator:params.indicator];
    UIColor *bgColor =
        [styleProps.backgroundColor colorWithAlphaIfNotTransparent:0.4];

    [self drawTightInlineBackgroundForRange:[pair.rangeValue rangeValue]
                                      color:bgColor
                                     origin:origin
                             leadingPadding:padding
                            trailingPadding:padding
                            verticalPadding:verticalPadding
                                     radius:radius
                                       host:host];
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
      [self mergeContiguousCodeBlockStylePairs:allCodeBlocks];
  CGFloat backgroundAlpha = 80.0 / 255.0;
  UIColor *bgColor = [[host.config codeBlockBgColor]
      colorWithAlphaIfNotTransparent:backgroundAlpha];
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
                                     NSRange glyphRange, BOOL *_Nonnull stop) {
                                   CGFloat horizontalPadding = 12.0;
                                   CGFloat verticalPadding = 6.0;
                                   CGFloat minX =
                                       MAX(0.0, usedRect.origin.x -
                                                    horizontalPadding);
                                   CGRect lineBgRect = CGRectMake(
                                       origin.x + minX,
                                       origin.y + usedRect.origin.y -
                                           verticalPadding,
                                       MAX(1.0, textContainer.size.width -
                                                    minX - horizontalPadding),
                                       usedRect.size.height +
                                           verticalPadding * 2);

                                   blockRect =
                                       CGRectIsNull(blockRect)
                                           ? lineBgRect
                                           : CGRectUnion(blockRect, lineBgRect);
                                 }];

    if (!CGRectIsNull(blockRect)) {
      UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:blockRect
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

- (NSArray<StylePair *> *)mergeContiguousCodeBlockStylePairs:
    (NSArray<StylePair *> *)pairs {
  if (pairs.count == 0) {
    return @[];
  }

  NSMutableArray<StylePair *> *mergedPairs = [[NSMutableArray alloc] init];
  StylePair *currentPair = pairs[0];
  StylePair *previousPair = pairs[0];
  NSRange currentRange = [currentPair.rangeValue rangeValue];

  for (NSUInteger i = 1; i < pairs.count; i++) {
    StylePair *nextPair = pairs[i];
    NSRange nextRange = [nextPair.rangeValue rangeValue];
    NSParagraphStyle *previousStyle =
        (NSParagraphStyle *)previousPair.styleValue;
    NSParagraphStyle *nextStyle = (NSParagraphStyle *)nextPair.styleValue;
    BOOL spacingBoundary = previousStyle.paragraphSpacing > 0.0 &&
                           nextStyle.paragraphSpacingBefore > 0.0;

    if (NSMaxRange(currentRange) == nextRange.location && !spacingBoundary) {
      currentRange.length += nextRange.length;
    } else {
      StylePair *mergedPair = [[StylePair alloc] init];
      mergedPair.rangeValue = [NSValue valueWithRange:currentRange];
      mergedPair.styleValue = currentPair.styleValue;
      [mergedPairs addObject:mergedPair];

      currentPair = nextPair;
      currentRange = nextRange;
    }

    previousPair = nextPair;
  }

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
    BOOL sameBlockQuote = (currentMarker == nil && nextMarker == nil) ||
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

  void (^drawQuoteRail)(CGRect, CGFloat, CGFloat, CGFloat) =
      ^(CGRect quoteRect, CGFloat railX, CGFloat topPadding,
        CGFloat bottomPadding) {
        CGFloat borderWidth = [host.config blockquoteBorderWidth];
        [[host.config blockquoteBorderColor] setFill];
        CGRect lineRect = CGRectMake(
            origin.x + railX, origin.y + quoteRect.origin.y - topPadding,
            borderWidth, quoteRect.size.height + topPadding + bottomPadding);
        UIRectFill(lineRect);
      };

  NSMutableArray<NSDictionary *> *quoteRailSegments =
      [[NSMutableArray alloc] init];
  NSMutableDictionary<NSNumber *, NSMutableDictionary *> *activeRailSegments =
      [[NSMutableDictionary alloc] init];

  void (^flushRail)(NSNumber *) = ^(NSNumber *railLevel) {
    NSMutableDictionary *railSegment = activeRailSegments[railLevel];
    if (railSegment != nil) {
      [quoteRailSegments addObject:[railSegment copy]];
      [activeRailSegments removeObjectForKey:railLevel];
    }
  };

  void (^flushRailsDeeperThan)(NSInteger) = ^(NSInteger quoteLevel) {
    NSArray<NSNumber *> *activeLevels = [activeRailSegments allKeys];
    for (NSNumber *railLevel in activeLevels) {
      if ([railLevel integerValue] > quoteLevel) {
        flushRail(railLevel);
      }
    }
  };

  void (^flushAllRails)(void) = ^{
    NSArray<NSNumber *> *activeLevels = [activeRailSegments allKeys];
    for (NSNumber *railLevel in activeLevels) {
      flushRail(railLevel);
    }
  };

  NSArray *paragraphs =
      [RangeUtils getSeparateParagraphsRangesIn:host.textView
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
      flushAllRails();
      continue;
    }
    NSInteger currentQuoteLevel = EnrichedListMarkerLevel(quoteMarker);
    BOOL paragraphHasCodeBlock = EnrichedParagraphHasCodeBlock(paragraphStyle);

    if (!EnrichedParagraphHasVisibleContent(text, paragraphRange)) {
      continue;
    }

    NSRange paragraphGlyphRange =
        [self glyphRangeForCharacterRange:paragraphRange
                     actualCharacterRange:nullptr];
    __block CGRect paragraphRect = CGRectNull;

    [self
        enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                 usingBlock:^(
                                     CGRect rect, CGRect usedRect,
                                     NSTextContainer *_Nonnull textContainer,
                                     NSRange glyphRange, BOOL *_Nonnull stop) {
                                   NSUInteger charIdx =
                                       [self characterIndexForGlyphAtIndex:
                                                 glyphRange.location];
                                   if (charIdx >= textStorage.length) {
                                     charIdx = textStorage.length - 1;
                                   }
                                   UIFont *font = [textStorage
                                            attribute:NSFontAttributeName
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
                                       EnrichedLayoutIndentNestedInsideBlockQuote(
                                           host, lineParagraphStyle);
                                   if (listIndent > 0.0) {
                                     CGFloat adjustedX = MAX(
                                         0.0, textRect.origin.x - listIndent);
                                     textRect.size.width +=
                                         textRect.origin.x - adjustedX;
                                     textRect.origin.x = adjustedX;
                                   }
                                   if (EnrichedParagraphHasCodeBlock(
                                           lineParagraphStyle)) {
                                     CGFloat verticalPadding = 6.0;
                                     textRect.origin.y =
                                         usedRect.origin.y - verticalPadding;
                                     textRect.size.height =
                                         usedRect.size.height +
                                         verticalPadding * 2.0;
                                   } else {
                                     textRect.origin.y = rect.origin.y;
                                     textRect.size.height = rect.size.height;
                                   }
                                   paragraphRect =
                                       CGRectIsNull(paragraphRect)
                                           ? textRect
                                           : CGRectUnion(paragraphRect,
                                                         textRect);
                                 }];

    if (!CGRectIsNull(paragraphRect)) {
      flushRailsDeeperThan(currentQuoteLevel);

      CGFloat borderWidth = [host.config blockquoteBorderWidth];
      CGFloat indentUnit = borderWidth + [host.config blockquoteGapWidth];
      for (NSInteger railLevel = 0; railLevel <= currentQuoteLevel;
           railLevel++) {
        CGFloat distanceFromContent =
            indentUnit * (currentQuoteLevel + 1 - railLevel);
        CGFloat railX = paragraphRect.origin.x - distanceFromContent;
        NSNumber *railKey = @(railLevel);
        NSMutableDictionary *activeSegment = activeRailSegments[railKey];
        BOOL shouldMerge = NO;

        if (activeSegment != nil) {
          CGFloat activeX = [activeSegment[@"x"] doubleValue];
          NSInteger previousQuoteLevel =
              [activeSegment[@"lastQuoteLevel"] integerValue];
          NSString *previousMarker = activeSegment[@"marker"];
          BOOL markerChanged = previousMarker != nil &&
                               ![previousMarker isEqualToString:quoteMarker];
          BOOL siblingQuoteBoundary =
              markerChanged && previousQuoteLevel == currentQuoteLevel;
          CGFloat railDelta =
              activeX > railX ? activeX - railX : railX - activeX;
          shouldMerge = railDelta < 0.5 && !siblingQuoteBoundary;
        }

        if (!shouldMerge) {
          flushRail(railKey);
          activeSegment = [@{
            @"rect" : [NSValue valueWithCGRect:paragraphRect],
            @"x" : @(railX),
            @"marker" : quoteMarker,
            @"lastQuoteLevel" : @(currentQuoteLevel),
            @"startsWithCodeBlock" : @(paragraphHasCodeBlock),
            @"endsWithCodeBlock" : @(paragraphHasCodeBlock)
          } mutableCopy];
          activeRailSegments[railKey] = activeSegment;
          continue;
        }

        CGRect activeRect = [activeSegment[@"rect"] CGRectValue];
        activeSegment[@"rect"] =
            [NSValue valueWithCGRect:CGRectUnion(activeRect, paragraphRect)];
        activeSegment[@"marker"] = quoteMarker;
        activeSegment[@"lastQuoteLevel"] = @(currentQuoteLevel);
        activeSegment[@"endsWithCodeBlock"] = @(paragraphHasCodeBlock);
      }
    }
  }

  flushAllRails();

  CGFloat desiredVerticalPadding = 6.0;
  for (NSDictionary *quoteSegment in quoteRailSegments) {
    CGRect quoteRect = [quoteSegment[@"rect"] CGRectValue];
    CGFloat railX = [quoteSegment[@"x"] doubleValue];
    BOOL startsWithCodeBlock = [quoteSegment[@"startsWithCodeBlock"] boolValue];
    BOOL endsWithCodeBlock = [quoteSegment[@"endsWithCodeBlock"] boolValue];
    CGFloat topPadding = startsWithCodeBlock ? 0.0 : desiredVerticalPadding;
    CGFloat bottomPadding = endsWithCodeBlock ? 0.0 : desiredVerticalPadding;
    drawQuoteRail(quoteRect, railX, topPadding, bottomPadding);
  }
}

- (NSUInteger)previousDrawableListCharIndexForHost:(id<EnrichedViewHost>)host
                                         charIndex:(NSUInteger)index
                                      markerFormat:(NSString *)markerFormat {
  if (markerFormat == nil) {
    return NSNotFound;
  }

  NSString *fullText = host.textView.textStorage.string;
  NSRange currentParagraph =
      [fullText paragraphRangeForRange:NSMakeRange(index, 0)];
  if (currentParagraph.location == 0) {
    return NSNotFound;
  }

  NSInteger currentLevel = EnrichedListMarkerLevel(markerFormat);
  NSUInteger recentParagraphLocation =
      [fullText
          paragraphRangeForRange:NSMakeRange(currentParagraph.location - 1, 0)]
          .location;

  while (true) {
    NSRange previousParagraphRange = [fullText
        paragraphRangeForRange:NSMakeRange(recentParagraphLocation, 0)];
    if (!EnrichedParagraphHasVisibleContent(fullText, previousParagraphRange)) {
      break;
    }

    NSString *previousMarker =
        [self deepestListMarkerForHost:host charIndex:recentParagraphLocation];
    NSString *previousLayoutMarker =
        [self deepestLayoutListMarkerForHost:host
                                   charIndex:recentParagraphLocation];

    if (previousMarker != nil) {
      if ([previousMarker isEqualToString:markerFormat]) {
        return recentParagraphLocation;
      }

      if (EnrichedListMarkerLevel(previousMarker) < currentLevel) {
        break;
      }
    } else if (!(previousLayoutMarker != nil &&
                 EnrichedIsListContinuationMarker(previousLayoutMarker) &&
                 EnrichedListMarkerLevel(previousLayoutMarker) >=
                     currentLevel)) {
      break;
    }

    if (recentParagraphLocation == 0) {
      break;
    }

    recentParagraphLocation =
        [fullText
            paragraphRangeForRange:NSMakeRange(recentParagraphLocation - 1, 0)]
            .location;
  }

  return NSNotFound;
}

- (void)drawLists:(id<EnrichedViewHost>)host
              origin:(CGPoint)origin
    visibleCharRange:(NSRange)visibleCharRange {
  UnorderedListStyle *ulStyle =
      host.stylesDict[@([UnorderedListStyle getType])];
  OrderedListStyle *olStyle = host.stylesDict[@([OrderedListStyle getType])];
  CheckboxListStyle *cbStyle = host.stylesDict[@([CheckboxListStyle getType])];

  NSMutableArray *allLists = [[NSMutableArray alloc] init];

  if (cbStyle != nullptr) {
    [allLists addObjectsFromArray:[cbStyle all:visibleCharRange]];
  }
  if (ulStyle != nullptr) {
    [allLists addObjectsFromArray:[ulStyle all:visibleCharRange]];
  }
  if (olStyle != nullptr) {
    [allLists addObjectsFromArray:[olStyle all:visibleCharRange]];
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
      __block BOOL didDrawMarker = NO;

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
                                       markerIndent = [lineParagraphStyle
                                           firstLineHeadIndent];
                                     }

                                     NSParagraphStyle *effectiveParagraphStyle =
                                         lineParagraphStyle ?: pStyle;
                                     NSString *checkboxMarkerFormat =
                                         EnrichedDeepestDrawableCheckboxMarker(
                                             effectiveParagraphStyle);
                                     NSString *layoutMarkerFormat =
                                         checkboxMarkerFormat
                                             ?: EnrichedDeepestListMarker(
                                                    effectiveParagraphStyle);
                                     NSString *markerFormat =
                                         checkboxMarkerFormat
                                             ?: EnrichedDeepestDrawableListMarker(
                                                    effectiveParagraphStyle);
                                     BOOL drawsContinuationQuoteMarker = NO;
                                     if (markerFormat == nil &&
                                         EnrichedParagraphHasBlockQuote(
                                             effectiveParagraphStyle)) {
                                       layoutMarkerFormat =
                                           EnrichedDeepestDrawableContinuationListMarker(
                                               effectiveParagraphStyle);
                                       markerFormat =
                                           EnrichedDrawableMarkerForContinuation(
                                               layoutMarkerFormat);
                                       drawsContinuationQuoteMarker =
                                           markerFormat != nil;
                                     }
                                     if (markerFormat == nil) {
                                       *stop = YES;
                                       return;
                                     }

                                     if (drawsContinuationQuoteMarker) {
                                       markerIndent = MAX(
                                           0.0,
                                           markerIndent -
                                               EnrichedBlockQuoteIndentForParagraph(
                                                   host,
                                                   effectiveParagraphStyle));
                                     }

                                     if (EnrichedBlockQuotePrecedesMarker(
                                             lineParagraphStyle,
                                             drawsContinuationQuoteMarker
                                                 ? layoutMarkerFormat
                                                 : markerFormat)) {
                                       markerUsedRect.origin.x -=
                                           [host.config blockquoteBorderWidth] +
                                           [host.config blockquoteGapWidth];
                                     }

                                     if ([markerFormat
                                             hasPrefix:
                                                 @"EnrichedOrderedList"]) {
                                       NSUInteger markerCharIdx = charIdx;
                                       if (drawsContinuationQuoteMarker) {
                                         NSUInteger previousCharIdx = [self
                                             previousDrawableListCharIndexForHost:
                                                 host
                                                                        charIndex:
                                                                            charIdx
                                                                     markerFormat:
                                                                         markerFormat];
                                         if (previousCharIdx != NSNotFound) {
                                           markerCharIdx = previousCharIdx;
                                         }
                                       }
                                       NSString *marker = [self
                                           getDecimalMarkerForList:host
                                                         charIndex:markerCharIdx
                                                      markerFormat:markerFormat
                                                         listRange:listRange];
                                       [self drawDecimal:host
                                                     marker:marker
                                           markerAttributes:markerAttributes
                                                     origin:origin
                                                   usedRect:markerUsedRect
                                                     indent:markerIndent];
                                       didDrawMarker = YES;
                                     } else if ([markerFormat
                                                    hasPrefix:
                                                        @"EnrichedUnorderedLis"
                                                        @"t"]) {
                                       [self drawBullet:host
                                           markerFormat:markerFormat
                                                 origin:origin
                                               usedRect:markerUsedRect
                                                 indent:markerIndent];
                                       didDrawMarker = YES;
                                     } else if ([markerFormat
                                                    hasPrefix:
                                                        @"EnrichedCheckbox"]) {
                                       [self drawCheckbox:host
                                             markerFormat:markerFormat
                                                   origin:origin
                                                 usedRect:markerUsedRect
                                                   indent:markerIndent];
                                       didDrawMarker = YES;
                                     }
                                     // only first line of a list gets its
                                     // marker drawn
                                     *stop = YES;
                                   }];
      if (didDrawMarker) {
        [drawnParagraphs addObject:paragraphKey];
      }
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
          [self deepestListMarkerForHost:host
                               charIndex:recentParagraphLocation];
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
          // Nested list content belongs to the previous same-level item. Skip
          // it while counting siblings at the current ordered-list level.
        } else if (previousIsOrdered && previousLevel == currentLevel) {
          // Same depth but a different ordered-list marker means a distinct
          // list context, so numbering should restart.
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
  BOOL isChecked = [markerFormat hasPrefix:@"EnrichedCheckbox1"];

  UIImage *image = isChecked ? host.config.checkboxCheckedImage
                             : host.config.checkboxUncheckedImage;
  CGFloat gapWidth = [host.config checkboxListGapWidth];
  CGFloat configuredBoxSize = [host.config checkboxListBoxSize];
  if (configuredBoxSize <= 0.0) {
    configuredBoxSize = MAX(12.0, usedRect.size.height * 0.8);
  }

  CGFloat boxSize = MIN(configuredBoxSize, MAX(1.0, usedRect.size.height));
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;
  CGFloat boxX = origin.x + indent - gapWidth - boxSize;
  CGFloat boxY = centerY - boxSize / 2.0;
  CGRect boxRect = CGRectMake(boxX, boxY, boxSize, boxSize);

  if (image != nil && image.size.width > 0.0 && image.size.height > 0.0) {
    [image drawInRect:boxRect];
    return;
  }

  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context == nil) {
    return;
  }

  UIColor *boxColor =
      [host.config checkboxListBoxColor] ?: [UIColor blackColor];
  CGFloat strokeWidth = MAX(1.5, boxSize * 0.1);
  CGRect insetRect = CGRectInset(boxRect, strokeWidth / 2.0, strokeWidth / 2.0);
  CGFloat cornerRadius = MAX(2.0, boxSize * 0.16);
  UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:insetRect
                                                     cornerRadius:cornerRadius];
  boxPath.lineWidth = strokeWidth;

  CGContextSaveGState(context);
  [boxColor setStroke];
  if (isChecked) {
    [boxColor setFill];
    [boxPath fill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *checkPath = [UIBezierPath bezierPath];
    checkPath.lineWidth = MAX(2.0, boxSize * 0.12);
    checkPath.lineCapStyle = kCGLineCapRound;
    checkPath.lineJoinStyle = kCGLineJoinRound;
    [checkPath moveToPoint:CGPointMake(CGRectGetMinX(boxRect) + boxSize * 0.25,
                                       CGRectGetMidY(boxRect))];
    [checkPath
        addLineToPoint:CGPointMake(CGRectGetMinX(boxRect) + boxSize * 0.43,
                                   CGRectGetMinY(boxRect) + boxSize * 0.66)];
    [checkPath
        addLineToPoint:CGPointMake(CGRectGetMinX(boxRect) + boxSize * 0.76,
                                   CGRectGetMinY(boxRect) + boxSize * 0.32)];
    [checkPath stroke];
  } else {
    [boxPath stroke];
  }
  CGContextRestoreGState(context);
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
      CGRect squareRect =
          CGRectMake(bulletX - side / 2, centerY - side / 2, side, side);
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
