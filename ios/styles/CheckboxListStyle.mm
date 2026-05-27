#import "EnrichedTextInputView.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"

static BOOL EnrichedCheckboxMarkerMatches(NSString *markerFormat) {
  return markerFormat != nullptr &&
         [markerFormat hasPrefix:@"EnrichedCheckbox"];
}

static BOOL EnrichedCheckboxMarkerIsChecked(NSString *markerFormat) {
  return markerFormat != nullptr &&
         [markerFormat hasPrefix:@"EnrichedCheckbox1"];
}

static NSInteger EnrichedCheckboxLevelFromMarker(NSString *markerFormat) {
  if (!EnrichedCheckboxMarkerMatches(markerFormat)) {
    return -1;
  }
  NSRange separator = [markerFormat rangeOfString:@":"];
  if (separator.location == NSNotFound) {
    return 0;
  }
  NSString *levelString =
      [markerFormat substringFromIndex:separator.location + separator.length];
  return MAX(0, [levelString integerValue]);
}

static NSInteger EnrichedCheckboxLevelInParagraph(NSParagraphStyle *pStyle) {
  NSInteger level = 0;
  for (NSTextList *textList in pStyle.textLists) {
    NSInteger markerLevel =
        EnrichedCheckboxLevelFromMarker(textList.markerFormat);
    if (markerLevel > level) {
      level = markerLevel;
    }
  }
  return level;
}

@interface CheckboxListStyle ()
- (NSString *)getCheckboxMarkerAt:(NSUInteger)location;
@end

@implementation CheckboxListStyle

+ (StyleType)getType {
  return CheckboxList;
}

- (NSString *)getValue {
  return @"EnrichedCheckbox0";
}

- (NSString *)getMarkerPrefix {
  return @"EnrichedCheckbox";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  CGFloat baseMargin = [self.host.config checkboxListMarginLeft];
  CGFloat gapWidth = [self.host.config checkboxListGapWidth];
  CGFloat boxSize = [self.host.config checkboxListBoxSize];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange range,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)value mutableCopy];
                NSInteger level = EnrichedCheckboxLevelInParagraph(pStyle);
                CGFloat listHeadIndent =
                    baseMargin * (level + 1) + gapWidth + boxSize;
                pStyle.headIndent = listHeadIndent;
                pStyle.firstLineHeadIndent = listHeadIndent;
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:range];
              }];
}

- (BOOL)styleCondition:(id)value range:(NSRange)range {
  NSParagraphStyle *pStyle = (NSParagraphStyle *)value;
  if (pStyle == nullptr) {
    return NO;
  }
  for (NSTextList *textList in pStyle.textLists) {
    if (EnrichedCheckboxMarkerMatches(textList.markerFormat)) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)matchesParagraphMarker:(NSString *)markerFormat
                          value:(NSString *)value {
  return EnrichedCheckboxMarkerMatches(markerFormat);
}

- (void)toggleWithChecked:(BOOL)checked range:(NSRange)range {
  NSRange actualRange = [self actualUsedRange:range];
  BOOL isPresent = [self detect:actualRange];

  if (isPresent) {
    [self remove:actualRange withDirtyRange:YES];
  } else {
    [self addWithChecked:checked
                   range:actualRange
              withTyping:YES
          withDirtyRange:YES];
  }
}

- (void)addWithChecked:(BOOL)checked
                 range:(NSRange)range
            withTyping:(BOOL)withTyping
        withDirtyRange:(BOOL)withDirtyRange {
  NSString *value = checked ? @"EnrichedCheckbox1" : @"EnrichedCheckbox0";
  [self add:range
           withValue:value
          withTyping:withTyping
      withDirtyRange:withDirtyRange];
}

// During dirty range re-application the default add: would use getValue
// (EnrichedCheckbox0) and lose the checked state. Instead, read the original
// marker format from the saved StylePair
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  NSParagraphStyle *savedPStyle = (NSParagraphStyle *)pair.styleValue;
  BOOL checked = NO;
  if (savedPStyle != nullptr) {
    for (NSTextList *textList in savedPStyle.textLists) {
      if (EnrichedCheckboxMarkerMatches(textList.markerFormat)) {
        checked = EnrichedCheckboxMarkerIsChecked(textList.markerFormat);
        break;
      }
    }
  }
  [self addWithChecked:checked range:range withTyping:NO withDirtyRange:NO];
}

- (void)toggleCheckedAt:(NSUInteger)location
         withDirtyRange:(BOOL)withDirtyRange {
  if (location >= self.host.textView.textStorage.length) {
    return;
  }

  NSString *marker = [self getCheckboxMarkerAt:location];
  BOOL isCurrentlyChecked = EnrichedCheckboxMarkerIsChecked(marker);

  NSRange paragraphRange = [self.host.textView.textStorage.string
      paragraphRangeForRange:NSMakeRange(location, 0)];

  [self addWithChecked:!isCurrentlyChecked
                 range:paragraphRange
            withTyping:NO
        withDirtyRange:withDirtyRange];
}

- (NSString *)getCheckboxMarkerAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return nil;
  }

  NSParagraphStyle *style =
      [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                        atIndex:location
                                 effectiveRange:NULL];

  if (style && style.textLists.count > 0) {
    for (NSTextList *list in style.textLists) {
      if (EnrichedCheckboxMarkerMatches(list.markerFormat)) {
        return list.markerFormat;
      }
    }
  }

  return nil;
}

- (BOOL)getCheckboxStateAt:(NSUInteger)location {
  NSString *marker = [self getCheckboxMarkerAt:location];
  if (marker != nil) {
    if (EnrichedCheckboxMarkerIsChecked(marker)) {
      return YES;
    }
    return NO;
  }

  return NO;
}

- (BOOL)handleNewlinesInRange:(NSRange)range replacementText:(NSString *)text {
  if ([self detect:self.host.textView.selectedRange] && text.length > 0 &&
      [[NSCharacterSet newlineCharacterSet]
          characterIsMember:[text characterAtIndex:text.length - 1]]) {
    // do the replacement manually
    [TextInsertionUtils replaceText:text
                                 at:range
               additionalAttributes:nullptr
                               host:self.host
                      withSelection:YES];
    // apply unchecked checkbox attributes to the new paragraph
    [self addWithChecked:NO
                   range:self.host.textView.selectedRange
              withTyping:YES
          withDirtyRange:YES];
    return YES;
  }
  return NO;
}

@end
