#import "EnrichedTextInputView.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "StyleUtils.h"
#import "TextInsertionUtils.h"

static BOOL EnrichedListMarkerMatches(NSString *markerFormat,
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

static NSInteger EnrichedListLevelFromMarker(NSString *markerFormat,
                                             NSString *baseValue) {
  if (!EnrichedListMarkerMatches(markerFormat, baseValue)) {
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

  if ([markerFormat isEqualToString:matchedBaseValue]) {
    return 0;
  }
  NSString *prefix = [matchedBaseValue stringByAppendingString:@":"];
  NSString *levelString = [markerFormat substringFromIndex:prefix.length];
  return MAX(0, [levelString integerValue]);
}

static NSInteger EnrichedListLevelInParagraph(NSParagraphStyle *pStyle,
                                              NSString *baseValue) {
  NSInteger level = 0;
  for (NSTextList *textList in pStyle.textLists) {
    NSInteger markerLevel =
        EnrichedListLevelFromMarker(textList.markerFormat, baseValue);
    if (markerLevel > level) {
      level = markerLevel;
    }
  }
  return level;
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

@implementation OrderedListStyle

+ (StyleType)getType {
  return OrderedList;
}

- (NSString *)getValue {
  return @"EnrichedOrderedList";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  // lists are drawn manually
  // margin before marker + gap between marker and paragraph
  CGFloat baseMargin = [self.host.config orderedListMarginLeft];
  CGFloat gapWidth = [self.host.config orderedListGapWidth];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange range,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)value mutableCopy];
                NSInteger level =
                    EnrichedListLevelInParagraph(pStyle, [self getValue]);
                CGFloat blockquoteIndent =
                    EnrichedParagraphHasBlockQuote(pStyle)
                        ? [self.host.config blockquoteBorderWidth] +
                              [self.host.config blockquoteGapWidth]
                        : 0.0;
                CGFloat listHeadIndent =
                    baseMargin * (level + 1) + gapWidth + blockquoteIndent;
                pStyle.headIndent = listHeadIndent;
                pStyle.firstLineHeadIndent = listHeadIndent;
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:range];
              }];
}

- (BOOL)matchesParagraphMarker:(NSString *)markerFormat
                          value:(NSString *)value {
  return EnrichedListMarkerMatches(markerFormat, value);
}

- (BOOL)tryHandlingListShorcutInRange:(NSRange)range
                      replacementText:(NSString *)text {
  NSRange paragraphRange =
      [self.host.textView.textStorage.string paragraphRangeForRange:range];
  // a dot was added - check if we are both at the paragraph beginning + 1
  // character (which we want to be a digit '1')
  if ([text isEqualToString:@"."] &&
      range.location - 1 == paragraphRange.location) {
    unichar charBefore = [self.host.textView.textStorage.string
        characterAtIndex:range.location - 1];
    if (charBefore == '1') {
      // we got a match - add a list if possible
      if ([StyleUtils handleStyleBlocksAndConflicts:[[self class] getType]
                                              range:paragraphRange
                                            forHost:self.host]) {
        // don't emit during the replacing
        self.host.blockEmitting = YES;

        // remove the number
        [TextInsertionUtils replaceText:@""
                                     at:NSMakeRange(paragraphRange.location, 1)
                   additionalAttributes:nullptr
                                   host:self.host
                          withSelection:YES];

        self.host.blockEmitting = NO;

        // add attributes on the paragraph
        [self add:NSMakeRange(paragraphRange.location,
                              paragraphRange.length - 1)
                withTyping:YES
            withDirtyRange:YES];

        return YES;
      }
    }
  }
  return NO;
}

@end
