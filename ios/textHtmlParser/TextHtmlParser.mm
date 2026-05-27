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

- (void)applyProcessedStyles:(NSArray *_Nonnull)processedStyles {
  // Some paragraph styles (codeblock, blockquote, etc.) insert \u200B
  // into empty lines, mutating NSTextStorage length. We need to
  // shift subsequent ranges by this offset.
  NSInteger zeroWidthSpaceOffset = 0;

  // Inline styles collected during the first pass so their applyStyling: can
  // be re-run after all paragraph styles have applied their visual attributes.
  // Each entry is @[style, adjustedRange].
  NSMutableArray *pendingInlineApply = [NSMutableArray array];
  NSMutableArray *pendingInlineCodeApply = [NSMutableArray array];
  NSMutableArray *pendingHeadingApply = [NSMutableArray array];

  // Paragraph styles call applyStyling: immediately; inline styles
  // defer it so that paragraph visual attributes are already in
  // place when inline styles override them.
  for (NSArray *arr in processedStyles) {
    NSNumber *styleType = (NSNumber *)arr[0];
    StylePair *stylePair = (StylePair *)arr[1];
    StyleBase *style = _view->stylesDict[styleType];
    if (style == nullptr)
      continue;

    NSRange parsedRange = [stylePair.rangeValue rangeValue];
    NSUInteger textLengthBeforeStyleApplied =
        _view->textView.textStorage.string.length;

    // Range must be taking zeroWidthSpaceOffset into consideration
    // because processed styles ranges are relative to only the new text while
    // we need absolute ranges relative to the whole existing text
    NSRange styleRange = NSMakeRange(
        zeroWidthSpaceOffset + parsedRange.location, parsedRange.length);

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
    } else if ([styleType isEqualToNumber:@([CheckboxListStyle getType])]) {
      NSDictionary *checkboxStates = (NSDictionary *)stylePair.styleValue;
      CheckboxListStyle *cbStyle = (CheckboxListStyle *)style;

      [cbStyle addWithChecked:NO
                        range:styleRange
                   withTyping:NO
               withDirtyRange:NO];

      if (checkboxStates && checkboxStates.count > 0) {
        for (NSNumber *key in checkboxStates) {
          NSUInteger checkboxPosition =
              zeroWidthSpaceOffset + [key unsignedIntegerValue];
          BOOL isChecked = [checkboxStates[key] boolValue];

          if (isChecked) {
            [cbStyle toggleCheckedAt:checkboxPosition withDirtyRange:NO];
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

    // Use an adjusted range so that applyStyling covers any ZWS characters that
    // were just inserted by addSpacesIfNeededInHost:inRange:. Without this, a
    // style applied to an empty range {0,0} would call applyStyling on {0,0}
    // even after a ZWS was inserted.
    NSRange adjustedStyleRange = NSMakeRange(
        styleRange.location, styleRange.length + (NSUInteger)MAX(0LL, delta));

    BOOL isHeadingStyle =
        [styleType isEqualToNumber:@([H1Style getType])] ||
        [styleType isEqualToNumber:@([H2Style getType])] ||
        [styleType isEqualToNumber:@([H3Style getType])] ||
        [styleType isEqualToNumber:@([H4Style getType])] ||
        [styleType isEqualToNumber:@([H5Style getType])] ||
        [styleType isEqualToNumber:@([H6Style getType])];

    if ([style isParagraph]) {
      if (isHeadingStyle) {
        [pendingHeadingApply
            addObject:@[ style, [NSValue valueWithRange:adjustedStyleRange] ]];
      } else {
        [style applyStyling:adjustedStyleRange];
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

    // Image shifts are already handled by _precedingImageCount during tag
    // finalization.
    if (delta != 0 && ![styleType isEqualToNumber:@([ImageStyle getType])]) {
      zeroWidthSpaceOffset += delta;
    }
  }

  // Headings apply after paragraph container styles so they can react to
  // context such as headings nested inside list items or blockquotes.
  for (NSArray *entry in pendingHeadingApply) {
    StyleBase *style = entry[0];
    NSRange adjustedStyleRange = [((NSValue *)entry[1]) rangeValue];
    [style applyStyling:adjustedStyleRange];
  }

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
                  withDirtyRange:NO];
    [alignmentStyle applyStyling:finalRange];
  }
}

@end
