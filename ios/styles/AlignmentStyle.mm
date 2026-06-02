#import "AlignmentUtils.h"
#import "StyleHeaders.h"
#import "TextListsUtils.h"

@implementation AlignmentStyle

+ (StyleType)getType {
  return Alignment;
}

- (NSString *)getValue {
  return @"EnrichedAlignmentNatural";
}

- (NSString *)getMarkerPrefix {
  return @"EnrichedAlignment";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)appliesStylingToTyping {
  return YES;
}

- (void)toggle:(NSRange)range {
  // no-op for alignments
}

- (void)applyStyling:(NSRange)range {
  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)value mutableCopy];

                NSString *marker =
                    [TextListsUtils
                        firstTextListWithPrefix:[self getMarkerPrefix]
                                        inArray:pStyle.textLists]
                        .markerFormat;
                NSTextAlignment alignment =
                    [AlignmentUtils markerToAlignment:marker];
                pStyle.alignment = alignment;
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:subRange];
              }];
}

- (NSRange)actualUsedRange:(NSRange)range {
  NSRange paragraphRange =
      [self.host.textView.textStorage.string paragraphRangeForRange:range];
  return [self expandRangeToContiguousList:paragraphRange];
}

- (void)addAlignment:(NSTextAlignment)alignment
               range:(NSRange)range
          withTyping:(BOOL)withTyping
      withDirtyRange:(BOOL)withDirtyRange {
  [self addAlignment:alignment
                range:range
           withTyping:withTyping
       withDirtyRange:withDirtyRange
      expandListRange:YES];
}

- (void)addAlignment:(NSTextAlignment)alignment
               range:(NSRange)range
          withTyping:(BOOL)withTyping
      withDirtyRange:(BOOL)withDirtyRange
     expandListRange:(BOOL)expandListRange {
  NSString *value = [AlignmentUtils alignmentToMarker:alignment];

  if (expandListRange) {
    [self add:range
             withValue:value
            withTyping:withTyping
        withDirtyRange:withDirtyRange];
    return;
  }

  NSString *text = self.host.textView.textStorage.string;
  if (text.length == 0)
    return;

  NSRange paragraphRange = [text paragraphRangeForRange:range];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:paragraphRange
                 options:0
              usingBlock:^(id _Nullable existingValue, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)existingValue mutableCopy];
                if (pStyle == nullptr)
                  return;

                NSMutableArray<NSTextList *> *textLists =
                    [pStyle.textLists mutableCopy];
                if (textLists == nullptr) {
                  textLists = [[NSMutableArray alloc] init];
                }

                NSIndexSet *matchingIndexes = [textLists
                    indexesOfObjectsPassingTest:^BOOL(
                        NSTextList *textList, NSUInteger idx, BOOL *stop) {
                      return [self matchesParagraphMarker:textList.markerFormat
                                                    value:value];
                    }];
                [textLists removeObjectsAtIndexes:matchingIndexes];
                [textLists
                    addObject:[[NSTextList alloc] initWithMarkerFormat:value
                                                               options:0]];
                pStyle.textLists = textLists;
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:subRange];
              }];

  if (withTyping) {
    [self addTypingWithValue:value];
  }

  if (withDirtyRange &&
      [self.host respondsToSelector:@selector(attributesManager)]) {
    [self.host.attributesManager addDirtyRange:paragraphRange];
  }
}

- (BOOL)styleCondition:(id)value range:(NSRange)range {
  NSParagraphStyle *pStyle = (NSParagraphStyle *)value;
  if (pStyle == nil)
    return NO;
  return [TextListsUtils textLists:pStyle.textLists
                    containsPrefix:[self getMarkerPrefix]];
}

- (BOOL)matchesParagraphMarker:(NSString *)markerFormat
                         value:(NSString *)value {
  return markerFormat != nullptr &&
         [markerFormat hasPrefix:[self getMarkerPrefix]];
}

- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  NSParagraphStyle *savedPStyle = pair.styleValue;
  NSString *markerFormat =
      [TextListsUtils firstTextListWithPrefix:[self getMarkerPrefix]
                                      inArray:savedPStyle.textLists]
          .markerFormat;
  if (markerFormat == nil)
    return;

  [self add:range withValue:markerFormat withTyping:NO withDirtyRange:NO];
}

- (NSString *)getStyleState {
  UITextView *textView = self.host.textView;
  NSParagraphStyle *paraStyle =
      textView.typingAttributes[NSParagraphStyleAttributeName];

  NSString *marker =
      [TextListsUtils firstTextListWithPrefix:[self getMarkerPrefix]
                                      inArray:paraStyle.textLists]
          .markerFormat;

  NSTextAlignment currentAlignment = [AlignmentUtils markerToAlignment:marker];
  return [AlignmentUtils alignmentToString:currentAlignment];
}

- (void)applyStylingToTypingAttrs:(NSMutableDictionary *)attributes {
  NSMutableParagraphStyle *pStyle =
      [attributes[NSParagraphStyleAttributeName] mutableCopy];
  if (pStyle == nil)
    return;
  NSString *marker =
      [TextListsUtils firstTextListWithPrefix:[self getMarkerPrefix]
                                      inArray:pStyle.textLists]
          .markerFormat;
  NSTextAlignment alignment = [AlignmentUtils markerToAlignment:marker];
  pStyle.alignment = alignment;
  attributes[NSParagraphStyleAttributeName] = pStyle;
}

- (NSRange)expandRangeToContiguousList:(NSRange)range {
  NSString *text = self.host.textView.textStorage.string;
  if (text.length == 0)
    return range;

  NSArray<StyleBase *> *listStyles = @[
    self.host.stylesDict[@([UnorderedListStyle getType])],
    self.host.stylesDict[@([OrderedListStyle getType])],
    self.host.stylesDict[@([CheckboxListStyle getType])]
  ];

  NSRange expandedRange = range;

  // Expand Backward
  NSRange startParagraph =
      [text paragraphRangeForRange:NSMakeRange(range.location, 0)];

  // Find which list style is active at the start
  StyleBase *activeStartStyle = nil;
  for (StyleBase *style in listStyles) {
    if ([style detect:startParagraph]) {
      activeStartStyle = style;
      break;
    }
  }

  // If we found a list style, walk backwards until it stops
  if (activeStartStyle) {
    NSRange currentPara = startParagraph;
    while (currentPara.location > 0) {
      // Check the paragraph before the current one
      NSRange prevPara = [text
          paragraphRangeForRange:NSMakeRange(currentPara.location - 1, 0)];

      if ([activeStartStyle detect:prevPara]) {
        // It's still the same list -> Expand our range.
        expandedRange = NSUnionRange(expandedRange, prevPara);
        currentPara = prevPara;
      } else {
        // The list ended here.
        break;
      }
    }
  }

  // Expand forward, we check the paragraph at the end of the current selection
  NSUInteger endLoc =
      (range.length > 0) ? (NSMaxRange(range) - 1) : range.location;
  NSRange endParagraph = [text paragraphRangeForRange:NSMakeRange(endLoc, 0)];

  // Find which list style is active at the end
  StyleBase *activeEndStyle = nil;
  for (StyleBase *style in listStyles) {
    if ([style detect:endParagraph]) {
      activeEndStyle = style;
      break;
    }
  }

  // If we found a list style, walk forwards until it stops
  if (activeEndStyle) {
    NSRange currentPara = endParagraph;
    while (NSMaxRange(currentPara) < text.length) {
      // Check the paragraph after the current one
      NSRange nextPara =
          [text paragraphRangeForRange:NSMakeRange(NSMaxRange(currentPara), 0)];

      if ([activeEndStyle detect:nextPara]) {
        // It's still the same list -> expand our range.
        expandedRange = NSUnionRange(expandedRange, nextPara);
        currentPara = nextPara;
      } else {
        break;
      }
    }
  }

  return expandedRange;
}

@end
