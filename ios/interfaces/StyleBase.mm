#import "StyleBase.h"
#import "AttributeEntry.h"
#import "OccurenceUtils.h"
#import "RangeUtils.h"
#import "ZeroWidthSpaceUtils.h"

@implementation StyleBase

static BOOL EnrichedIsListMarker(NSString *markerFormat, NSString *baseValue) {
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

static BOOL EnrichedShouldKeepParagraphMarkerWhenAdding(NSString *markerFormat,
                                                        NSString *value) {
  if ([markerFormat isEqualToString:value]) {
    return NO;
  }

  return (EnrichedIsListMarker(markerFormat, @"EnrichedUnorderedList") &&
          EnrichedIsListMarker(value, @"EnrichedUnorderedList")) ||
         (EnrichedIsListMarker(markerFormat, @"EnrichedOrderedList") &&
          EnrichedIsListMarker(value, @"EnrichedOrderedList"));
}

// This method gets overridden
+ (StyleType)getType {
  return None;
}

// This method gets overridden for inline styles
- (NSString *)getKey {
  if ([self isParagraph]) {
    return NSParagraphStyleAttributeName;
  }
  return @"NoneAttribute";
}

// Basic inline styles will use this default value, paragraph styles will
// override it and parametrised ones completely don't use it
- (NSString *)getValue {
  return @"AnyValue";
}

// Paragraph styles that store a family of mutually exclusive markers (e.g.
// alignment variants) should override this to return the shared prefix.
- (NSString *)getMarkerPrefix {
  return nil;
}

// This method gets overridden
- (BOOL)isParagraph {
  return false;
}

- (BOOL)needsZWS {
  return NO;
}

- (BOOL)appliesStylingToTyping {
  return NO;
}

- (instancetype)initWithHost:(id<EnrichedViewHost>)host {
  self = [super init];
  _host = host;
  return self;
}

// aligns range to whole paragraph for the paragraph stlyes
- (NSRange)actualUsedRange:(NSRange)range {
  if (![self isParagraph])
    return range;
  return [self.host.textView.textStorage.string paragraphRangeForRange:range];
}

- (void)toggle:(NSRange)range {
  NSRange actualRange = [self actualUsedRange:range];

  BOOL isPresent = [self detect:actualRange];
  if (actualRange.length >= 1) {
    isPresent ? [self remove:actualRange withDirtyRange:YES]
              : [self add:actualRange withTyping:YES withDirtyRange:YES];
  } else {
    isPresent ? [self removeTyping] : [self addTypingWithValue:[self getValue]];
  }
}

- (void)add:(NSRange)range
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange {
  [self add:range
           withValue:[self getValue]
          withTyping:withTyping
      withDirtyRange:withDirtyRange];
}

- (void)add:(NSRange)range
         withValue:(NSString *)value
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange {
  NSRange actualRange = [self actualUsedRange:range];

  if (![self isParagraph]) {
    [self.host.textView.textStorage addAttribute:[self getKey]
                                           value:value
                                           range:actualRange];
  } else {
    [self.host.textView.textStorage
        enumerateAttribute:NSParagraphStyleAttributeName
                   inRange:actualRange
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
                      indexesOfObjectsPassingTest:^BOOL(NSTextList *textList,
                                                        NSUInteger idx,
                                                        BOOL *stop) {
                        NSString *markerFormat = textList.markerFormat;
                        return [self matchesParagraphMarker:markerFormat
                                                      value:value] &&
                               !EnrichedShouldKeepParagraphMarkerWhenAdding(
                                   markerFormat, value);
                      }];
                  [textLists removeObjectsAtIndexes:matchingIndexes];
                  [textLists addObject:[[NSTextList alloc]
                                           initWithMarkerFormat:value
                                                        options:0]];
                  pStyle.textLists = textLists;
                  [self.host.textView.textStorage
                      addAttribute:NSParagraphStyleAttributeName
                             value:pStyle
                             range:subRange];
                }];
  }

  if (withTyping) {
    [self addTypingWithValue:value];
  }

  // Notify attributes manager of styling to be re-done if needed.
  if (withDirtyRange) {
    [self.host.attributesManager addDirtyRange:actualRange];
  }
}

- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange {
  NSRange actualRange = [self actualUsedRange:range];

  if (![self isParagraph]) {
    [self.host.textView.textStorage removeAttribute:[self getKey]
                                              range:actualRange];
  } else {
    [self.host.textView.textStorage
        enumerateAttribute:NSParagraphStyleAttributeName
                   inRange:actualRange
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
                      indexesOfObjectsPassingTest:^BOOL(NSTextList *textList,
                                                        NSUInteger idx,
                                                        BOOL *stop) {
                        return [self matchesParagraphMarker:textList
                                                                .markerFormat
                                                      value:[self getValue]];
                      }];
                  [textLists removeObjectsAtIndexes:matchingIndexes];
                  pStyle.textLists = textLists;
                  [self.host.textView.textStorage
                      addAttribute:NSParagraphStyleAttributeName
                             value:pStyle
                             range:subRange];
                }];
  }
  [self removeTyping];

  // Notify attributes manager of styling to be re-done if needed.
  if (withDirtyRange) {
    [self.host.attributesManager addDirtyRange:actualRange];
  }
}

- (void)addTypingWithValue:(NSString *)value {
  NSMutableDictionary *newTypingAttrs =
      [self.host.textView.typingAttributes mutableCopy];

  if (![self isParagraph]) {
    newTypingAttrs[[self getKey]] = value;
  } else {
    NSMutableParagraphStyle *pStyle =
        [newTypingAttrs[NSParagraphStyleAttributeName] mutableCopy];
    NSMutableArray<NSTextList *> *textLists = [pStyle.textLists mutableCopy];
    if (textLists == nullptr) {
      textLists = [[NSMutableArray alloc] init];
    }

    NSIndexSet *matchingIndexes = [textLists
        indexesOfObjectsPassingTest:^BOOL(NSTextList *textList, NSUInteger idx,
                                          BOOL *stop) {
          NSString *markerFormat = textList.markerFormat;
          return [self matchesParagraphMarker:markerFormat value:value] &&
                 !EnrichedShouldKeepParagraphMarkerWhenAdding(markerFormat,
                                                              value);
        }];
    [textLists removeObjectsAtIndexes:matchingIndexes];
    [textLists addObject:[[NSTextList alloc] initWithMarkerFormat:value
                                                          options:0]];
    pStyle.textLists = textLists;
    newTypingAttrs[NSParagraphStyleAttributeName] = pStyle;
  }

  self.host.textView.typingAttributes = newTypingAttrs;
}

- (void)removeTyping {
  NSMutableDictionary *newTypingAttrs =
      [self.host.textView.typingAttributes mutableCopy];

  if (![self isParagraph]) {
    [newTypingAttrs removeObjectForKey:[self getKey]];
    // attributes manager also needs to be notified of custom attributes that
    // shouldn't be extended
    [self.host.attributesManager didRemoveTypingAttribute:[self getKey]];
  } else {
    NSMutableParagraphStyle *pStyle =
        [newTypingAttrs[NSParagraphStyleAttributeName] mutableCopy];
    NSMutableArray<NSTextList *> *textLists = [pStyle.textLists mutableCopy];
    if (textLists == nullptr) {
      textLists = [[NSMutableArray alloc] init];
    }

    NSIndexSet *matchingIndexes = [textLists
        indexesOfObjectsPassingTest:^BOOL(NSTextList *textList, NSUInteger idx,
                                          BOOL *stop) {
          return [self matchesParagraphMarker:textList.markerFormat
                                        value:[self getValue]];
        }];
    [textLists removeObjectsAtIndexes:matchingIndexes];
    pStyle.textLists = textLists;
    newTypingAttrs[NSParagraphStyleAttributeName] = pStyle;
  }

  self.host.textView.typingAttributes = newTypingAttrs;
}

// custom styles (e.g. ImageStyle, MentionStyle) will likely need to override
// this method
- (BOOL)styleCondition:(id)value range:(NSRange)range {
  if (![self isParagraph]) {
    NSString *valueString = (NSString *)value;
    return valueString != nullptr &&
           [valueString isEqualToString:[self getValue]];
  } else {
    NSParagraphStyle *pStyle = (NSParagraphStyle *)value;
    if (pStyle == nullptr) {
      return NO;
    }

    for (NSTextList *textList in pStyle.textLists) {
      if ([self matchesParagraphMarker:textList.markerFormat
                                  value:[self getValue]]) {
        return YES;
      }
    }
    return NO;
  }
}

- (BOOL)matchesParagraphMarker:(NSString *)markerFormat
                          value:(NSString *)value {
  return markerFormat != nullptr && [markerFormat isEqualToString:value];
}

- (BOOL)detect:(NSRange)range {
  if (range.length >= 1) {
    return [OccurenceUtils detect:[self getKey]
                         withHost:self.host
                          inRange:range
                    withCondition:^BOOL(id _Nullable value, NSRange range) {
                      return [self styleCondition:value range:range];
                    }];
  } else {
    return [OccurenceUtils detect:[self getKey]
                         withHost:self.host
                          atIndex:range.location
                    checkPrevious:[self isParagraph]
                    withCondition:^BOOL(id _Nullable value, NSRange range) {
                      return [self styleCondition:value range:range];
                    }];
  }
}

- (BOOL)any:(NSRange)range {
  return [OccurenceUtils any:[self getKey]
                    withHost:self.host
                     inRange:range
               withCondition:^BOOL(id _Nullable value, NSRange range) {
                 return [self styleCondition:value range:range];
               }];
}

- (NSArray<StylePair *> *)all:(NSRange)range {
  return [OccurenceUtils all:[self getKey]
                    withHost:self.host
                     inRange:range
               withCondition:^BOOL(id _Nullable value, NSRange range) {
                 return [self styleCondition:value range:range];
               }];
}

// This method gets overridden
- (void)applyStyling:(NSRange)range {
}

// This method gets overridden when the style needs to apply certain typing
// attributes
- (void)applyStylingToTypingAttrs:(NSMutableDictionary *)attributes {
}

// Called during dirty range re-application to restore a style from a saved
// StylePair
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  [self add:range withTyping:NO withDirtyRange:NO];
}

// Gets a custom attribtue entry for the typingAttributes.
// Only used with inline styles.
- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  if (![self detect:range]) {
    return nullptr;
  }

  AttributeEntry *entry = [[AttributeEntry alloc] init];
  entry.key = [self getKey];
  entry.value = [self getValue];
  return entry;
}

@end
