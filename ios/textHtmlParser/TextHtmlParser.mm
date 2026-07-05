#import "TextHtmlParser.h"
#import "AlignmentEntry.h"
#import "EnrichedTextView.h"
#import "HtmlParser.h"
#import "LinkData.h"
#import "MentionParams.h"
#import "StyleHeaders.h"
#import "ZeroWidthSpaceUtils.h"
#import <React/RCTLog.h>

@implementation TextHtmlParser

static BOOL EnrichedHtmlStyleTypeIsHeading(NSNumber *styleType) {
  return [styleType isEqualToNumber:@([H1Style getType])] ||
         [styleType isEqualToNumber:@([H2Style getType])] ||
         [styleType isEqualToNumber:@([H3Style getType])] ||
         [styleType isEqualToNumber:@([H4Style getType])] ||
         [styleType isEqualToNumber:@([H5Style getType])] ||
         [styleType isEqualToNumber:@([H6Style getType])];
}

static BOOL EnrichedHtmlStyleTypeIsList(NSNumber *styleType) {
  return [styleType isEqualToNumber:@([UnorderedListStyle getType])] ||
         [styleType isEqualToNumber:@([OrderedListStyle getType])] ||
         [styleType isEqualToNumber:@([CheckboxListStyle getType])];
}

static BOOL EnrichedTextHtmlMarkerMatches(NSString *markerFormat,
                                          NSString *baseValue) {
  if (markerFormat == nil) {
    return NO;
  }

  NSString *continuationBaseValue =
      [baseValue stringByAppendingString:@"Continuation"];
  return [markerFormat isEqualToString:baseValue] ||
         [markerFormat hasPrefix:[baseValue stringByAppendingString:@":"]] ||
         [markerFormat isEqualToString:continuationBaseValue] ||
         [markerFormat
             hasPrefix:[continuationBaseValue stringByAppendingString:@":"]];
}

static BOOL EnrichedTextHtmlParagraphHasCollapsibleLayoutMarker(
    NSParagraphStyle *paragraphStyle) {
  if (paragraphStyle == nil) {
    return NO;
  }

  for (NSTextList *textList in paragraphStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (EnrichedTextHtmlMarkerMatches(markerFormat, @"EnrichedBlockQuote") ||
        EnrichedTextHtmlMarkerMatches(markerFormat, @"EnrichedUnorderedList") ||
        EnrichedTextHtmlMarkerMatches(markerFormat, @"EnrichedOrderedList") ||
        [markerFormat hasPrefix:@"EnrichedCheckbox"] ||
        [markerFormat isEqualToString:@"EnrichedCodeBlock"]) {
      return YES;
    }
  }
  return NO;
}

static BOOL EnrichedTextHtmlParagraphHasVisibleContent(NSString *text,
                                                       NSRange range) {
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

static NSUInteger
EnrichedHtmlInsertionCountBefore(NSArray<NSNumber *> *insertions,
                                 NSUInteger location) {
  NSUInteger count = 0;
  for (NSNumber *insertion in insertions) {
    if ([insertion unsignedIntegerValue] < location) {
      count++;
    }
  }
  return count;
}

static NSUInteger
EnrichedHtmlInsertionCountAtOrBefore(NSArray<NSNumber *> *insertions,
                                     NSUInteger location) {
  NSUInteger count = 0;
  for (NSNumber *insertion in insertions) {
    if ([insertion unsignedIntegerValue] <= location) {
      count++;
    }
  }
  return count;
}

static NSRange
EnrichedHtmlRangeAdjustedForInsertions(NSRange range,
                                       NSArray<NSNumber *> *insertions) {
  NSUInteger originalStart = range.location;
  NSUInteger originalEnd = NSMaxRange(range);
  NSUInteger adjustedStart = originalStart + EnrichedHtmlInsertionCountBefore(
                                                 insertions, originalStart);
  NSUInteger adjustedEnd =
      originalEnd + EnrichedHtmlInsertionCountBefore(insertions, originalEnd);
  return NSMakeRange(adjustedStart, adjustedEnd - adjustedStart);
}

static NSUInteger EnrichedHtmlOriginalLocationForAdjustedLocation(
    NSUInteger adjustedLocation, NSArray<NSNumber *> *insertions) {
  NSUInteger originalLocation = adjustedLocation;
  while (true) {
    NSUInteger previousLocation = originalLocation;
    NSUInteger insertionCount =
        EnrichedHtmlInsertionCountAtOrBefore(insertions, originalLocation);
    originalLocation = adjustedLocation >= insertionCount
                           ? adjustedLocation - insertionCount
                           : 0;
    if (originalLocation == previousLocation) {
      return originalLocation;
    }
  }
}

static void EnrichedHtmlRecordInsertedZeroWidthSpaces(
    NSString *before, NSString *after, NSMutableArray<NSNumber *> *insertions) {
  if (after.length <= before.length) {
    return;
  }

  NSUInteger beforeIndex = 0;
  NSUInteger afterIndex = 0;
  while (afterIndex < after.length) {
    if (beforeIndex < before.length && [before characterAtIndex:beforeIndex] ==
                                           [after
                                               characterAtIndex:afterIndex]) {
      beforeIndex++;
      afterIndex++;
      continue;
    }

    if ([after characterAtIndex:afterIndex] == 0x200B) {
      NSUInteger originalLocation =
          EnrichedHtmlOriginalLocationForAdjustedLocation(beforeIndex,
                                                          insertions);
      [insertions addObject:@(originalLocation)];
    }
    afterIndex++;
  }
}

static void EnrichedHtmlApplyPendingStyles(NSArray *pendingEntries) {
  for (NSArray *entry in pendingEntries) {
    StyleBase *style = entry[0];
    NSRange adjustedStyleRange = [((NSValue *)entry[1]) rangeValue];
    [style applyStyling:adjustedStyleRange];
  }
}

- (instancetype)initWithView:(EnrichedTextView *)view {
  self = [super init];
  _view = view;
  return self;
}

- (void)replaceWholeFromHtml:(NSString *_Nonnull)html {
  @try {
    NSString *normalized =
        [HtmlParser initiallyProcessHtml:html
                       useHtmlNormalizer:_view->useHtmlNormalizer];
    if (normalized == nil) {
      [_view->textView.textStorage
          setAttributedString:[[NSAttributedString alloc]
                                  initWithString:html
                                      attributes:_view->
                                                 defaultTypingAttributes]];
      return;
    }

    NSArray *result = [HtmlParser getTextAndStylesFromHtml:normalized];
    NSString *plainText = result[0];
    NSArray *processedStyles = result[1];
    NSArray *alignments = result[2];

    NSMutableAttributedString *body = [[NSMutableAttributedString alloc]
        initWithString:plainText
            attributes:_view->defaultTypingAttributes];
    [_view->textView.textStorage setAttributedString:body];
    [self applyProcessedStyles:processedStyles];
    [self applyProcessedAlignments:alignments];
    [self collapseInvisibleLayoutParagraphs];
  } @catch (NSException *exception) {
    RCTLogWarn(@"[EnrichedTextView]: Failed to parse HTML: (%@), falling back "
               @"to raw input.",
               exception.reason);
    [_view->textView.textStorage
        setAttributedString:[[NSAttributedString alloc]
                                initWithString:html
                                    attributes:_view->defaultTypingAttributes]];
  }
}

- (void)collapseInvisibleLayoutParagraphs {
  NSTextStorage *textStorage = _view->textView.textStorage;
  NSString *text = textStorage.string;
  if (text.length == 0) {
    return;
  }

  UIFont *collapsedFont = [UIFont systemFontOfSize:0.1];
  NSUInteger cursor = 0;
  while (cursor < text.length) {
    NSRange paragraphRange =
        [text paragraphRangeForRange:NSMakeRange(cursor, 0)];
    if (paragraphRange.length == 0 ||
        paragraphRange.location >= textStorage.length) {
      break;
    }

    NSUInteger attributeLocation =
        MIN(paragraphRange.location, textStorage.length - 1);
    NSParagraphStyle *paragraphStyle =
        [textStorage attribute:NSParagraphStyleAttributeName
                       atIndex:attributeLocation
                effectiveRange:nil];

    if (!EnrichedTextHtmlParagraphHasVisibleContent(text, paragraphRange) &&
        EnrichedTextHtmlParagraphHasCollapsibleLayoutMarker(paragraphStyle)) {
      NSMutableParagraphStyle *collapsedStyle =
          paragraphStyle != nil ? [paragraphStyle mutableCopy]
                                : [[NSMutableParagraphStyle alloc] init];
      collapsedStyle.paragraphSpacing = 0.0;
      collapsedStyle.paragraphSpacingBefore = 0.0;
      collapsedStyle.lineSpacing = 0.0;
      collapsedStyle.lineHeightMultiple = 0.0;
      collapsedStyle.minimumLineHeight = 0.1;
      collapsedStyle.maximumLineHeight = 0.1;
      [textStorage addAttribute:NSParagraphStyleAttributeName
                          value:collapsedStyle
                          range:paragraphRange];
      [textStorage addAttribute:NSFontAttributeName
                          value:collapsedFont
                          range:paragraphRange];
    }

    NSUInteger nextCursor = NSMaxRange(paragraphRange);
    if (nextCursor <= cursor) {
      break;
    }
    cursor = nextCursor;
  }
}

- (void)applyProcessedStyles:(NSArray *_Nonnull)processedStyles {
  // HTML parser ranges are relative to plain text before image attachments and
  // zero-width spaces are inserted. Track every inserted character by original
  // plain-text location so later ranges move while earlier/nested ranges do
  // not.
  NSMutableArray<NSNumber *> *textStorageInsertions =
      [[NSMutableArray alloc] init];

  // Inline styles collected during the first pass so their applyStyling: can
  // be re-run after all paragraph styles have applied their visual attributes.
  // Each entry is @[style, adjustedRange].
  NSMutableArray *pendingInlineApply = [NSMutableArray array];
  NSMutableArray *pendingInlineCodeApply = [NSMutableArray array];
  NSMutableArray *pendingBlockQuoteApply = [NSMutableArray array];
  NSMutableArray *pendingListApply = [NSMutableArray array];
  NSMutableArray *pendingCodeBlockApply = [NSMutableArray array];
  NSMutableArray *pendingHeadingApply = [NSMutableArray array];
  NSMutableArray *pendingParagraphApply = [NSMutableArray array];

  // First add all style metadata, then apply visual paragraph styling in a
  // deterministic order. Nested quote/list/code paragraphs can share the same
  // paragraph style, so applying visuals as parser entries arrive lets one
  // paragraph style flatten another.
  for (NSArray *arr in processedStyles) {
    NSNumber *styleType = (NSNumber *)arr[0];
    StylePair *stylePair = (StylePair *)arr[1];
    StyleBase *style = _view->stylesDict[styleType];
    if (style == nullptr)
      continue;

    NSRange parsedRange = [stylePair.rangeValue rangeValue];
    NSUInteger textLengthBeforeStyleApplied =
        _view->textView.textStorage.string.length;
    NSString *textBeforeStyleApplied =
        [_view->textView.textStorage.string copy];

    // Range must take inserted ZWS characters into consideration
    // because processed styles ranges are relative to only the new text while
    // we need absolute ranges relative to the whole existing text
    NSRange styleRange = EnrichedHtmlRangeAdjustedForInsertions(
        parsedRange, textStorageInsertions);
    BOOL didApplyImageStyle = NO;

    if ([styleType isEqualToNumber:@([LinkStyle getType])]) {
      LinkData *linkData = (LinkData *)stylePair.styleValue;
      [((LinkStyle *)style) applyLinkMetaWithData:linkData range:styleRange];
    } else if ([styleType isEqualToNumber:@([MentionStyle getType])]) {
      MentionParams *params = (MentionParams *)stylePair.styleValue;
      [((MentionStyle *)style) applyMentionMeta:params range:styleRange];
    } else if ([styleType isEqualToNumber:@([ImageStyle getType])]) {
      ImageData *imgData = (ImageData *)stylePair.styleValue;
      [((ImageStyle *)style) addImageAtRange:styleRange
                                   imageData:imgData
                               withSelection:NO
                              withDirtyRange:NO];
      didApplyImageStyle = YES;

      if (imgData.standalone) {
        NSUInteger afterImageLocation = styleRange.location + 1;
        NSString *currentText = _view->textView.textStorage.string;
        BOOL hasTrailingLineBreak =
            afterImageLocation < currentText.length &&
            [[NSCharacterSet newlineCharacterSet]
                characterIsMember:[currentText
                                      characterAtIndex:afterImageLocation]];
        if (!hasTrailingLineBreak) {
          NSAttributedString *lineBreak = [[NSAttributedString alloc]
              initWithString:@"\n"
                  attributes:_view->defaultTypingAttributes];
          [_view->textView.textStorage
              insertAttributedString:lineBreak
                             atIndex:afterImageLocation];
        }
      }
    } else if ([styleType isEqualToNumber:@([CheckboxListStyle getType])]) {
      CheckboxListStyle *cbStyle = (CheckboxListStyle *)style;

      if ([stylePair.styleValue isKindOfClass:[NSString class]]) {
        [cbStyle add:styleRange
                 withValue:(NSString *)stylePair.styleValue
                withTyping:NO
            withDirtyRange:NO];
      } else {
        NSDictionary *checkboxStates =
            [stylePair.styleValue isKindOfClass:[NSDictionary class]]
                ? (NSDictionary *)stylePair.styleValue
                : nil;

        [cbStyle addWithChecked:NO
                          range:styleRange
                     withTyping:NO
                 withDirtyRange:NO];

        if (checkboxStates && checkboxStates.count > 0) {
          for (NSNumber *key in checkboxStates) {
            NSUInteger checkboxPosition =
                [key unsignedIntegerValue] +
                EnrichedHtmlInsertionCountBefore(textStorageInsertions,
                                                 [key unsignedIntegerValue]);
            BOOL isChecked = [checkboxStates[key] boolValue];

            if (isChecked) {
              [cbStyle toggleCheckedAt:checkboxPosition withDirtyRange:NO];
            }
          }
        }
      }
    } else if ([styleType isEqualToNumber:@([UnorderedListStyle getType])] ||
               [styleType isEqualToNumber:@([OrderedListStyle getType])]) {
      NSString *markerValue =
          [stylePair.styleValue isKindOfClass:[NSString class]]
              ? (NSString *)stylePair.styleValue
              : [style getValue];
      [style add:styleRange
               withValue:markerValue
              withTyping:NO
          withDirtyRange:NO];
    } else if ([styleType isEqualToNumber:@([BlockQuoteStyle getType])]) {
      NSString *markerValue =
          [stylePair.styleValue isKindOfClass:[NSString class]]
              ? (NSString *)stylePair.styleValue
              : [style getValue];
      [style add:styleRange
               withValue:markerValue
              withTyping:NO
          withDirtyRange:NO];
    } else {
      [style add:styleRange withTyping:NO withDirtyRange:NO];
    }

    [ZeroWidthSpaceUtils addSpacesIfNeededInHost:_view inRange:styleRange];

    NSInteger delta = _view->textView.textStorage.string.length -
                      textLengthBeforeStyleApplied;
    if (delta > 0 && didApplyImageStyle) {
      for (NSInteger insertionIndex = 0; insertionIndex < delta;
           insertionIndex++) {
        [textStorageInsertions addObject:@(parsedRange.location)];
      }
    } else if (delta > 0) {
      EnrichedHtmlRecordInsertedZeroWidthSpaces(
          textBeforeStyleApplied, _view->textView.textStorage.string,
          textStorageInsertions);
    }

    // Use an adjusted range so that applyStyling covers any ZWS characters that
    // were just inserted by addSpacesIfNeededInHost:inRange:. Without this, a
    // style applied to an empty range {0,0} would call applyStyling on {0,0}
    // even after a ZWS was inserted.
    NSRange adjustedStyleRange = EnrichedHtmlRangeAdjustedForInsertions(
        parsedRange, textStorageInsertions);

    if ([style isParagraph]) {
      NSRange paragraphApplyRange = [style actualUsedRange:adjustedStyleRange];
      NSArray *pendingEntry =
          @[ style, [NSValue valueWithRange:paragraphApplyRange] ];
      if ([styleType isEqualToNumber:@([BlockQuoteStyle getType])]) {
        [pendingBlockQuoteApply addObject:pendingEntry];
      } else if (EnrichedHtmlStyleTypeIsList(styleType)) {
        [pendingListApply addObject:pendingEntry];
      } else if ([styleType isEqualToNumber:@([CodeBlockStyle getType])]) {
        [pendingCodeBlockApply addObject:pendingEntry];
      } else if (EnrichedHtmlStyleTypeIsHeading(styleType)) {
        [pendingHeadingApply
            addObject:@[ style, [NSValue valueWithRange:paragraphApplyRange] ]];
      } else {
        [pendingParagraphApply addObject:pendingEntry];
      }
    } else {
      NSArray *pendingEntry =
          @[ style, [NSValue valueWithRange:adjustedStyleRange] ];
      if ([styleType isEqualToNumber:@([InlineCodeStyle getType])]) {
        [pendingInlineCodeApply addObject:pendingEntry];
      } else {
        [pendingInlineApply addObject:pendingEntry];
      }
    }
  }

  // Blockquote color/layout applies before nested list/code layout so those
  // styles can decide the final paragraph indentation. Headings apply after
  // paragraph containers so they can react to list/quote context.
  EnrichedHtmlApplyPendingStyles(pendingBlockQuoteApply);
  EnrichedHtmlApplyPendingStyles(pendingListApply);
  EnrichedHtmlApplyPendingStyles(pendingCodeBlockApply);
  EnrichedHtmlApplyPendingStyles(pendingParagraphApply);
  EnrichedHtmlApplyPendingStyles(pendingHeadingApply);

  // Apply visual styling for inline styles. Inline code runs last so its
  // foreground and background take precedence over link styling, matching the
  // web code CSS cascade.
  [pendingInlineApply addObjectsFromArray:pendingInlineCodeApply];
  for (NSArray *entry in pendingInlineApply) {
    StyleBase *style = entry[0];
    NSRange adjustedStyleRange = [((NSValue *)entry[1]) rangeValue];
    if ([[style class] getType] == [InlineCodeStyle getType]) {
      CodeBlockStyle *codeBlockStyle =
          _view->stylesDict[@([CodeBlockStyle getType])];
      if (codeBlockStyle != nullptr &&
          [codeBlockStyle any:adjustedStyleRange]) {
        continue;
      }
    }
    [style applyStyling:adjustedStyleRange];
  }
}

- (void)applyProcessedAlignments:(NSArray<AlignmentEntry *> *)alignments {
  AlignmentStyle *alignmentStyle =
      _view.stylesDict[@([AlignmentStyle getType])];

  if (alignmentStyle == nil) {
    return;
  }

  for (AlignmentEntry *entry in alignments) {
    NSRange finalRange = NSMakeRange(entry.range.location, entry.range.length);
    [alignmentStyle addAlignment:entry.alignment
                           range:finalRange
                      withTyping:NO
                  withDirtyRange:NO
                 expandListRange:entry.expandListRange];
    [alignmentStyle applyStyling:finalRange];
  }
}

@end
