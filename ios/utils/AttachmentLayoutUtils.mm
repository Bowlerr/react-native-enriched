#import "AttachmentLayoutUtils.h"

@implementation AttachmentLayoutUtils

+ (void)handleAttachmentUpdate:(MediaAttachment *)attachment
                      textView:(UITextView *)textView
                 onLayoutBlock:(dispatch_block_t)layoutBlock {
  NSTextStorage *storage = textView.textStorage;
  NSRange fullRange = NSMakeRange(0, storage.length);

  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);

  [storage enumerateAttribute:NSAttachmentAttributeName
                      inRange:fullRange
                      options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop) {
                     if (value == attachment) {
                       foundRange = range;
                       *stop = YES;
                     }
                   }];

  if (foundRange.location == NSNotFound) {
    return;
  }

  [storage edited:NSTextStorageEditedAttributes
               range:foundRange
      changeInLength:0];

  dispatch_async(dispatch_get_main_queue(), layoutBlock);
}

+ (NSMutableDictionary<NSString *, UIImageView *> *)
    layoutAttachmentsInTextView:(UITextView *)textView
                         config:(EnrichedConfig *)config
                  existingViews:
                      (NSMutableDictionary<NSString *, UIImageView *> *)
                          attachmentViews {
  NSTextStorage *storage = textView.textStorage;
  NSMutableDictionary<NSString *, UIImageView *> *activeAttachmentViews =
      [NSMutableDictionary dictionary];

  if (storage.length > 0) {
    __block NSUInteger imageIndex = 0;

    // Iterate over the entire text to find ImageAttachments
    [storage
        enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, storage.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:[ImageAttachment class]]) {
                    ImageAttachment *attachment = (ImageAttachment *)value;

                    // TextKit may recreate NSTextAttachment instances
                    // while preserving document content. Key overlay views
                    // by their document occurrence instead of attachment
                    // identity so loaded image views are reused during
                    // relayout/restyling.
                    NSString *key = [NSString
                        stringWithFormat:@"image:%lu:%@:%0.3f:%0.3f",
                                         (unsigned long)imageIndex++,
                                         attachment.uri ?: @"",
                                         attachment.width, attachment.height];

                    if (!attachment.requiresOverlayRendering) {
                      UIImageView *existingView = attachmentViews[key];
                      if (existingView != nil) {
                        [existingView removeFromSuperview];
                        [attachmentViews removeObjectForKey:key];
                      }
                      return;
                    }

                    CGRect rect = [self frameForAttachment:attachment
                                                   atRange:range
                                                  textView:textView
                                                    config:config];
                    if (CGRectIsEmpty(rect)) {
                      return;
                    }

                    UIImageView *imgView = attachmentViews[key];

                    if (!imgView) {
                      // It doesn't exist yet, create it
                      imgView = [[UIImageView alloc] initWithFrame:rect];
                      imgView.contentMode = UIViewContentModeScaleAspectFit;
                      imgView.tintColor = [UIColor labelColor];

                      // Add it directly to the TextView
                      [textView addSubview:imgView];
                    }

                    // Update position (in case text moved/scrolled)
                    if (!CGRectEqualToRect(imgView.frame, rect)) {
                      imgView.frame = rect;
                    }
                    UIImage *targetImage = attachment.storedAnimatedImage;
                    if (targetImage == nil && imgView.image == nil) {
                      targetImage = attachment.image;
                    }

                    // Only set if different to avoid resetting animation
                    // loops. If the attachment was recreated and is still
                    // loading, keep the previously loaded image instead of
                    // swapping it back to the blank placeholder.
                    if (targetImage != nil && imgView.image != targetImage) {
                      imgView.image = targetImage;
                    }

                    // Ensure it is visible on top
                    imgView.hidden = NO;
                    [textView bringSubviewToFront:imgView];

                    activeAttachmentViews[key] = imgView;
                    // Remove from the old map so we know it has been
                    // claimed
                    [attachmentViews removeObjectForKey:key];
                  }
                }];
  }

  // Everything remaining in attachmentViews is dead or off-screen
  for (UIImageView *danglingView in attachmentViews.allValues) {
    [danglingView removeFromSuperview];
  }

  return activeAttachmentViews;
}

+ (CGRect)frameForAttachment:(ImageAttachment *)attachment
                     atRange:(NSRange)range
                    textView:(UITextView *)textView
                      config:(EnrichedConfig *)config {
  NSLayoutManager *layoutManager = textView.layoutManager;
  NSTextContainer *textContainer = textView.textContainer;

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range
                                             actualCharacterRange:NULL];
  if (glyphRange.location == NSNotFound || glyphRange.length == 0) {
    return CGRectZero;
  }

  [layoutManager ensureLayoutForGlyphRange:glyphRange];

  CGRect glyphRect = [layoutManager boundingRectForGlyphRange:glyphRange
                                              inTextContainer:textContainer];
  CGSize attachmentSize = attachment.bounds.size;

  CGRect rect =
      CGRectMake(glyphRect.origin.x + textView.textContainerInset.left,
                 glyphRect.origin.y + textView.textContainerInset.top,
                 attachmentSize.width, attachmentSize.height);

  return CGRectIntegral(rect);
}

@end
