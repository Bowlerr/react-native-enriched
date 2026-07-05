#import "HtmlParser.h"
#import "AlignmentEntry.h"
#import "AlignmentUtils.h"
#import "ImageData.h"
#import "LinkData.h"
#import "MentionParams.h"
#import "StringExtension.h"
#import "StyleHeaders.h"
#import "StylePair.h"

#include "GumboParser.hpp"

@implementation HtmlParser

static BOOL
EnrichedHtmlTagRangeShouldTrimBoundaryWhitespace(NSString *tagName) {
  return [tagName isEqualToString:@"b"] || [tagName isEqualToString:@"i"] ||
         [tagName isEqualToString:@"u"] || [tagName isEqualToString:@"s"] ||
         [tagName isEqualToString:@"code"] || [tagName isEqualToString:@"a"] ||
         [tagName isEqualToString:@"mention"] ||
         [tagName isEqualToString:@"h1"] || [tagName isEqualToString:@"h2"] ||
         [tagName isEqualToString:@"h3"] || [tagName isEqualToString:@"h4"] ||
         [tagName isEqualToString:@"h5"] || [tagName isEqualToString:@"h6"];
}

static BOOL EnrichedHtmlIsBoundaryWhitespace(unichar character) {
  return [[NSCharacterSet whitespaceAndNewlineCharacterSet]
             characterIsMember:character] ||
         character == 0x200B;
}

static NSRange EnrichedHtmlRangeByTrimmingBoundaryWhitespace(NSString *text,
                                                             NSRange range) {
  if (range.location >= text.length || NSMaxRange(range) > text.length ||
      range.length == 0) {
    return range;
  }

  NSUInteger start = range.location;
  NSUInteger end = NSMaxRange(range);

  while (start < end &&
         EnrichedHtmlIsBoundaryWhitespace([text characterAtIndex:start])) {
    start++;
  }

  while (end > start &&
         EnrichedHtmlIsBoundaryWhitespace([text characterAtIndex:end - 1])) {
    end--;
  }

  if (start >= end) {
    return range;
  }

  return NSMakeRange(start, end - start);
}

+ (BOOL)isBlockTag:(NSString *)tagName {
  return [tagName isEqualToString:@"ul"] || [tagName isEqualToString:@"ol"] ||
         [tagName isEqualToString:@"blockquote"] ||
         [tagName isEqualToString:@"codeblock"] ||
         [tagName isEqualToString:@"p"] || [tagName isEqualToString:@"li"] ||
         [tagName isEqualToString:@"h1"] || [tagName isEqualToString:@"h2"] ||
         [tagName isEqualToString:@"h3"] || [tagName isEqualToString:@"h4"] ||
         [tagName isEqualToString:@"h5"] || [tagName isEqualToString:@"h6"];
}

+ (BOOL)shouldInsertLineBreakBeforeOpeningBlockTag:(NSString *)tagName
                                         plainText:(NSString *)plainText {
  if (![self isBlockTag:tagName] || plainText.length == 0) {
    return NO;
  }

  unichar lastCharacter = [plainText characterAtIndex:plainText.length - 1];
  return ![[NSCharacterSet newlineCharacterSet]
      characterIsMember:lastCharacter];
}

/**
 * Prepares HTML for the parser by stripping extraneous whitespace and newlines
 * from structural tags, while preserving them within text content.
 *
 * APPROACH:
 * This function treats the HTML as having two distinct states:
 * 1. Structure Mode (Depth == 0): We are inside or between container tags (like
 * blockquote, ul, codeblock). In this mode whitespace and newlines are
 * considered layout artifacts and are REMOVED to prevent the parser from
 * creating unwanted spaces.
 * 2. Content Mode (Depth > 0): We are inside a text-containing tag (like p,
 * b, li). In this mode, all whitespace is PRESERVED exactly as is, ensuring
 * that sentences and inline formatting remain readable.
 *
 * The function iterates character-by-character, using a depth counter to track
 * nesting levels of the specific tags defined in `textTags`.
 *
 * IMPORTANT:
 * The `textTags` set acts as a whitelist for "Content Mode". If you add support
 * for a new HTML tag that contains visible text (e.g., h4, h5, h6),
 * you MUST add it to the `textTags` set below.
 */
+ (NSString *)stripExtraWhiteSpacesAndNewlines:(NSString *)html {
  NSSet *textTags = [NSSet setWithObjects:@"p", @"h1", @"h2", @"h3", @"h4",
                                          @"h5", @"h6", @"li", @"b", @"a", @"s",
                                          @"mention", @"code", @"u", @"i", nil];

  NSMutableString *output = [NSMutableString stringWithCapacity:html.length];
  NSMutableString *currentTagBuffer = [NSMutableString string];
  NSCharacterSet *whitespaceAndNewlineSet =
      [NSCharacterSet whitespaceAndNewlineCharacterSet];

  BOOL isReadingTag = NO;
  NSInteger textDepth = 0;

  for (NSUInteger i = 0; i < html.length; i++) {
    unichar c = [html characterAtIndex:i];

    if (c == '<') {
      isReadingTag = YES;
      [currentTagBuffer setString:@""];
      [output appendString:@"<"];
    } else if (c == '>') {
      isReadingTag = NO;
      [output appendString:@">"];

      NSString *fullTag = [currentTagBuffer lowercaseString];

      NSString *cleanName = [fullTag
          stringByTrimmingCharactersInSet:
              [NSCharacterSet characterSetWithCharactersInString:@"/"]];
      NSArray *parts =
          [cleanName componentsSeparatedByCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      NSString *tagName = parts.firstObject;

      if (![textTags containsObject:tagName]) {
        continue;
      }

      if ([fullTag hasPrefix:@"/"]) {
        textDepth--;
        if (textDepth < 0)
          textDepth = 0;
      } else {
        // Opening tag (e.g. <h1>) -> Enter Text Mode
        // (Ignore self-closing tags like <img/> if they happen to be in the
        // list)
        if (![fullTag hasSuffix:@"/"]) {
          textDepth++;
        }
      }
    } else {
      if (isReadingTag) {
        [currentTagBuffer appendFormat:@"%C", c];
        [output appendFormat:@"%C", c];
        continue;
      }

      if (textDepth > 0) {
        [output appendFormat:@"%C", c];
      } else {
        if (![whitespaceAndNewlineSet characterIsMember:c]) {
          [output appendFormat:@"%C", c];
        }
      }
    }
  }

  return output;
}

+ (NSString *)stringByAddingNewlinesToTag:(NSString *)tag
                                 inString:(NSString *)html
                                  leading:(BOOL)leading
                                 trailing:(BOOL)trailing {
  NSString *str = [html copy];
  if (leading) {
    NSString *formattedTag = [NSString stringWithFormat:@">%@", tag];
    NSString *formattedNewTag = [NSString stringWithFormat:@">\n%@", tag];
    str = [str stringByReplacingOccurrencesOfString:formattedTag
                                         withString:formattedNewTag];
  }
  if (trailing) {
    NSString *formattedTag = [NSString stringWithFormat:@"%@<", tag];
    NSString *formattedNewTag = [NSString stringWithFormat:@"%@\n<", tag];
    str = [str stringByReplacingOccurrencesOfString:formattedTag
                                         withString:formattedNewTag];
  }
  return str;
}

+ (NSString *)
    stringByAddingNewlinesToOpeningTagsMatchingPattern:(NSString *)pattern
                                              inString:(NSString *)html
                                               leading:(BOOL)leading
                                              trailing:(BOOL)trailing {
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:pattern
                           options:NSRegularExpressionCaseInsensitive
                             error:&error];
  if (regex == nil || error != nil) {
    return html;
  }

  NSMutableString *str = [html mutableCopy];
  NSArray<NSTextCheckingResult *> *matches =
      [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];

  for (NSInteger index = (NSInteger)matches.count - 1; index >= 0; index--) {
    NSRange range = matches[(NSUInteger)index].range;
    if (trailing && NSMaxRange(range) < str.length &&
        [str characterAtIndex:NSMaxRange(range)] != '\n') {
      [str insertString:@"\n" atIndex:NSMaxRange(range)];
    }
    if (leading && range.location > 0 &&
        [str characterAtIndex:range.location - 1] != '\n') {
      [str insertString:@"\n" atIndex:range.location];
    }
  }

  return str;
}

+ (NSString *)stringByRemovingStructuralNewlinesBeforeClosingListItems:
    (NSString *)html {
  NSString *str = [html copy];
  for (NSString *closingTag in
       @[ @"</ul>", @"</ol>", @"</blockquote>", @"</codeblock>" ]) {
    NSString *structuralBreak =
        [NSString stringWithFormat:@"%@\n</li>", closingTag];
    NSString *compact = [NSString stringWithFormat:@"%@</li>", closingTag];
    str = [str stringByReplacingOccurrencesOfString:structuralBreak
                                         withString:compact];
  }
  return str;
}

#pragma mark - External HTML normalization

/**
 * Normalizes external HTML (from Google Docs, Word, web pages, etc.) into our
 * canonical tag subset using the Gumbo-based C++ normalizer.
 *
 * Converts: strong → b, em → i, span style="font-weight:bold" → b,
 * strips unknown tags while preserving text
 */
+ (NSString *_Nullable)normalizeExternalHtml:(NSString *_Nonnull)html {
  std::string result =
      GumboParser::normalizeHtml(std::string([html UTF8String]));
  if (result.empty())
    return nil;
  return [NSString stringWithUTF8String:result.c_str()];
}

+ (void)finalizeTagEntry:(NSMutableString *)tagName
               ongoingTags:(NSMutableDictionary *)ongoingTags
    initiallyProcessedTags:(NSMutableArray *)processedTags
                 plainText:(NSMutableString *)plainText
       precedingImageCount:(NSInteger *)precedingImageCount {
  NSMutableArray *tagEntry = [[NSMutableArray alloc] init];

  NSMutableArray *tagStack = ongoingTags[tagName];
  NSArray *tagData = tagStack.lastObject;
  if (tagData == nil) {
    return;
  }

  NSInteger tagLocation = [((NSNumber *)tagData[0]) intValue];
  // Keep parser ranges in plain-text coordinates. Image attachments are
  // inserted later by the platform-specific HTML appliers and those appliers
  // adjust style ranges as attachments mutate the text storage. Shifting here
  // corrupts parser-only work such as splitting list-item ranges into
  // paragraphs.
  NSRange tagRange = NSMakeRange(tagLocation, plainText.length - tagLocation);
  if (EnrichedHtmlTagRangeShouldTrimBoundaryWhitespace(tagName)) {
    tagRange =
        EnrichedHtmlRangeByTrimmingBoundaryWhitespace(plainText, tagRange);
  }

  [tagEntry addObject:[tagName copy]];
  [tagEntry addObject:[NSValue valueWithRange:tagRange]];
  if (tagData.count > 2) {
    [tagEntry addObject:[(NSString *)tagData[2] copy]];
  }

  [processedTags addObject:tagEntry];
  [tagStack removeLastObject];
  if (tagStack.count == 0) {
    [ongoingTags removeObjectForKey:tagName];
  }

  if ([tagName isEqualToString:@"img"]) {
    (*precedingImageCount)++;
  }
}

+ (BOOL)isUlCheckboxList:(NSString *)params {
  NSString *lowercaseParams = [params lowercaseString];
  NSString *compactParams =
      [[lowercaseParams componentsSeparatedByCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]]
          componentsJoinedByString:@""];
  return ([compactParams containsString:@"data-type=\"checkbox\""] ||
          [compactParams containsString:@"data-type='checkbox'"] ||
          [compactParams containsString:@"data-type=checkbox"] ||
          [compactParams containsString:@"data-type=\"checkboxlist\""] ||
          [compactParams containsString:@"data-type='checkboxlist'"] ||
          [compactParams containsString:@"data-type=checkboxlist"]);
}

+ (BOOL)isCheckedCheckboxListItem:(NSString *)params {
  NSString *lowercaseParams = [params lowercaseString];
  NSString *compactParams =
      [[lowercaseParams componentsSeparatedByCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]]
          componentsJoinedByString:@""];
  if ([compactParams containsString:@"data-checked=\"false\""] ||
      [compactParams containsString:@"data-checked='false'"] ||
      [compactParams containsString:@"data-checked=false"] ||
      [compactParams containsString:@"checked=\"false\""] ||
      [compactParams containsString:@"checked='false'"] ||
      [compactParams containsString:@"checked=false"]) {
    return NO;
  }

  if ([compactParams containsString:@"data-checked=\"true\""] ||
      [compactParams containsString:@"data-checked='true'"] ||
      [compactParams containsString:@"data-checked=true"] ||
      [compactParams containsString:@"checked=\"true\""] ||
      [compactParams containsString:@"checked='true'"] ||
      [compactParams containsString:@"checked=true"]) {
    return YES;
  }

  return [compactParams containsString:@"checked"];
}

+ (NSInteger)currentListLevelFromOngoingTags:(NSDictionary *)ongoingTags {
  NSInteger level = 0;
  for (NSString *tagName in @[ @"ul", @"ol" ]) {
    NSArray *tagStack = ongoingTags[tagName];
    level += tagStack.count;
  }
  return level;
}

+ (NSString *)paramsByAppendingListLevel:(NSString *)params
                                   level:(NSInteger)level
                               contextId:(NSInteger)contextId {
  NSString *levelParam =
      [NSString stringWithFormat:@"data-enriched-list-level=\"%ld\" "
                                 @"data-enriched-list-context=\"%ld\"",
                                 (long)level, (long)contextId];
  if (params.length == 0) {
    return levelParam;
  }
  return [NSString stringWithFormat:@"%@ %@", params, levelParam];
}

+ (NSString *)paramsByAppendingBlockQuoteContext:(NSString *)params
                                           level:(NSInteger)level
                                       contextId:(NSInteger)contextId {
  NSString *contextParams =
      [NSString stringWithFormat:@"data-enriched-blockquote-level=\"%ld\" "
                                 @"data-enriched-blockquote-context=\"%ld\"",
                                 (long)level, (long)contextId];
  if (params.length == 0) {
    return contextParams;
  }
  return [NSString stringWithFormat:@"%@ %@", params, contextParams];
}

+ (NSString *)paramsByAppendingListItemContext:(NSString *)params
                                       listTag:(NSString *)listTag
                                         level:(NSInteger)level
                                     contextId:(NSInteger)contextId {
  NSString *contextParams =
      [NSString stringWithFormat:@"data-enriched-list-item=\"%@\" "
                                 @"data-enriched-list-level=\"%ld\" "
                                 @"data-enriched-list-context=\"%ld\"",
                                 listTag, (long)level, (long)contextId];
  if (params.length == 0) {
    return contextParams;
  }
  return [NSString stringWithFormat:@"%@ %@", params, contextParams];
}

+ (NSString *)paramsByAppendingCurrentBlockQuoteContext:(NSString *)params
                                            ongoingTags:
                                                (NSDictionary *)ongoingTags {
  NSArray *blockQuoteStack = ongoingTags[@"blockquote"];
  NSArray *currentBlockQuote = blockQuoteStack.lastObject;
  if (currentBlockQuote.count <= 2) {
    return params;
  }

  NSString *blockQuoteParams = (NSString *)currentBlockQuote[2];
  NSInteger quoteContextId =
      [self blockQuoteContextFromParams:blockQuoteParams];
  if (quoteContextId < 0) {
    return params;
  }

  NSInteger quoteLevel = [self blockQuoteLevelFromParams:blockQuoteParams];
  return [self paramsByAppendingBlockQuoteContext:params
                                            level:quoteLevel
                                        contextId:quoteContextId];
}

+ (NSInteger)listLevelFromParams:(NSString *)params {
  NSRegularExpression *levelRegex = [NSRegularExpression
      regularExpressionWithPattern:
          @"data-enriched-list-level=['\\\"]([0-9]+)['\\\"]"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [levelRegex firstMatchInString:params
                             options:0
                               range:NSMakeRange(0, params.length)];
  if (match == nullptr || match.numberOfRanges < 2) {
    return 0;
  }
  NSString *levelString = [params substringWithRange:[match rangeAtIndex:1]];
  return MAX(0, [levelString integerValue]);
}

+ (NSInteger)listContextFromParams:(NSString *)params {
  NSRegularExpression *contextRegex = [NSRegularExpression
      regularExpressionWithPattern:
          @"data-enriched-list-context=['\\\"]([0-9]+)['\\\"]"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [contextRegex firstMatchInString:params
                               options:0
                                 range:NSMakeRange(0, params.length)];
  if (match == nullptr || match.numberOfRanges < 2) {
    return -1;
  }
  NSString *contextString = [params substringWithRange:[match rangeAtIndex:1]];
  return MAX(0, [contextString integerValue]);
}

+ (NSInteger)blockQuoteLevelFromParams:(NSString *)params {
  NSRegularExpression *levelRegex = [NSRegularExpression
      regularExpressionWithPattern:
          @"data-enriched-blockquote-level=['\\\"]([0-9]+)['\\\"]"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [levelRegex firstMatchInString:params
                             options:0
                               range:NSMakeRange(0, params.length)];
  if (match == nullptr || match.numberOfRanges < 2) {
    return 0;
  }
  NSString *levelString = [params substringWithRange:[match rangeAtIndex:1]];
  return MAX(0, [levelString integerValue]);
}

+ (NSInteger)blockQuoteContextFromParams:(NSString *)params {
  NSRegularExpression *contextRegex = [NSRegularExpression
      regularExpressionWithPattern:
          @"data-enriched-blockquote-context=['\\\"]([0-9]+)['\\\"]"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [contextRegex firstMatchInString:params
                               options:0
                                 range:NSMakeRange(0, params.length)];
  if (match == nullptr || match.numberOfRanges < 2) {
    return -1;
  }
  NSString *contextString = [params substringWithRange:[match rangeAtIndex:1]];
  return MAX(0, [contextString integerValue]);
}

+ (NSString *)blockQuoteMarkerValueWithLevel:(NSInteger)level
                                   contextId:(NSInteger)contextId {
  if (contextId < 0) {
    if (level <= 0) {
      return @"EnrichedBlockQuote";
    }
    return [NSString stringWithFormat:@"EnrichedBlockQuote:%ld", (long)level];
  }
  return [NSString stringWithFormat:@"EnrichedBlockQuote:%ld:%ld", (long)level,
                                    (long)contextId];
}

+ (BOOL)blockQuoteMarkerMatches:(NSString *)markerFormat {
  if (markerFormat == nil) {
    return NO;
  }

  NSString *baseValue = @"EnrichedBlockQuote";
  NSString *continuationBaseValue =
      [baseValue stringByAppendingString:@"Continuation"];
  return [markerFormat isEqualToString:baseValue] ||
         [markerFormat hasPrefix:[baseValue stringByAppendingString:@":"]] ||
         [markerFormat isEqualToString:continuationBaseValue] ||
         [markerFormat
             hasPrefix:[continuationBaseValue stringByAppendingString:@":"]];
}

+ (NSInteger)blockQuoteLevelFromMarker:(NSString *)markerFormat {
  if (![self blockQuoteMarkerMatches:markerFormat]) {
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

+ (NSString *)blockQuoteMarkerAtLocation:(NSInteger)location
                                    host:(id<EnrichedViewHost>)host {
  if (host.textView.textStorage.length == 0) {
    return nil;
  }

  NSUInteger styleLocation =
      MIN(MAX(location, 0), (NSInteger)host.textView.textStorage.length - 1);
  NSParagraphStyle *pStyle =
      [host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                   atIndex:styleLocation
                            effectiveRange:nil];
  NSString *marker = nil;
  NSInteger markerLevel = -1;
  for (NSTextList *textList in pStyle.textLists) {
    NSInteger currentLevel =
        [self blockQuoteLevelFromMarker:textList.markerFormat];
    if (currentLevel >= 0 && currentLevel >= markerLevel) {
      marker = textList.markerFormat;
      markerLevel = currentLevel;
    }
  }
  return marker;
}

+ (NSInteger)blockQuoteDepthFromMarker:(NSString *)markerFormat {
  NSInteger level = [self blockQuoteLevelFromMarker:markerFormat];
  if (level >= 0) {
    return level + 1;
  }
  return 0;
}

+ (void)appendOpeningBlockQuotes:(NSInteger)count
                        toResult:(NSMutableString *)result {
  for (NSInteger index = 0; index < count; index++) {
    [result appendString:@"\n<blockquote>"];
  }
}

+ (void)appendClosingBlockQuotes:(NSInteger)count
                        toResult:(NSMutableString *)result {
  for (NSInteger index = 0; index < count; index++) {
    [result appendString:@"\n</blockquote>"];
  }
}

+ (NSString *)listItemTagFromParams:(NSString *)params {
  NSRegularExpression *itemRegex = [NSRegularExpression
      regularExpressionWithPattern:
          @"data-enriched-list-item=['\\\"]([^'\\\"]+)['\\\"]"
                           options:0
                             error:nil];
  NSTextCheckingResult *match =
      [itemRegex firstMatchInString:params
                            options:0
                              range:NSMakeRange(0, params.length)];
  if (match == nullptr || match.numberOfRanges < 2) {
    return nil;
  }
  return [params substringWithRange:[match rangeAtIndex:1]];
}

+ (NSString *)listMarkerValueWithBase:(NSString *)baseValue
                                level:(NSInteger)level {
  if (level <= 0) {
    return baseValue;
  }
  return [NSString stringWithFormat:@"%@:%ld", baseValue, (long)level];
}

+ (NSString *)listMarkerValueWithBase:(NSString *)baseValue
                                level:(NSInteger)level
                            contextId:(NSInteger)contextId {
  if (contextId < 0) {
    return [self listMarkerValueWithBase:baseValue level:level];
  }
  return [NSString
      stringWithFormat:@"%@:%ld:%ld", baseValue, (long)level, (long)contextId];
}

+ (BOOL)paragraphRangeHasVisibleContent:(NSString *)text range:(NSRange)range {
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

+ (NSArray<NSValue *> *)paragraphRangesInListItemRange:(NSRange)itemRange
                                             plainText:(NSString *)plainText {
  NSMutableArray<NSValue *> *paragraphRanges = [[NSMutableArray alloc] init];
  NSUInteger itemEnd = MIN(NSMaxRange(itemRange), plainText.length);
  NSUInteger cursor = itemRange.location;

  while (cursor < itemEnd) {
    NSRange paragraphRange =
        [plainText paragraphRangeForRange:NSMakeRange(cursor, 0)];
    NSRange clippedRange = NSIntersectionRange(paragraphRange, itemRange);
    if (clippedRange.length > 0 &&
        [self paragraphRangeHasVisibleContent:plainText range:clippedRange]) {
      [paragraphRanges addObject:[NSValue valueWithRange:clippedRange]];
    }

    NSUInteger nextCursor = NSMaxRange(paragraphRange);
    if (nextCursor <= cursor) {
      break;
    }
    cursor = nextCursor;
  }

  return paragraphRanges;
}

+ (BOOL)isInsideCheckboxList:(NSDictionary *)ongoingTags {
  NSArray *ulStack = ongoingTags[@"ul"];
  for (NSArray *tagData in [ulStack reverseObjectEnumerator]) {
    if (tagData.count > 2 && [self isUlCheckboxList:(NSString *)tagData[2]]) {
      return YES;
    }
  }
  return NO;
}

+ (BOOL)isCurrentListCheckboxList:(NSDictionary *)ongoingTags
                  ongoingListTags:(NSArray<NSString *> *)ongoingListTags {
  if (ongoingListTags.count == 0 ||
      ![ongoingListTags.lastObject isEqualToString:@"ul"]) {
    return NO;
  }

  NSArray *ulStack = ongoingTags[@"ul"];
  NSArray *currentUl = ulStack.lastObject;
  if (currentUl.count <= 2) {
    return NO;
  }

  return [self isUlCheckboxList:(NSString *)currentUl[2]];
}

+ (NSDictionary *)prepareCheckboxListStyleValue:(NSValue *)rangeValue
                                 checkboxStates:(NSDictionary *)checkboxStates {
  NSRange range = [rangeValue rangeValue];
  NSMutableDictionary *statesInRange = [[NSMutableDictionary alloc] init];

  for (NSNumber *key in checkboxStates) {
    NSUInteger pos = [key unsignedIntegerValue];
    if (pos >= range.location && pos < range.location + range.length) {
      [statesInRange setObject:checkboxStates[key] forKey:key];
    }
  }

  return statesInRange;
}

+ (BOOL)checkboxStateInListItemRange:(NSRange)itemRange
                      checkboxStates:(NSDictionary *)checkboxStates {
  NSNumber *exactState = checkboxStates[@(itemRange.location)];
  if (exactState != nil) {
    return [exactState boolValue];
  }

  NSUInteger itemEnd = NSMaxRange(itemRange);
  for (NSNumber *key in checkboxStates) {
    NSUInteger position = [key unsignedIntegerValue];
    if (position >= itemRange.location && position < itemEnd) {
      return [checkboxStates[key] boolValue];
    }
  }

  return NO;
}

+ (NSNumber *)checkboxStatePositionInListItemRange:(NSRange)itemRange
                                    checkboxStates:
                                        (NSDictionary *)checkboxStates {
  NSNumber *exactPosition = checkboxStates[@(itemRange.location)] != nil
                                ? @(itemRange.location)
                                : nil;
  if (exactPosition != nil) {
    return exactPosition;
  }

  NSUInteger itemEnd = NSMaxRange(itemRange);
  NSNumber *firstPosition = nil;
  for (NSNumber *key in checkboxStates) {
    NSUInteger position = [key unsignedIntegerValue];
    if (position < itemRange.location || position >= itemEnd) {
      continue;
    }

    if (firstPosition == nil ||
        position < [firstPosition unsignedIntegerValue]) {
      firstPosition = key;
    }
  }

  return firstPosition;
}

+ (void)sortProcessedStylesByRangeContainment:
    (NSMutableArray *)processedStyles {
  NSMapTable *originalPositions = [NSMapTable
      mapTableWithKeyOptions:NSPointerFunctionsObjectPointerPersonality
                valueOptions:NSPointerFunctionsStrongMemory];

  for (NSUInteger index = 0; index < processedStyles.count; index++) {
    [originalPositions setObject:@(index) forKey:processedStyles[index]];
  }

  [processedStyles
      sortUsingComparator:^NSComparisonResult(NSArray *left, NSArray *right) {
        if (left.count < 2 || right.count < 2) {
          return NSOrderedSame;
        }

        StylePair *leftPair = (StylePair *)left[1];
        StylePair *rightPair = (StylePair *)right[1];
        if (![leftPair isKindOfClass:[StylePair class]] ||
            ![rightPair isKindOfClass:[StylePair class]]) {
          return NSOrderedSame;
        }

        NSRange leftRange = [leftPair.rangeValue rangeValue];
        NSRange rightRange = [rightPair.rangeValue rangeValue];

        if (leftRange.location < rightRange.location) {
          return NSOrderedAscending;
        }
        if (leftRange.location > rightRange.location) {
          return NSOrderedDescending;
        }

        if (leftRange.length > rightRange.length) {
          return NSOrderedAscending;
        }
        if (leftRange.length < rightRange.length) {
          return NSOrderedDescending;
        }

        // Equal ranges happen when a list item paragraph only contains a nested
        // block, for example <li><blockquote>...</blockquote></li>. The outer
        // tag closes later, so apply later-produced styles first to preserve
        // nesting.
        NSUInteger leftPosition =
            [[originalPositions objectForKey:left] unsignedIntegerValue];
        NSUInteger rightPosition =
            [[originalPositions objectForKey:right] unsignedIntegerValue];
        if (leftPosition > rightPosition) {
          return NSOrderedAscending;
        }
        if (leftPosition < rightPosition) {
          return NSOrderedDescending;
        }

        return NSOrderedSame;
      }];
}

+ (NSString *_Nullable)initiallyProcessHtml:(NSString *_Nonnull)html
                          useHtmlNormalizer:(BOOL)useHtmlNormalizer {
  NSString *htmlWithoutSpaces = [self stripExtraWhiteSpacesAndNewlines:html];
  NSString *fixedHtml = nullptr;

  if (htmlWithoutSpaces.length >= 13) {
    NSString *firstSix =
        [htmlWithoutSpaces substringWithRange:NSMakeRange(0, 6)];
    NSString *lastSeven = [htmlWithoutSpaces
        substringWithRange:NSMakeRange(htmlWithoutSpaces.length - 7, 7)];

    if ([firstSix isEqualToString:@"<html>"] &&
        [lastSeven isEqualToString:@"</html>"]) {
      // remove html tags, might be with newlines or without them
      fixedHtml = [htmlWithoutSpaces copy];
      // firstly remove newlined html tags if any:
      fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<html>\n"
                                                       withString:@""];
      fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"\n</html>"
                                                       withString:@""];
      // fallback; remove html tags without their newlines
      fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<html>"
                                                       withString:@""];
      fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"</html>"
                                                       withString:@""];
    } else if (useHtmlNormalizer) {
      // External HTML (from Google Docs, Word, web pages, etc.)
      // Run through the Gumbo-based normalizer to convert arbitrary HTML
      // into our canonical tag subset.
      NSString *normalized = [self normalizeExternalHtml:html];
      if (normalized != nil) {
        fixedHtml = normalized;
      }
    }

    // Additionally, try getting the content from between body tags if there are
    // some:

    // Firstly make sure there are no newlines between them.
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<body>\n"
                                                     withString:@"<body>"];
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"\n</body>"
                                                     withString:@"</body>"];
    // Then, if there actually are body tags, use the content between them.
    NSRange openingBodyRange = [htmlWithoutSpaces rangeOfString:@"<body>"];
    NSRange closingBodyRange = [htmlWithoutSpaces rangeOfString:@"</body>"];
    if (openingBodyRange.length != 0 && closingBodyRange.length != 0) {
      NSInteger newStart = openingBodyRange.location + 6;
      NSInteger newEnd = closingBodyRange.location - 1;
      fixedHtml = [htmlWithoutSpaces
          substringWithRange:NSMakeRange(newStart, newEnd - newStart + 1)];
    }
  }

  // second processing - try fixing htmls with wrong newlines' setup
  if (fixedHtml != nullptr) {
    // add <br> tag wherever needed
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<p></p>"
                                                     withString:@"<br>"];

    // remove <p> tags inside of <li>
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<li><p>"
                                                     withString:@"<li>"];
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"</p></li>"
                                                     withString:@"</li>"];

    // change <br/> to <br>
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<br/>"
                                                     withString:@"<br>"];

    // remove <p> tags around <br>
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<p><br>"
                                                     withString:@"<br>"];
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<br></p>"
                                                     withString:@"<br>"];

    // add <br> tags inside empty blockquote and codeblock tags
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<blockquote></blockquote>"
                                  withString:@"<blockquote><br></"
                                             @"blockquote>"];
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<codeblock></codeblock>"
                                  withString:@"<codeblock><br></codeblock>"];

    // remove empty ul and ol tags
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<ul></ul>"
                                                     withString:@""];
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<ul data-type=\"checkbox\"></ul>"
                                  withString:@""];
    fixedHtml = [fixedHtml stringByReplacingOccurrencesOfString:@"<ol></ol>"
                                                     withString:@""];

    // tags that have to be in separate lines
    fixedHtml = [self stringByAddingNewlinesToTag:@"<ul>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self
        stringByAddingNewlinesToOpeningTagsMatchingPattern:@"<ul\\s+[^>]*>"
                                                  inString:fixedHtml
                                                   leading:YES
                                                  trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</ul>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<ol>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self
        stringByAddingNewlinesToOpeningTagsMatchingPattern:@"<ol\\s+[^>]*>"
                                                  inString:fixedHtml
                                                   leading:YES
                                                  trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</ol>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<blockquote>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</blockquote>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<codeblock>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</codeblock>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:YES];

    // line opening tags
    fixedHtml = [self stringByAddingNewlinesToTag:@"<p>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml =
        [self stringByAddingNewlinesToOpeningTagsMatchingPattern:@"<p\\s+[^>]*>"
                                                        inString:fixedHtml
                                                         leading:YES
                                                        trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<li>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<li checked>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self
        stringByAddingNewlinesToOpeningTagsMatchingPattern:@"<li\\s+[^>]*>"
                                                  inString:fixedHtml
                                                   leading:YES
                                                  trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h1>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h2>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h3>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h4>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h5>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];
    fixedHtml = [self stringByAddingNewlinesToTag:@"<h6>"
                                         inString:fixedHtml
                                          leading:YES
                                         trailing:NO];

    // line closing tags
    fixedHtml = [self stringByAddingNewlinesToTag:@"</p>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</li>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h1>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h2>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h3>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h4>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h5>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];
    fixedHtml = [self stringByAddingNewlinesToTag:@"</h6>"
                                         inString:fixedHtml
                                          leading:NO
                                         trailing:YES];

    fixedHtml = [self
        stringByRemovingStructuralNewlinesBeforeClosingListItems:fixedHtml];

    // this is more like a hack but for some reason the last <br> in
    // <blockquote> and <codeblock> are not properly changed into zero width
    // space so we do that manually here
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<br>\n</blockquote>"
                                  withString:@"<p>\u200B</p>\n</blockquote>"];
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<br>\n</codeblock>"
                                  withString:@"<p>\u200B</p>\n</codeblock>"];

    // The same like above for (blockquote and codeblock) this is more like a
    // hack but for some reason the last <li></li> in <ul> and <ol> are not
    // properly changed into zero width space so we do that manually here
    // TODO: investigate this further, issue is already described here:
    // https://github.com/software-mansion/react-native-enriched/issues/505
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<li></li>\n</ul>"
                                  withString:@"<li>\u200B</li>\n</ul>"];
    fixedHtml = [fixedHtml
        stringByReplacingOccurrencesOfString:@"<li></li>\n</ol>"
                                  withString:@"<li>\u200B</li>\n</ol>"];
  }

  return fixedHtml;
}

+ (NSArray *_Nonnull)getTextAndStylesFromHtml:(NSString *_Nonnull)fixedHtml {
  NSMutableString *plainText = [[NSMutableString alloc] initWithString:@""];
  NSMutableDictionary *ongoingTags = [[NSMutableDictionary alloc] init];
  NSMutableArray<NSString *> *ongoingListTags = [[NSMutableArray alloc] init];
  NSMutableArray<NSNumber *> *ongoingListContextIds =
      [[NSMutableArray alloc] init];
  NSMutableArray *initiallyProcessedTags = [[NSMutableArray alloc] init];
  NSMutableDictionary *checkboxStates = [[NSMutableDictionary alloc] init];
  NSMutableArray<AlignmentEntry *> *foundAlignments =
      [[NSMutableArray alloc] init];
  NSInteger precedingImageCount = 0;
  NSInteger listContextId = 0;
  NSInteger blockquoteContextId = 0;
  BOOL lastVisibleTokenWasImage = NO;
  BOOL lastVisibleTokenWasStandaloneImage = NO;
  BOOL insideTag = NO;
  BOOL gettingTagName = NO;
  BOOL gettingTagParams = NO;
  BOOL closingTag = NO;
  NSInteger currentTagStartIndex = -1;
  NSInteger paragraphDepth = 0;
  NSMutableString *currentTagName =
      [[NSMutableString alloc] initWithString:@""];
  NSMutableString *currentTagParams =
      [[NSMutableString alloc] initWithString:@""];
  NSDictionary *htmlEntitiesDict =
      [NSString getEscapedCharactersInfoFrom:fixedHtml];

  // firstly, extract text and initially processed tags
  for (int i = 0; i < fixedHtml.length; i++) {
    NSString *currentCharacterStr =
        [fixedHtml substringWithRange:NSMakeRange(i, 1)];
    unichar currentCharacterChar = [fixedHtml characterAtIndex:i];

    if (currentCharacterChar == '<') {
      // opening the tag, mark that we are inside and getting its name
      insideTag = YES;
      gettingTagName = YES;
      currentTagStartIndex = i;
    } else if (currentCharacterChar == '>') {
      // finishing some tag, no longer marked as inside or getting its
      // name/params
      insideTag = NO;
      gettingTagName = NO;
      gettingTagParams = NO;

      BOOL isSelfClosing = NO;

      // Check if params ended with '/' (e.g. <img src="" />)
      if ([currentTagParams hasSuffix:@"/"]) {
        [currentTagParams
            deleteCharactersInRange:NSMakeRange(currentTagParams.length - 1,
                                                1)];
        isSelfClosing = YES;
      }
      if ([currentTagName isEqualToString:@"img"]) {
        isSelfClosing = YES;
      }

      if ([currentTagName isEqualToString:@"br"]) {
        [plainText appendString:@"\n"];
      } else if (!closingTag) {
        BOOL isPlainParagraph = [currentTagName isEqualToString:@"p"] &&
                                currentTagParams.length == 0;
        if ([currentTagName isEqualToString:@"p"]) {
          paragraphDepth++;
        }

        if (!isPlainParagraph) {
          if ([self isBlockTag:currentTagName] && lastVisibleTokenWasImage) {
            if ([self shouldInsertLineBreakBeforeOpeningBlockTag:@"p"
                                                       plainText:plainText]) {
              [plainText appendString:@"\n"];
            }
            lastVisibleTokenWasImage = NO;
            lastVisibleTokenWasStandaloneImage = NO;
          }

          if ([self shouldInsertLineBreakBeforeOpeningBlockTag:currentTagName
                                                     plainText:plainText]) {
            [plainText appendString:@"\n"];
          }

          BOOL isStandaloneImage =
              [currentTagName isEqualToString:@"img"] && paragraphDepth == 0 &&
              currentTagStartIndex > 0 &&
              [[NSCharacterSet newlineCharacterSet]
                  characterIsMember:[fixedHtml
                                        characterAtIndex:currentTagStartIndex -
                                                         1]];
          if (isStandaloneImage &&
              [self shouldInsertLineBreakBeforeOpeningBlockTag:@"p"
                                                     plainText:plainText]) {
            [plainText appendString:@"\n"];
          }

          // Track checkbox state at the same text location used for the list
          // item tag range. Some list items insert a synthetic leading newline;
          // recording before that newline leaves the checkbox state just
          // outside the final paragraph range.
          if ([currentTagName isEqualToString:@"li"] &&
              [self isCurrentListCheckboxList:ongoingTags
                              ongoingListTags:ongoingListTags]) {
            BOOL isChecked = [self isCheckedCheckboxListItem:currentTagParams];
            checkboxStates[@(plainText.length)] = @(isChecked);
          }

          // we finish opening tag - get its location, the current
          // precedingImageCount and optionally params and put them under tag
          // name key in ongoingTags. Images occupy an object-replacement
          // character in plainText, so later style ranges stay in parser
          // coordinates without attachment insertion shifts.
          NSMutableArray *tagArr = [[NSMutableArray alloc] init];
          [tagArr addObject:[NSNumber numberWithInteger:plainText.length]];
          [tagArr addObject:[NSNumber numberWithInteger:precedingImageCount]];

          NSString *tagParams = [currentTagParams copy];
          if ([currentTagName isEqualToString:@"ul"] ||
              [currentTagName isEqualToString:@"ol"]) {
            NSInteger listLevel = ongoingListTags.count;
            NSInteger currentListContextId = listContextId++;
            tagParams = [self paramsByAppendingListLevel:tagParams
                                                   level:listLevel
                                               contextId:currentListContextId];
            [ongoingListContextIds
                addObject:[NSNumber numberWithInteger:currentListContextId]];
          } else if ([currentTagName isEqualToString:@"blockquote"]) {
            NSInteger quoteLevel = [ongoingTags[@"blockquote"] count];
            NSInteger currentQuoteContextId = blockquoteContextId++;
            tagParams =
                [self paramsByAppendingBlockQuoteContext:tagParams
                                                   level:quoteLevel
                                               contextId:currentQuoteContextId];
          } else if ([currentTagName isEqualToString:@"codeblock"]) {
            tagParams =
                [self paramsByAppendingCurrentBlockQuoteContext:tagParams
                                                    ongoingTags:ongoingTags];
          } else if ([currentTagName isEqualToString:@"img"] &&
                     isStandaloneImage) {
            if (tagParams.length == 0) {
              tagParams = @"data-enriched-image-standalone=\"true\"";
            } else {
              tagParams = [NSString
                  stringWithFormat:@"%@ %@", tagParams,
                                   @"data-enriched-image-standalone=\"true\""];
            }
          } else if ([currentTagName isEqualToString:@"li"] &&
                     ongoingListTags.count > 0) {
            BOOL isCheckboxListItem =
                [self isCurrentListCheckboxList:ongoingTags
                                ongoingListTags:ongoingListTags];
            NSString *parentListTag =
                isCheckboxListItem ? @"checkbox" : ongoingListTags.lastObject;
            NSInteger listLevel = MAX(0, (NSInteger)ongoingListTags.count - 1);
            NSInteger currentListContextId =
                ongoingListContextIds.count > 0
                    ? [ongoingListContextIds.lastObject integerValue]
                    : -1;
            tagParams =
                [self paramsByAppendingListItemContext:tagParams
                                               listTag:parentListTag
                                                 level:listLevel
                                             contextId:currentListContextId];
            tagParams =
                [self paramsByAppendingCurrentBlockQuoteContext:tagParams
                                                    ongoingTags:ongoingTags];
          }

          if (tagParams.length > 0) {
            [tagArr addObject:tagParams];
          }

          NSMutableArray *tagStack = ongoingTags[currentTagName];
          if (tagStack == nil) {
            tagStack = [[NSMutableArray alloc] init];
            ongoingTags[currentTagName] = tagStack;
          }
          [tagStack addObject:tagArr];

          if ([currentTagName isEqualToString:@"ul"] ||
              [currentTagName isEqualToString:@"ol"]) {
            [ongoingListTags addObject:[currentTagName copy]];
          }

          // skip one newline if it was added after opening tags that are in
          // separate lines
          if ([self isBlockTag:currentTagName] && i + 1 < fixedHtml.length &&
              [[NSCharacterSet newlineCharacterSet]
                  characterIsMember:[fixedHtml characterAtIndex:i + 1]]) {
            i += 1;
          }

          if (isSelfClosing) {
            if ([currentTagName isEqualToString:@"img"]) {
              [plainText appendString:@"\uFFFC"];
            }
            [self finalizeTagEntry:currentTagName
                           ongoingTags:ongoingTags
                initiallyProcessedTags:initiallyProcessedTags
                             plainText:plainText
                   precedingImageCount:&precedingImageCount];
            if ([currentTagName isEqualToString:@"img"]) {
              if (isStandaloneImage) {
                [plainText appendString:@"\n"];
                if (i + 1 < fixedHtml.length &&
                    [[NSCharacterSet newlineCharacterSet]
                        characterIsMember:[fixedHtml characterAtIndex:i + 1]]) {
                  i += 1;
                }
              }
              lastVisibleTokenWasImage = YES;
              lastVisibleTokenWasStandaloneImage = isStandaloneImage;
            }
          }
        }
      } else {
        // we finish closing tags - pack tag name, tag range and optionally tag
        // params into an entry that goes inside initiallyProcessedTags

        BOOL isBlockTag = [self isBlockTag:currentTagName];

        // skip one newline if it was added before some closing tags that are
        // in separate lines
        if (isBlockTag && plainText.length > 0 &&
            [[NSCharacterSet newlineCharacterSet]
                characterIsMember:[plainText
                                      characterAtIndex:plainText.length - 1]] &&
            !lastVisibleTokenWasStandaloneImage) {
          plainText = [[plainText
              substringWithRange:NSMakeRange(0, plainText.length - 1)]
              mutableCopy];
        }

        NSArray *tagStack = ongoingTags[currentTagName];
        [self checkForAlignments:tagStack.lastObject
                       plainText:plainText
                 foundAlignments:foundAlignments
             precedingImageCount:precedingImageCount];
        [self finalizeTagEntry:currentTagName
                       ongoingTags:ongoingTags
            initiallyProcessedTags:initiallyProcessedTags
                         plainText:plainText
               precedingImageCount:&precedingImageCount];

        if ([currentTagName isEqualToString:@"p"] && paragraphDepth > 0) {
          paragraphDepth--;
        }

        if (([currentTagName isEqualToString:@"ul"] ||
             [currentTagName isEqualToString:@"ol"]) &&
            ongoingListTags.count > 0) {
          [ongoingListTags removeLastObject];
          if (ongoingListContextIds.count > 0) {
            [ongoingListContextIds removeLastObject];
          }
        }
      }
      // post-tag cleanup
      closingTag = NO;
      currentTagStartIndex = -1;
      currentTagName = [[NSMutableString alloc] initWithString:@""];
      currentTagParams = [[NSMutableString alloc] initWithString:@""];
    } else {
      if (!insideTag) {
        // no tags logic - just append the right text

        // html entity on the index; use unescaped character and forward
        // iterator accordingly
        NSArray *entityInfo = htmlEntitiesDict[@(i)];
        if (entityInfo != nullptr) {
          NSString *escaped = entityInfo[0];
          NSString *unescaped = entityInfo[1];
          [plainText appendString:unescaped];
          if ([unescaped
                  rangeOfCharacterFromSet:[[NSCharacterSet
                                              whitespaceAndNewlineCharacterSet]
                                              invertedSet]]
                  .location != NSNotFound) {
            lastVisibleTokenWasImage = NO;
            lastVisibleTokenWasStandaloneImage = NO;
          }
          // the iterator will forward by 1 itself
          i += escaped.length - 1;
        } else {
          [plainText appendString:currentCharacterStr];
          if (![[NSCharacterSet whitespaceAndNewlineCharacterSet]
                  characterIsMember:currentCharacterChar]) {
            lastVisibleTokenWasImage = NO;
            lastVisibleTokenWasStandaloneImage = NO;
          }
        }
      } else {
        if (gettingTagName) {
          if (currentCharacterChar == ' ') {
            // no longer getting tag name - switch to params
            gettingTagName = NO;
            gettingTagParams = YES;
          } else if (currentCharacterChar == '/') {
            // mark that the tag is closing
            closingTag = YES;
          } else {
            // append next tag char
            [currentTagName appendString:currentCharacterStr];
          }
        } else if (gettingTagParams) {
          // append next tag params char
          [currentTagParams appendString:currentCharacterStr];
        }
      }
    }
  }

  // process tags into proper StyleType + StylePair values
  NSMutableArray *processedStyles = [[NSMutableArray alloc] init];

  for (NSArray *arr in initiallyProcessedTags) {
    NSString *tagName = (NSString *)arr[0];
    NSValue *tagRangeValue = (NSValue *)arr[1];
    NSMutableString *params = [[NSMutableString alloc] initWithString:@""];
    if (arr.count > 2) {
      [params appendString:(NSString *)arr[2]];
    }

    NSMutableArray *styleArr = [[NSMutableArray alloc] init];
    StylePair *stylePair = [[StylePair alloc] init];

    if ([tagName isEqualToString:@"b"]) {
      [styleArr addObject:@([BoldStyle getType])];
    } else if ([tagName isEqualToString:@"i"]) {
      [styleArr addObject:@([ItalicStyle getType])];
    } else if ([tagName isEqualToString:@"img"]) {
      NSRegularExpression *srcRegex =
          [NSRegularExpression regularExpressionWithPattern:@"src=\"([^\"]+)\""
                                                    options:0
                                                      error:nullptr];
      NSTextCheckingResult *match =
          [srcRegex firstMatchInString:params
                               options:0
                                 range:NSMakeRange(0, params.length)];

      if (match == nullptr) {
        continue;
      }

      NSRange srcRange = match.range;
      [styleArr addObject:@([ImageStyle getType])];
      // cut only the uri from the src="..." string
      NSString *uri =
          [params substringWithRange:NSMakeRange(srcRange.location + 5,
                                                 srcRange.length - 6)];
      ImageData *imageData = [[ImageData alloc] init];
      imageData.uri = uri;
      imageData.standalone =
          [params containsString:@"data-enriched-image-standalone=\"true\""];

      NSRegularExpression *widthRegex = [NSRegularExpression
          regularExpressionWithPattern:@"width=\"([0-9.]+)\""
                               options:0
                                 error:nil];
      NSTextCheckingResult *widthMatch =
          [widthRegex firstMatchInString:params
                                 options:0
                                   range:NSMakeRange(0, params.length)];

      if (widthMatch) {
        NSString *widthString =
            [params substringWithRange:[widthMatch rangeAtIndex:1]];
        imageData.width = [widthString floatValue];
      }

      NSRegularExpression *heightRegex = [NSRegularExpression
          regularExpressionWithPattern:@"height=\"([0-9.]+)\""
                               options:0
                                 error:nil];
      NSTextCheckingResult *heightMatch =
          [heightRegex firstMatchInString:params
                                  options:0
                                    range:NSMakeRange(0, params.length)];

      if (heightMatch) {
        NSString *heightString =
            [params substringWithRange:[heightMatch rangeAtIndex:1]];
        imageData.height = [heightString floatValue];
      }

      stylePair.styleValue = imageData;
    } else if ([tagName isEqualToString:@"u"]) {
      [styleArr addObject:@([UnderlineStyle getType])];
    } else if ([tagName isEqualToString:@"s"]) {
      [styleArr addObject:@([StrikethroughStyle getType])];
    } else if ([tagName isEqualToString:@"code"]) {
      [styleArr addObject:@([InlineCodeStyle getType])];
    } else if ([tagName isEqualToString:@"a"]) {
      NSRegularExpression *hrefRegex =
          [NSRegularExpression regularExpressionWithPattern:@"href=\".+\""
                                                    options:0
                                                      error:nullptr];
      NSTextCheckingResult *match =
          [hrefRegex firstMatchInString:params
                                options:0
                                  range:NSMakeRange(0, params.length)];

      if (match == nullptr) {
        // same as on Android, no href (or empty href) equals no link style
        continue;
      }

      NSRange hrefRange = match.range;
      [styleArr addObject:@([LinkStyle getType])];
      // cut only the url from the href="..." string
      NSString *url =
          [params substringWithRange:NSMakeRange(hrefRange.location + 6,
                                                 hrefRange.length - 7)];
      NSString *text = [plainText substringWithRange:tagRangeValue.rangeValue];

      LinkData *linkData = [[LinkData alloc] init];
      linkData.url = url;
      linkData.text = text;
      linkData.isManual = ![text isEqualToString:url];

      stylePair.styleValue = linkData;
    } else if ([tagName isEqualToString:@"mention"]) {
      [styleArr addObject:@([MentionStyle getType])];
      // extract html expression into dict using some regex
      NSMutableDictionary *paramsDict = [[NSMutableDictionary alloc] init];
      NSString *pattern = @"(\\w+)=(['\"])(.*?)\\2";
      NSRegularExpression *regex =
          [NSRegularExpression regularExpressionWithPattern:pattern
                                                    options:0
                                                      error:nil];

      [regex enumerateMatchesInString:params
                              options:0
                                range:NSMakeRange(0, params.length)
                           usingBlock:^(NSTextCheckingResult *_Nullable result,
                                        NSMatchingFlags flags,
                                        BOOL *_Nonnull stop) {
                             if (result.numberOfRanges == 4) {
                               NSString *key = [params
                                   substringWithRange:[result rangeAtIndex:1]];
                               NSString *value = [params
                                   substringWithRange:[result rangeAtIndex:3]];
                               paramsDict[key] = value;
                             }
                           }];

      MentionParams *mentionParams = [[MentionParams alloc] init];
      mentionParams.text = paramsDict[@"text"];
      mentionParams.indicator = paramsDict[@"indicator"];

      [paramsDict removeObjectsForKeys:@[ @"text", @"indicator" ]];
      NSError *error;
      NSData *attrsData = [NSJSONSerialization dataWithJSONObject:paramsDict
                                                          options:0
                                                            error:&error];
      NSString *formattedAttrsString =
          [[NSString alloc] initWithData:attrsData
                                encoding:NSUTF8StringEncoding];
      mentionParams.attributes = formattedAttrsString;

      stylePair.styleValue = mentionParams;
    } else if ([tagName isEqualToString:@"h1"]) {
      [styleArr addObject:@([H1Style getType])];
    } else if ([tagName isEqualToString:@"h2"]) {
      [styleArr addObject:@([H2Style getType])];
    } else if ([tagName isEqualToString:@"h3"]) {
      [styleArr addObject:@([H3Style getType])];
    } else if ([tagName isEqualToString:@"h4"]) {
      [styleArr addObject:@([H4Style getType])];
    } else if ([tagName isEqualToString:@"h5"]) {
      [styleArr addObject:@([H5Style getType])];
    } else if ([tagName isEqualToString:@"h6"]) {
      [styleArr addObject:@([H6Style getType])];
    } else if ([tagName isEqualToString:@"li"]) {
      NSString *listItemTag = [self listItemTagFromParams:params];
      if (listItemTag == nil) {
        continue;
      }

      NSInteger listLevel = [self listLevelFromParams:params];
      NSInteger listContextId = [self listContextFromParams:params];
      NSString *baseValue = nil;
      NSString *continuationBaseValue = nil;
      NSNumber *styleType = nil;

      if ([listItemTag isEqualToString:@"checkbox"]) {
        BOOL isChecked =
            [self checkboxStateInListItemRange:tagRangeValue.rangeValue
                                checkboxStates:checkboxStates];
        baseValue = isChecked ? @"EnrichedCheckbox1" : @"EnrichedCheckbox0";
        continuationBaseValue = @"EnrichedCheckboxContinuation";
        styleType = @([CheckboxListStyle getType]);
      } else {
        baseValue = [listItemTag isEqualToString:@"ol"]
                        ? @"EnrichedOrderedList"
                        : @"EnrichedUnorderedList";
        continuationBaseValue =
            [baseValue stringByAppendingString:@"Continuation"];
        styleType = [listItemTag isEqualToString:@"ol"]
                        ? @([OrderedListStyle getType])
                        : @([UnorderedListStyle getType]);
      }

      NSArray<NSValue *> *paragraphRanges =
          [self paragraphRangesInListItemRange:tagRangeValue.rangeValue
                                     plainText:plainText];
      NSNumber *checkboxStatePosition =
          [listItemTag isEqualToString:@"checkbox"]
              ? [self checkboxStatePositionInListItemRange:tagRangeValue
                                                               .rangeValue
                                            checkboxStates:checkboxStates]
              : nil;
      BOOL hasEmittedBaseListMarker = NO;

      for (NSUInteger paragraphIndex = 0;
           paragraphIndex < paragraphRanges.count; paragraphIndex++) {
        NSRange paragraphRange = [paragraphRanges[paragraphIndex] rangeValue];
        if (checkboxStatePosition != nil &&
            NSMaxRange(paragraphRange) <=
                [checkboxStatePosition unsignedIntegerValue]) {
          continue;
        }

        BOOL shouldUseBaseMarker = checkboxStatePosition != nil
                                       ? !hasEmittedBaseListMarker
                                       : paragraphIndex == 0;
        NSMutableArray *listStyleArr = [[NSMutableArray alloc] init];
        StylePair *listStylePair = [[StylePair alloc] init];
        listStylePair.rangeValue = paragraphRanges[paragraphIndex];
        listStylePair.styleValue =
            [self listMarkerValueWithBase:(shouldUseBaseMarker
                                               ? baseValue
                                               : continuationBaseValue)
                                    level:listLevel
                                contextId:listContextId];
        if (shouldUseBaseMarker) {
          hasEmittedBaseListMarker = YES;
        }
        [listStyleArr addObject:styleType];
        [listStyleArr addObject:listStylePair];
        [processedStyles addObject:listStyleArr];

        NSInteger quoteContextId = [self blockQuoteContextFromParams:params];
        if (quoteContextId >= 0) {
          NSMutableArray *blockQuoteStyleArr = [[NSMutableArray alloc] init];
          StylePair *blockQuoteStylePair = [[StylePair alloc] init];
          blockQuoteStylePair.rangeValue = paragraphRanges[paragraphIndex];
          blockQuoteStylePair.styleValue =
              [self blockQuoteMarkerValueWithLevel:
                        [self blockQuoteLevelFromParams:params]
                                         contextId:quoteContextId];
          [blockQuoteStyleArr addObject:@([BlockQuoteStyle getType])];
          [blockQuoteStyleArr addObject:blockQuoteStylePair];
          [processedStyles addObject:blockQuoteStyleArr];
        }
      }
      continue;
    } else if ([tagName isEqualToString:@"ul"]) {
      if ([self isUlCheckboxList:params]) {
        continue;
      }
      continue;
    } else if ([tagName isEqualToString:@"ol"]) {
      continue;
    } else if ([tagName isEqualToString:@"blockquote"]) {
      [styleArr addObject:@([BlockQuoteStyle getType])];
      NSInteger quoteLevel = [self blockQuoteLevelFromParams:params];
      NSInteger quoteContextId = [self blockQuoteContextFromParams:params];
      stylePair.styleValue =
          [self blockQuoteMarkerValueWithLevel:quoteLevel
                                     contextId:quoteContextId];
    } else if ([tagName isEqualToString:@"codeblock"]) {
      [styleArr addObject:@([CodeBlockStyle getType])];

      NSInteger quoteContextId = [self blockQuoteContextFromParams:params];
      if (quoteContextId >= 0) {
        NSMutableArray *blockQuoteStyleArr = [[NSMutableArray alloc] init];
        StylePair *blockQuoteStylePair = [[StylePair alloc] init];
        blockQuoteStylePair.rangeValue = tagRangeValue;
        blockQuoteStylePair.styleValue = [self
            blockQuoteMarkerValueWithLevel:[self
                                               blockQuoteLevelFromParams:params]
                                 contextId:quoteContextId];
        [blockQuoteStyleArr addObject:@([BlockQuoteStyle getType])];
        [blockQuoteStyleArr addObject:blockQuoteStylePair];
        [processedStyles addObject:blockQuoteStyleArr];
      }
    } else {
      // some other external tags like span just don't get put into the
      // processed styles
      continue;
    }

    stylePair.rangeValue = tagRangeValue;
    [styleArr addObject:stylePair];
    [processedStyles addObject:styleArr];
  }

  [self sortProcessedStylesByRangeContainment:processedStyles];

  return @[ plainText, processedStyles, foundAlignments ];
}

+ (NSString *)parseToHtmlFromRange:(NSRange)range
                              host:(id<EnrichedViewHost>)host {
  NSInteger offset = range.location;
  NSString *text = [host.textView.textStorage.string substringWithRange:range];

  if (text.length == 0) {
    return @"<html>\n<p></p>\n</html>";
  }

  NSMutableString *result = [[NSMutableString alloc] initWithString:@"<html>"];
  NSSet<NSNumber *> *previousActiveStyles = [[NSSet<NSNumber *> alloc] init];
  BOOL newLine = YES;
  BOOL inUnorderedList = NO;
  BOOL inOrderedList = NO;
  NSInteger blockQuoteDepth = 0;
  NSString *blockQuoteMarker = nil;
  BOOL inCodeBlock = NO;
  BOOL inCheckboxList = NO;
  unichar lastCharacter = 0;

  for (int i = 0; i < text.length; i++) {
    NSRange currentRange = NSMakeRange(offset + i, 1);
    NSMutableSet<NSNumber *> *currentActiveStyles =
        [[NSMutableSet<NSNumber *> alloc] init];
    NSMutableDictionary *currentActiveStylesBeginning =
        [[NSMutableDictionary alloc] init];

    // check each existing style existence
    for (NSNumber *type in host.stylesDict) {
      StyleBase *style = host.stylesDict[type];
      // we do not want to add <></> tags for alignment
      if ([style isKindOfClass:[AlignmentStyle class]]) {
        continue;
      }
      if ([style detect:currentRange]) {
        [currentActiveStyles addObject:type];

        if (![previousActiveStyles member:type]) {
          currentActiveStylesBeginning[type] = [NSNumber numberWithInt:i];
        }
      } else if ([previousActiveStyles member:type]) {
        [currentActiveStylesBeginning removeObjectForKey:type];
      }
    }

    NSString *currentCharacterStr =
        [host.textView.textStorage.string substringWithRange:currentRange];
    unichar currentCharacterChar = [host.textView.textStorage.string
        characterAtIndex:currentRange.location];

    if ([[NSCharacterSet newlineCharacterSet]
            characterIsMember:currentCharacterChar]) {
      if (newLine) {
        // we can either have an empty list item OR need to close the list and
        // put a BR in such a situation the existence of the list must be
        // checked on 0 length range, not on the newline character
        if (inOrderedList) {
          OrderedListStyle *oStyle = host.stylesDict[@(OrderedList)];
          BOOL detected = [oStyle detect:NSMakeRange(currentRange.location, 0)];
          if (detected) {
            [result appendString:@"\n<li></li>"];
          } else {
            [result appendString:@"\n</ol>\n<br>"];
            inOrderedList = NO;
          }
        } else if (inUnorderedList) {
          UnorderedListStyle *uStyle = host.stylesDict[@(UnorderedList)];
          BOOL detected = [uStyle detect:NSMakeRange(currentRange.location, 0)];
          if (detected) {
            [result appendString:@"\n<li></li>"];
          } else {
            [result appendString:@"\n</ul>\n<br>"];
            inUnorderedList = NO;
          }
        } else if (blockQuoteDepth > 0) {
          BlockQuoteStyle *bqStyle = host.stylesDict[@(BlockQuote)];
          BOOL detected =
              [bqStyle detect:NSMakeRange(currentRange.location, 0)];
          if (detected) {
            [result appendString:@"\n<br>"];
          } else {
            [self appendClosingBlockQuotes:blockQuoteDepth toResult:result];
            [result appendString:@"\n<br>"];
            blockQuoteDepth = 0;
            blockQuoteMarker = nil;
          }
        } else if (inCodeBlock) {
          CodeBlockStyle *cbStyle = host.stylesDict[@(CodeBlock)];
          BOOL detected =
              [cbStyle detect:NSMakeRange(currentRange.location, 0)];
          if (detected) {
            [result appendString:@"\n<br>"];
          } else {
            [result appendString:@"\n</codeblock>\n<br>"];
            inCodeBlock = NO;
          }
        } else if (inCheckboxList) {
          CheckboxListStyle *cbLStyle = host.stylesDict[@(CheckboxList)];
          BOOL detected =
              [cbLStyle detect:NSMakeRange(currentRange.location, 0)];
          if (detected) {
            BOOL checked = [cbLStyle getCheckboxStateAt:currentRange.location];
            if (checked) {
              [result appendString:@"\n<li checked></li>"];
            } else {
              [result appendString:@"\n<li></li>"];
            }
          } else {
            [result appendString:@"\n</ul>\n<br>"];
            inCheckboxList = NO;
          }
        } else {
          [result appendString:@"\n<br>"];
        }
      } else {
        // newline finishes a paragraph and all style tags need to be closed
        // we use previous styles
        NSArray<NSNumber *> *sortedEndedStyles = [previousActiveStyles
            sortedArrayUsingDescriptors:@[ [NSSortDescriptor
                                            sortDescriptorWithKey:@"intValue"
                                                        ascending:NO] ]];

        // append closing tags
        for (NSNumber *style in sortedEndedStyles) {
          if ([style isEqualToNumber:@([ImageStyle getType])]) {
            continue;
          }
          NSString *tagContent = [self tagContentForStyle:style
                                               openingTag:NO
                                                 location:currentRange.location
                                                     host:host];
          [result
              appendString:[NSString stringWithFormat:@"</%@>", tagContent]];
        }

        // append closing paragraph tag
        if ([previousActiveStyles
                containsObject:@([UnorderedListStyle getType])] ||
            [previousActiveStyles
                containsObject:@([OrderedListStyle getType])] ||
            [previousActiveStyles containsObject:@([H1Style getType])] ||
            [previousActiveStyles containsObject:@([H2Style getType])] ||
            [previousActiveStyles containsObject:@([H3Style getType])] ||
            [previousActiveStyles containsObject:@([H4Style getType])] ||
            [previousActiveStyles containsObject:@([H5Style getType])] ||
            [previousActiveStyles containsObject:@([H6Style getType])] ||
            [previousActiveStyles
                containsObject:@([BlockQuoteStyle getType])] ||
            [previousActiveStyles containsObject:@([CodeBlockStyle getType])] ||
            [previousActiveStyles
                containsObject:@([CheckboxListStyle getType])]) {
          // do nothing, proper closing paragraph tags have been already
          // appended
        } else {
          [result appendString:@"</p>"];
        }
      }

      // clear the previous styles
      previousActiveStyles = [[NSSet<NSNumber *> alloc] init];

      // next character opens new paragraph
      newLine = YES;
    } else {
      // new line - open the paragraph
      if (newLine) {
        newLine = NO;
        NSString *desiredBlockQuoteMarker =
            [currentActiveStyles containsObject:@([BlockQuoteStyle getType])]
                ? [self blockQuoteMarkerAtLocation:currentRange.location
                                              host:host]
                : nil;
        NSInteger desiredBlockQuoteDepth =
            [self blockQuoteDepthFromMarker:desiredBlockQuoteMarker];

        // handle ending unordered list
        if (inUnorderedList &&
            ![currentActiveStyles
                containsObject:@([UnorderedListStyle getType])]) {
          inUnorderedList = NO;
          [result appendString:@"\n</ul>"];
        }
        // handle ending ordered list
        if (inOrderedList &&
            ![currentActiveStyles
                containsObject:@([OrderedListStyle getType])]) {
          inOrderedList = NO;
          [result appendString:@"\n</ol>"];
        }
        // handle ending blockquotes
        if (blockQuoteDepth > desiredBlockQuoteDepth) {
          [self
              appendClosingBlockQuotes:blockQuoteDepth - desiredBlockQuoteDepth
                              toResult:result];
          blockQuoteDepth = desiredBlockQuoteDepth;
          blockQuoteMarker = desiredBlockQuoteMarker;
        } else if (blockQuoteDepth > 0 &&
                   desiredBlockQuoteDepth == blockQuoteDepth &&
                   blockQuoteMarker != nil && desiredBlockQuoteMarker != nil &&
                   ![blockQuoteMarker
                       isEqualToString:desiredBlockQuoteMarker]) {
          [self appendClosingBlockQuotes:blockQuoteDepth toResult:result];
          blockQuoteDepth = 0;
          blockQuoteMarker = nil;
        }
        // handle ending codeblock
        if (inCodeBlock &&
            ![currentActiveStyles containsObject:@([CodeBlockStyle getType])]) {
          inCodeBlock = NO;
          [result appendString:@"\n</codeblock>"];
        }
        // handle ending checkbox list
        if (inCheckboxList &&
            ![currentActiveStyles
                containsObject:@([CheckboxListStyle getType])]) {
          inCheckboxList = NO;
          [result appendString:@"\n</ul>"];
        }

        NSString *cssStyleString =
            [self prepareCssStyleString:currentRange.location
                           isOpeningTag:YES
                                   host:host];

        // handle starting unordered list
        if (!inUnorderedList &&
            [currentActiveStyles
                containsObject:@([UnorderedListStyle getType])]) {
          inUnorderedList = YES;
          [result appendString:[NSString stringWithFormat:@"\n<ul%@>",
                                                          cssStyleString]];
        }
        // handle starting ordered list
        if (!inOrderedList &&
            [currentActiveStyles
                containsObject:@([OrderedListStyle getType])]) {
          inOrderedList = YES;
          [result appendString:[NSString stringWithFormat:@"\n<ol%@>",
                                                          cssStyleString]];
        }
        // handle starting blockquotes
        if (desiredBlockQuoteDepth > blockQuoteDepth) {
          [self
              appendOpeningBlockQuotes:desiredBlockQuoteDepth - blockQuoteDepth
                              toResult:result];
          blockQuoteDepth = desiredBlockQuoteDepth;
          blockQuoteMarker = desiredBlockQuoteMarker;
        }
        // handle starting codeblock
        if (!inCodeBlock &&
            [currentActiveStyles containsObject:@([CodeBlockStyle getType])]) {
          inCodeBlock = YES;
          [result appendString:@"\n<codeblock>"];
        }
        // handle starting checkbox list
        if (!inCheckboxList &&
            [currentActiveStyles
                containsObject:@([CheckboxListStyle getType])]) {
          inCheckboxList = YES;
          [result appendString:[NSString stringWithFormat:
                                             @"\n<ul data-type=\"checkbox\"%@>",
                                             cssStyleString]];
        }

        // don't add the <p> tag if some paragraph styles are present
        if ([currentActiveStyles
                containsObject:@([UnorderedListStyle getType])] ||
            [currentActiveStyles
                containsObject:@([OrderedListStyle getType])] ||
            [currentActiveStyles containsObject:@([H1Style getType])] ||
            [currentActiveStyles containsObject:@([H2Style getType])] ||
            [currentActiveStyles containsObject:@([H3Style getType])] ||
            [currentActiveStyles containsObject:@([H4Style getType])] ||
            [currentActiveStyles containsObject:@([H5Style getType])] ||
            [currentActiveStyles containsObject:@([H6Style getType])] ||
            [currentActiveStyles containsObject:@([BlockQuoteStyle getType])] ||
            [currentActiveStyles containsObject:@([CodeBlockStyle getType])] ||
            [currentActiveStyles
                containsObject:@([CheckboxListStyle getType])]) {
          [result appendString:@"\n"];
        } else {
          [result appendString:[NSString stringWithFormat:@"\n<p%@>",
                                                          cssStyleString]];
        }
      }

      // get styles that have ended
      NSMutableSet<NSNumber *> *endedStyles =
          [previousActiveStyles mutableCopy];
      [endedStyles minusSet:currentActiveStyles];

      // also finish styles that should be ended becasue they are nested in a
      // style that ended
      NSMutableSet *fixedEndedStyles = [endedStyles mutableCopy];
      NSMutableSet *stylesToBeReAdded = [[NSMutableSet alloc] init];

      for (NSNumber *style in endedStyles) {
        NSInteger styleBeginning =
            [currentActiveStylesBeginning[style] integerValue];

        for (NSNumber *activeStyle in currentActiveStyles) {
          NSInteger activeStyleBeginning =
              [currentActiveStylesBeginning[activeStyle] integerValue];

          // we end the styles that began after the currently ended style but
          // not at the "i" (cause the old style ended at exactly "i-1" also the
          // ones that began in the exact same place but are "inner" in relation
          // to them due to StyleTypeEnum integer values

          if ((activeStyleBeginning > styleBeginning &&
               activeStyleBeginning < i) ||
              (activeStyleBeginning == styleBeginning &&
               activeStyleBeginning<
                   i && [activeStyle integerValue]>[style integerValue])) {
            [fixedEndedStyles addObject:activeStyle];
            [stylesToBeReAdded addObject:activeStyle];
          }
        }
      }

      // if a style begins but there is a style inner to it that is (and was
      // previously) active, it also should be closed and readded

      // newly added styles
      NSMutableSet *newStyles = [currentActiveStyles mutableCopy];
      [newStyles minusSet:previousActiveStyles];
      // styles that were and still are active
      NSMutableSet *stillActiveStyles = [previousActiveStyles mutableCopy];
      [stillActiveStyles intersectSet:currentActiveStyles];

      for (NSNumber *style in newStyles) {
        for (NSNumber *ongoingStyle in stillActiveStyles) {
          if ([ongoingStyle integerValue] > [style integerValue]) {
            // the prev style is inner; needs to be closed and re-added later
            [fixedEndedStyles addObject:ongoingStyle];
            [stylesToBeReAdded addObject:ongoingStyle];
          }
        }
      }

      // they are sorted in a descending order
      NSArray<NSNumber *> *sortedEndedStyles = [fixedEndedStyles
          sortedArrayUsingDescriptors:@[ [NSSortDescriptor
                                          sortDescriptorWithKey:@"intValue"
                                                      ascending:NO] ]];

      // append closing tags
      for (NSNumber *style in sortedEndedStyles) {
        if ([style isEqualToNumber:@([ImageStyle getType])]) {
          continue;
        }
        NSString *tagContent = [self tagContentForStyle:style
                                             openingTag:NO
                                               location:currentRange.location
                                                   host:host];
        [result appendString:[NSString stringWithFormat:@"</%@>", tagContent]];
      }

      // all styles that have begun: new styles + the ones that need to be
      // re-added they are sorted in a ascending manner to properly keep tags'
      // FILO order
      [newStyles unionSet:stylesToBeReAdded];
      NSArray<NSNumber *> *sortedNewStyles = [newStyles
          sortedArrayUsingDescriptors:@[ [NSSortDescriptor
                                          sortDescriptorWithKey:@"intValue"
                                                      ascending:YES] ]];

      // append opening tags
      for (NSNumber *style in sortedNewStyles) {
        NSString *tagContent = [self tagContentForStyle:style
                                             openingTag:YES
                                               location:currentRange.location
                                                   host:host];
        if ([style isEqualToNumber:@([ImageStyle getType])]) {
          [result
              appendString:[NSString stringWithFormat:@"<%@/>", tagContent]];
          [currentActiveStyles removeObject:@([ImageStyle getType])];
        } else {
          [result appendString:[NSString stringWithFormat:@"<%@>", tagContent]];
        }
      }

      // append the letter and escape it if needed
      [result appendString:[NSString stringByEscapingHtml:currentCharacterStr]];

      // save current styles for next character's checks
      previousActiveStyles = currentActiveStyles;
    }

    // set last character
    lastCharacter = currentCharacterChar;
  }

  if (![[NSCharacterSet newlineCharacterSet] characterIsMember:lastCharacter]) {
    // not-newline character was last - finish the paragraph
    // close all pending tags
    NSArray<NSNumber *> *sortedEndedStyles = [previousActiveStyles
        sortedArrayUsingDescriptors:@[ [NSSortDescriptor
                                        sortDescriptorWithKey:@"intValue"
                                                    ascending:NO] ]];

    // append closing tags
    for (NSNumber *style in sortedEndedStyles) {
      if ([style isEqualToNumber:@([ImageStyle getType])]) {
        continue;
      }
      NSString *tagContent =
          [self tagContentForStyle:style
                        openingTag:NO
                          location:host.textView.textStorage.string.length - 1
                              host:host];
      [result appendString:[NSString stringWithFormat:@"</%@>", tagContent]];
    }

    // finish the paragraph
    // handle ending of some paragraph styles
    if ([previousActiveStyles containsObject:@([UnorderedListStyle getType])]) {
      [result appendString:@"\n</ul>"];
    } else if ([previousActiveStyles
                   containsObject:@([OrderedListStyle getType])]) {
      [result appendString:@"\n</ol>"];
    } else if ([previousActiveStyles
                   containsObject:@([BlockQuoteStyle getType])]) {
      NSInteger closingDepth = blockQuoteDepth > 0 ? blockQuoteDepth : 1;
      [self appendClosingBlockQuotes:closingDepth toResult:result];
      blockQuoteDepth = 0;
      blockQuoteMarker = nil;
    } else if ([previousActiveStyles
                   containsObject:@([CodeBlockStyle getType])]) {
      [result appendString:@"\n</codeblock>"];
    } else if ([previousActiveStyles
                   containsObject:@([CheckboxListStyle getType])]) {
      [result appendString:@"\n</ul>"];
    } else if ([previousActiveStyles containsObject:@([H1Style getType])] ||
               [previousActiveStyles containsObject:@([H2Style getType])] ||
               [previousActiveStyles containsObject:@([H3Style getType])] ||
               [previousActiveStyles containsObject:@([H4Style getType])] ||
               [previousActiveStyles containsObject:@([H5Style getType])] ||
               [previousActiveStyles containsObject:@([H6Style getType])]) {
      // do nothing, heading closing tag has already been appended
    } else {
      [result appendString:@"</p>"];
    }
  } else {
    // newline character was last - some paragraph styles need to be closed
    if (inUnorderedList) {
      inUnorderedList = NO;
      [result appendString:@"\n</ul>"];
    }
    if (inOrderedList) {
      inOrderedList = NO;
      [result appendString:@"\n</ol>"];
    }
    if (blockQuoteDepth > 0) {
      [self appendClosingBlockQuotes:blockQuoteDepth toResult:result];
      blockQuoteDepth = 0;
      blockQuoteMarker = nil;
    }
    if (inCodeBlock) {
      inCodeBlock = NO;
      [result appendString:@"\n</codeblock>"];
    }
    if (inCheckboxList) {
      inCheckboxList = NO;
      [result appendString:@"\n</ul>"];
    }
  }

  [result appendString:@"\n</html>"];

  // remove Object Replacement Characters in the very end
  [result replaceOccurrencesOfString:@"\uFFFC"
                          withString:@""
                             options:0
                               range:NSMakeRange(0, result.length)];

  // remove zero width spaces in the very end
  [result replaceOccurrencesOfString:@"\u200B"
                          withString:@""
                             options:0
                               range:NSMakeRange(0, result.length)];

  // replace empty <p></p> into <br> in the very end
  [result replaceOccurrencesOfString:@"<p></p>"
                          withString:@"<br>"
                             options:0
                               range:NSMakeRange(0, result.length)];

  return result;
}

+ (NSString *)tagContentForStyle:(NSNumber *)style
                      openingTag:(BOOL)openingTag
                        location:(NSInteger)location
                            host:(id<EnrichedViewHost>)host {
  NSString *cssStyleString = [self prepareCssStyleString:location
                                            isOpeningTag:openingTag
                                                    host:host];
  if ([style isEqualToNumber:@([BoldStyle getType])]) {
    return @"b";
  } else if ([style isEqualToNumber:@([ItalicStyle getType])]) {
    return @"i";
  } else if ([style isEqualToNumber:@([ImageStyle getType])]) {
    if (openingTag) {
      ImageStyle *imageStyle =
          (ImageStyle *)host.stylesDict[@([ImageStyle getType])];
      if (imageStyle != nullptr) {
        ImageData *data = [imageStyle getImageDataAt:location];
        if (data != nullptr && data.uri != nullptr) {
          return [NSString
              stringWithFormat:@"img src=\"%@\" width=\"%f\" height=\"%f\"",
                               data.uri, data.width, data.height];
        }
      }
      return @"img";
    } else {
      return @"";
    }
  } else if ([style isEqualToNumber:@([UnderlineStyle getType])]) {
    return @"u";
  } else if ([style isEqualToNumber:@([StrikethroughStyle getType])]) {
    return @"s";
  } else if ([style isEqualToNumber:@([InlineCodeStyle getType])]) {
    return @"code";
  } else if ([style isEqualToNumber:@([LinkStyle getType])]) {
    if (openingTag) {
      LinkStyle *linkStyle =
          (LinkStyle *)host.stylesDict[@([LinkStyle getType])];
      if (linkStyle != nullptr) {
        LinkData *data = [linkStyle getLinkDataAt:location];
        if (data != nullptr && data.url != nullptr) {
          return [NSString stringWithFormat:@"a href=\"%@\"", data.url];
        }
      }
      return @"a";
    } else {
      return @"a";
    }
  } else if ([style isEqualToNumber:@([MentionStyle getType])]) {
    if (openingTag) {
      MentionStyle *mentionStyle =
          (MentionStyle *)host.stylesDict[@([MentionStyle getType])];
      if (mentionStyle != nullptr) {
        MentionParams *params = [mentionStyle getMentionParamsAt:location];
        // attributes can theoretically be nullptr
        if (params != nullptr && params.indicator != nullptr &&
            params.text != nullptr) {
          NSMutableString *attrsStr =
              [[NSMutableString alloc] initWithString:@""];
          if (params.attributes != nullptr) {
            // turn attributes to Data and then into dict
            NSData *attrsData =
                [params.attributes dataUsingEncoding:NSUTF8StringEncoding];
            NSError *jsonError;
            NSDictionary *json =
                [NSJSONSerialization JSONObjectWithData:attrsData
                                                options:0
                                                  error:&jsonError];
            // format dict keys and values into string
            [json enumerateKeysAndObjectsUsingBlock:^(
                      id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
              [attrsStr
                  appendString:[NSString stringWithFormat:@" %@=\"%@\"",
                                                          (NSString *)key,
                                                          (NSString *)obj]];
            }];
          }
          return [NSString
              stringWithFormat:@"mention text=\"%@\" indicator=\"%@\"%@",
                               params.text, params.indicator, attrsStr];
        }
      }
      return @"mention";
    } else {
      return @"mention";
    }
  } else if ([style isEqualToNumber:@([H1Style getType])]) {
    return [NSString stringWithFormat:@"h1%@", cssStyleString];
  } else if ([style isEqualToNumber:@([H2Style getType])]) {
    return [NSString stringWithFormat:@"h2%@", cssStyleString];
  } else if ([style isEqualToNumber:@([H3Style getType])]) {
    return [NSString stringWithFormat:@"h3%@", cssStyleString];
  } else if ([style isEqualToNumber:@([H4Style getType])]) {
    return [NSString stringWithFormat:@"h4%@", cssStyleString];
  } else if ([style isEqualToNumber:@([H5Style getType])]) {
    return [NSString stringWithFormat:@"h5%@", cssStyleString];
  } else if ([style isEqualToNumber:@([H6Style getType])]) {
    return [NSString stringWithFormat:@"h6%@", cssStyleString];
  } else if ([style isEqualToNumber:@([UnorderedListStyle getType])] ||
             [style isEqualToNumber:@([OrderedListStyle getType])]) {
    return @"li";
  } else if ([style isEqualToNumber:@([CheckboxListStyle getType])]) {
    if (openingTag) {
      CheckboxListStyle *checkboxListStyleClass =
          (CheckboxListStyle *)host.stylesDict[@([CheckboxListStyle getType])];
      BOOL checked = [checkboxListStyleClass getCheckboxStateAt:location];

      if (checked) {
        return @"li checked";
      }
      return @"li";
    } else {
      return @"li";
    }
  } else if ([style isEqualToNumber:@([BlockQuoteStyle getType])] ||
             [style isEqualToNumber:@([CodeBlockStyle getType])]) {
    // blockquotes and codeblock use <p> tags the same way lists use <li>
    return [NSString stringWithFormat:@"p%@", cssStyleString];
  }
  return @"";
}

+ (NSString *)prepareCssStyleString:(NSInteger)location
                       isOpeningTag:(BOOL)isOpeningTag
                               host:(id<EnrichedViewHost>)host {
  if (!isOpeningTag) {
    return @"";
  }

  NSParagraphStyle *pStyle =
      [host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                   atIndex:location
                            effectiveRange:nil];
  NSString *alignStr = [AlignmentUtils cssValueForAlignment:pStyle.alignment];

  if (alignStr) {
    return [NSString stringWithFormat:@" style=\"text-align: %@\"", alignStr];
  }

  return @"";
}

+ (void)checkForAlignments:(NSArray *)tagData
                 plainText:(NSString *)plainText
           foundAlignments:(NSMutableArray<AlignmentEntry *> *)foundAlignments
       precedingImageCount:(NSInteger)precedingImageCount {
  if (tagData == nil) {
    return;
  }

  // We look at the params stored in ongoingTags
  NSString *storedParams = (tagData.count > 2) ? tagData[2] : nil;
  NSTextAlignment align =
      [AlignmentUtils alignmentFromStyleParams:storedParams];

  if (align != NSTextAlignmentNatural) {
    NSInteger startLoc = [tagData[0] integerValue];
    // Calculate range relative to plainText
    NSInteger actualStart = startLoc + precedingImageCount;
    NSInteger length = plainText.length - startLoc;

    if (length > 0) {
      AlignmentEntry *entry = [[AlignmentEntry alloc] init];
      entry.alignment = align;
      entry.range = NSMakeRange(actualStart, length);
      entry.expandListRange = NO;
      [foundAlignments addObject:entry];
    }
  }
}

@end
