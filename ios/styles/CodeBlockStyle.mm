#import "EnrichedTextInputView.h"
#import "FontExtension.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"

static BOOL EnrichedCodeBlockParagraphHasVisibleContent(NSString *text,
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
  [normalized replaceOccurrencesOfString:@"\uFFFC"
                              withString:@""
                                 options:0
                                   range:NSMakeRange(0, normalized.length)];

  NSString *trimmed = [normalized
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  return trimmed.length > 0;
}

@implementation CodeBlockStyle

+ (StyleType)getType {
  return CodeBlock;
}

- (NSString *)getValue {
  return @"EnrichedCodeBlock";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  CGFloat horizontalPadding = 12.0;
  NSArray *paragraphs =
      [RangeUtils getSeparateParagraphsRangesIn:self.host.textView range:range];
  NSString *text = self.host.textView.textStorage.string;
  NSRange firstVisibleParagraphRange = NSMakeRange(NSNotFound, 0);
  NSRange lastVisibleParagraphRange = NSMakeRange(NSNotFound, 0);

  for (NSValue *paragraphValue in paragraphs) {
    NSRange paragraphRange = [paragraphValue rangeValue];
    if (!EnrichedCodeBlockParagraphHasVisibleContent(text, paragraphRange)) {
      continue;
    }

    if (firstVisibleParagraphRange.location == NSNotFound) {
      firstVisibleParagraphRange = paragraphRange;
    }
    lastVisibleParagraphRange = paragraphRange;
  }

  if (firstVisibleParagraphRange.location == NSNotFound) {
    firstVisibleParagraphRange =
        paragraphs.count > 0
            ? [((NSValue *)[paragraphs firstObject]) rangeValue]
            : range;
    lastVisibleParagraphRange =
        paragraphs.count > 0 ? [((NSValue *)[paragraphs lastObject]) rangeValue]
                             : range;
  }

  for (NSValue *paragraphValue in paragraphs) {
    NSRange paragraphRange = [paragraphValue rangeValue];
    if (paragraphRange.location >= self.host.textView.textStorage.length) {
      continue;
    }

    NSParagraphStyle *existingStyle =
        [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                          atIndex:paragraphRange.location
                                   effectiveRange:nil];
    NSMutableParagraphStyle *pStyle =
        existingStyle != nullptr ? [existingStyle mutableCopy]
                                 : [[NSMutableParagraphStyle alloc] init];

    pStyle.headIndent = MAX(pStyle.headIndent, horizontalPadding);
    pStyle.firstLineHeadIndent =
        MAX(pStyle.firstLineHeadIndent, horizontalPadding);
    if (pStyle.tailIndent == 0.0) {
      pStyle.tailIndent = -horizontalPadding;
    } else if (pStyle.tailIndent < 0.0) {
      pStyle.tailIndent = MIN(pStyle.tailIndent, -horizontalPadding);
    }
    pStyle.paragraphSpacingBefore =
        NSEqualRanges(paragraphRange, firstVisibleParagraphRange)
            ? MAX(pStyle.paragraphSpacingBefore, 6.0)
            : 0.0;
    BOOL isLastVisibleParagraph =
        NSEqualRanges(paragraphRange, lastVisibleParagraphRange);
    BOOL isAtDocumentEnd =
        NSMaxRange(paragraphRange) >= self.host.textView.textStorage.length;
    CGFloat trailingSpacing = isAtDocumentEnd ? 28.0 : 12.0;
    pStyle.paragraphSpacing =
        isLastVisibleParagraph ? MAX(pStyle.paragraphSpacing, trailingSpacing)
                               : 0.0;
    [self.host.textView.textStorage addAttribute:NSParagraphStyleAttributeName
                                           value:pStyle
                                           range:paragraphRange];
  }

  [self.host.textView.textStorage
      enumerateAttribute:NSFontAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange subRange,
                           BOOL *_Nonnull stop) {
                UIFont *currentFont = (UIFont *)value;
                if (currentFont == nullptr)
                  return;
                UIFont *monoFont = [[[self.host.config monospacedFont]
                    withFontTraits:currentFont] setSize:currentFont.pointSize];
                if (monoFont != nullptr) {
                  [self.host.textView.textStorage
                      addAttribute:NSFontAttributeName
                             value:monoFont
                             range:subRange];
                }
              }];

  [self.host.textView.textStorage
      addAttribute:NSForegroundColorAttributeName
             value:[self.host.config codeBlockFgColor]
             range:range];
}

@end
