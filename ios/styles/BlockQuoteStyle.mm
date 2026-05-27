#import "ColorExtension.h"
#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"

@implementation BlockQuoteStyle

static BOOL EnrichedBlockQuoteListMarkerMatches(NSString *markerFormat,
                                                NSString *baseValue) {
  if (markerFormat == nullptr) {
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

static NSInteger EnrichedBlockQuoteListLevel(NSString *markerFormat,
                                             NSString *baseValue) {
  if (!EnrichedBlockQuoteListMarkerMatches(markerFormat, baseValue)) {
    return -1;
  }

  NSString *matchedBaseValue = baseValue;
  NSString *continuationBaseValue =
      [baseValue stringByAppendingString:@"Continuation"];
  if ([markerFormat isEqualToString:continuationBaseValue] ||
      [markerFormat
          hasPrefix:[continuationBaseValue stringByAppendingString:@":"]]) {
    matchedBaseValue = continuationBaseValue;
  }

  NSRange separator = [markerFormat rangeOfString:@":"];
  if (separator.location == NSNotFound) {
    return 0;
  }

  if (separator.location < matchedBaseValue.length) {
    return 0;
  }

  NSString *levelString =
      [markerFormat substringFromIndex:separator.location + separator.length];
  return MAX(0, [levelString integerValue]);
}

static BOOL EnrichedBlockQuoteHasNestedLayoutMarker(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (EnrichedBlockQuoteListMarkerMatches(markerFormat,
                                            @"EnrichedUnorderedList") ||
        EnrichedBlockQuoteListMarkerMatches(markerFormat,
                                            @"EnrichedOrderedList") ||
        [markerFormat hasPrefix:@"EnrichedCheckbox"] ||
        [markerFormat isEqualToString:@"EnrichedCodeBlock"]) {
      return YES;
    }
  }
  return NO;
}

static NSString *EnrichedBlockQuoteMarker(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if (EnrichedBlockQuoteListMarkerMatches(markerFormat,
                                            @"EnrichedBlockQuote")) {
      return markerFormat;
    }
  }
  return nil;
}

+ (StyleType)getType {
  return BlockQuote;
}

- (NSString *)getValue {
  return @"EnrichedBlockQuote";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)matchesParagraphMarker:(NSString *)markerFormat
                          value:(NSString *)value {
  return EnrichedBlockQuoteListMarkerMatches(markerFormat,
                                             @"EnrichedBlockQuote") &&
         EnrichedBlockQuoteListMarkerMatches(value, @"EnrichedBlockQuote");
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  CGFloat blockquoteIndent = [self.host.config blockquoteBorderWidth] +
                             [self.host.config blockquoteGapWidth];
  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    value != nullptr ? [(NSParagraphStyle *)value mutableCopy]
                                     : [[NSMutableParagraphStyle alloc] init];
                CGFloat listIndent = 0.0;
                for (NSTextList *textList in pStyle.textLists) {
                  NSString *markerFormat = textList.markerFormat;
                  NSInteger unorderedLevel = EnrichedBlockQuoteListLevel(
                      markerFormat, @"EnrichedUnorderedList");
                  if (unorderedLevel >= 0) {
                    listIndent = MAX(
                        listIndent,
                        [self.host.config unorderedListMarginLeft] *
                                (unorderedLevel + 1) +
                            [self.host.config unorderedListGapWidth]);
                  }

                  NSInteger orderedLevel = EnrichedBlockQuoteListLevel(
                      markerFormat, @"EnrichedOrderedList");
                  if (orderedLevel >= 0) {
                    listIndent = MAX(
                        listIndent,
                        [self.host.config orderedListMarginLeft] *
                                (orderedLevel + 1) +
                            [self.host.config orderedListGapWidth]);
                  }
                }

                CGFloat existingIndent =
                    MAX(pStyle.headIndent, pStyle.firstLineHeadIndent);
                CGFloat indent = MAX(existingIndent, listIndent) +
                                 blockquoteIndent;
                pStyle.headIndent = indent;
                pStyle.firstLineHeadIndent = indent;
                if (!EnrichedBlockQuoteHasNestedLayoutMarker(pStyle)) {
                  pStyle.paragraphSpacingBefore =
                      MAX(pStyle.paragraphSpacingBefore, 4.0);
                  pStyle.paragraphSpacing = MAX(pStyle.paragraphSpacing, 6.0);
                }
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:subRange];
              }];
}

- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  NSString *value =
      EnrichedBlockQuoteMarker((NSParagraphStyle *)pair.styleValue);
  if (value == nil) {
    value = [self getValue];
  }

  [self add:range withValue:value withTyping:NO withDirtyRange:NO];
}

@end
