#import "ColorExtension.h"
#import "EnrichedTextInputView.h"
#import "FontExtension.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"

static BOOL EnrichedInlineCodeIsDecorativeCharacter(unichar character) {
  return [[NSCharacterSet whitespaceAndNewlineCharacterSet]
             characterIsMember:character] ||
         character == 0x200B || character == 0xFFFC;
}

static BOOL
EnrichedInlineCodeIsInvisibleFormattingCharacter(unichar character) {
  return character == 0x200B || character == 0xFFFC;
}

static NSRange EnrichedInlineCodeVisibleRange(NSString *text, NSRange range) {
  if (range.location >= text.length || range.length == 0) {
    return NSMakeRange(range.location, 0);
  }

  NSUInteger start = range.location;
  NSUInteger end = MIN(NSMaxRange(range), text.length);
  while (start < end && EnrichedInlineCodeIsDecorativeCharacter(
                            [text characterAtIndex:start])) {
    start++;
  }

  while (end > start && EnrichedInlineCodeIsDecorativeCharacter(
                            [text characterAtIndex:end - 1])) {
    end--;
  }

  return NSMakeRange(start, end - start);
}

static BOOL EnrichedInlineCodeAllowsTrailingPadding(NSString *text,
                                                    NSRange visibleRange) {
  NSUInteger nextLocation = NSMaxRange(visibleRange);
  while (nextLocation < text.length &&
         EnrichedInlineCodeIsInvisibleFormattingCharacter(
             [text characterAtIndex:nextLocation])) {
    nextLocation++;
  }

  if (nextLocation >= text.length) {
    return YES;
  }

  unichar nextCharacter = [text characterAtIndex:nextLocation];
  return [[NSCharacterSet whitespaceAndNewlineCharacterSet]
      characterIsMember:nextCharacter];
}

static void
EnrichedInlineCodeApplyTrailingPadding(NSMutableAttributedString *textStorage,
                                       NSString *text, NSRange range,
                                       CGFloat padding) {
  NSRange visibleRange = EnrichedInlineCodeVisibleRange(text, range);
  if (visibleRange.length == 0) {
    return;
  }

  [textStorage removeAttribute:NSKernAttributeName range:visibleRange];
  if (!EnrichedInlineCodeAllowsTrailingPadding(text, visibleRange)) {
    return;
  }

  NSRange trailingCharacterRange = NSMakeRange(NSMaxRange(visibleRange) - 1, 1);
  [textStorage addAttribute:NSKernAttributeName
                      value:@(padding)
                      range:trailingCharacterRange];
}

static BOOL
EnrichedInlineCodeParagraphHasBlockMarker(NSParagraphStyle *pStyle) {
  for (NSTextList *textList in pStyle.textLists) {
    NSString *markerFormat = textList.markerFormat;
    if ([markerFormat isEqualToString:@"EnrichedBlockQuote"] ||
        [markerFormat hasPrefix:@"EnrichedUnorderedList"] ||
        [markerFormat hasPrefix:@"EnrichedOrderedList"] ||
        [markerFormat hasPrefix:@"EnrichedCheckbox"]) {
      return YES;
    }
  }
  return NO;
}

@implementation InlineCodeStyle

+ (StyleType)getType {
  return InlineCode;
}

- (NSString *)getKey {
  return @"EnrichedInlineCode";
}

- (BOOL)isParagraph {
  return NO;
}

- (void)applyStyling:(NSRange)range {
  if (range.location >= self.host.textView.textStorage.length) {
    return;
  }

  NSUInteger safeLength =
      MIN(range.length, self.host.textView.textStorage.length - range.location);
  NSRange safeRange = NSMakeRange(range.location, safeLength);

  NSMutableArray<NSValue *> *styledRanges = [[NSMutableArray alloc] init];
  [self.host.textView.textStorage
      enumerateAttribute:[self getKey]
                 inRange:safeRange
                 options:0
              usingBlock:^(id _Nullable value, NSRange attributeRange,
                           BOOL *_Nonnull stop) {
                if ([self styleCondition:value range:attributeRange]) {
                  [styledRanges
                      addObject:[NSValue valueWithRange:attributeRange]];
                }
              }];

  NSMutableArray<NSValue *> *nonNewlineRanges = [[NSMutableArray alloc] init];
  for (NSValue *value in styledRanges) {
    [nonNewlineRanges
        addObjectsFromArray:[RangeUtils
                                getNonNewlineRangesIn:self.host.textView
                                                range:[value rangeValue]]];
  }

  for (NSValue *value in nonNewlineRanges) {
    NSRange subRange = [value rangeValue];
    NSRange visibleRange = EnrichedInlineCodeVisibleRange(
        self.host.textView.textStorage.string, subRange);
    if (visibleRange.length == 0) {
      continue;
    }
    [self.host.textView.textStorage
        removeAttribute:NSBackgroundColorAttributeName
                  range:visibleRange];
    [self.host.textView.textStorage
        addAttribute:NSForegroundColorAttributeName
               value:[self.host.config inlineCodeFgColor]
               range:visibleRange];
    [self.host.textView.textStorage
        addAttribute:NSUnderlineColorAttributeName
               value:[self.host.config inlineCodeFgColor]
               range:visibleRange];
    [self.host.textView.textStorage
        addAttribute:NSStrikethroughColorAttributeName
               value:[self.host.config inlineCodeFgColor]
               range:visibleRange];
    [self.host.textView.textStorage
        enumerateAttribute:NSFontAttributeName
                   inRange:visibleRange
                   options:0
                usingBlock:^(id _Nullable value, NSRange fontRange,
                             BOOL *_Nonnull stop) {
                  UIFont *font = (UIFont *)value;
                  if (font != nullptr) {
                    UIFont *newFont = [[[self.host.config monospacedFont]
                        withFontTraits:font] setSize:font.pointSize];
                    [self.host.textView.textStorage
                        addAttribute:NSFontAttributeName
                               value:newFont
                               range:fontRange];
                  }
                }];
    EnrichedInlineCodeApplyTrailingPadding(
        self.host.textView.textStorage, self.host.textView.textStorage.string,
        visibleRange, 3.0);
  }

  NSMutableSet<NSString *> *spacedParagraphs = [[NSMutableSet alloc] init];
  NSString *text = self.host.textView.textStorage.string;
  for (NSValue *value in nonNewlineRanges) {
    NSRange subRange = [value rangeValue];
    if (subRange.location >= text.length) {
      continue;
    }

    NSRange paragraphRange = [text paragraphRangeForRange:subRange];
    NSString *paragraphKey = NSStringFromRange(paragraphRange);
    if ([spacedParagraphs containsObject:paragraphKey]) {
      continue;
    }

    NSRange visibleParagraphRange =
        EnrichedInlineCodeVisibleRange(text, paragraphRange);
    if (visibleParagraphRange.length == 0 ||
        visibleParagraphRange.location < subRange.location ||
        NSMaxRange(visibleParagraphRange) > NSMaxRange(subRange)) {
      continue;
    }

    NSParagraphStyle *existingStyle =
        [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                          atIndex:visibleParagraphRange.location
                                   effectiveRange:nil];
    if (existingStyle != nullptr &&
        EnrichedInlineCodeParagraphHasBlockMarker(existingStyle)) {
      continue;
    }

    NSMutableParagraphStyle *pStyle =
        existingStyle != nullptr ? [existingStyle mutableCopy]
                                 : [[NSMutableParagraphStyle alloc] init];
    pStyle.paragraphSpacingBefore = MAX(pStyle.paragraphSpacingBefore, 3.0);
    pStyle.paragraphSpacing = MAX(pStyle.paragraphSpacing, 5.0);
    [self.host.textView.textStorage addAttribute:NSParagraphStyleAttributeName
                                           value:pStyle
                                           range:paragraphRange];
    [spacedParagraphs addObject:paragraphKey];
  }
}

@end
