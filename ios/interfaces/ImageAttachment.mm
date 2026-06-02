#import "ImageAttachment.h"
#import "ImageExtension.h"
#import <ImageIO/ImageIO.h>

// NSTextStorage frequently recreates NSTextAttachment objects during attribute
// invalidation (e.g. on every keystroke). Without this cache each recreation
// would trigger a fresh async network/disk load, causing images to flicker or
// disappear temporarily. Caching by URI ensures that once an image is loaded it
// is reused instantly for all subsequent attachment instances with the same
// URI
static NSCache<NSString *, UIImage *> *ImageAttachmentCache(void) {
  static NSCache<NSString *, UIImage *> *cache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [[NSCache alloc] init];
    cache.totalCostLimit = 100 * 1024 * 1024; // 100 MB
  });
  return cache;
}

static NSMutableDictionary<NSString *, NSHashTable<ImageAttachment *> *> *
ImageAttachmentPendingLoads(void) {
  static NSMutableDictionary<NSString *, NSHashTable<ImageAttachment *> *>
      *pendingLoads = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pendingLoads = [[NSMutableDictionary alloc] init];
  });
  return pendingLoads;
}

static BOOL ImageAttachmentPropertiesContainKey(NSDictionary *properties,
                                                CFStringRef dictionaryKey,
                                                CFStringRef propertyKey) {
  NSDictionary *formatProperties =
      properties[(__bridge NSString *)dictionaryKey];
  return
      [formatProperties objectForKey:(__bridge NSString *)propertyKey] != nil;
}

static BOOL ImageAttachmentPropertiesContainAnyKey(NSDictionary *properties,
                                                   CFStringRef dictionaryKey,
                                                   NSArray *propertyKeys) {
  for (id propertyKey in propertyKeys) {
    if (ImageAttachmentPropertiesContainKey(
            properties, dictionaryKey, (__bridge CFStringRef)propertyKey)) {
      return YES;
    }
  }

  return NO;
}

static BOOL
ImageAttachmentPropertiesHaveAnimationMetadata(NSDictionary *properties) {
  if (properties == nil) {
    return NO;
  }

  return ImageAttachmentPropertiesContainAnyKey(
             properties, kCGImagePropertyGIFDictionary,
             @[
               (__bridge NSString *)kCGImagePropertyGIFDelayTime,
               (__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime
             ]) ||
         ImageAttachmentPropertiesContainAnyKey(
             properties, kCGImagePropertyPNGDictionary,
             @[
               (__bridge NSString *)kCGImagePropertyAPNGDelayTime,
               (__bridge NSString *)kCGImagePropertyAPNGUnclampedDelayTime,
               (__bridge NSString *)kCGImagePropertyAPNGFrameInfoArray,
               (__bridge NSString *)kCGImagePropertyAPNGLoopCount
             ]) ||
         ImageAttachmentPropertiesContainAnyKey(
             properties, kCGImagePropertyWebPDictionary,
             @[
               (__bridge NSString *)kCGImagePropertyWebPDelayTime,
               (__bridge NSString *)kCGImagePropertyWebPUnclampedDelayTime,
               (__bridge NSString *)kCGImagePropertyWebPFrameInfoArray,
               (__bridge NSString *)kCGImagePropertyWebPLoopCount
             ]) ||
         ImageAttachmentPropertiesContainAnyKey(
             properties, kCGImagePropertyHEICSDictionary, @[
               (__bridge NSString *)kCGImagePropertyHEICSDelayTime,
               (__bridge NSString *)kCGImagePropertyHEICSUnclampedDelayTime,
               (__bridge NSString *)kCGImagePropertyHEICSFrameInfoArray,
               (__bridge NSString *)kCGImagePropertyHEICSLoopCount
             ]);
}

static BOOL ImageAttachmentDataIsAnimated(NSData *data) {
  if (data.length == 0) {
    return NO;
  }

  CGImageSourceRef source =
      CGImageSourceCreateWithData((__bridge CFDataRef)data, nil);
  if (source == nil) {
    return NO;
  }

  size_t frameCount = CGImageSourceGetCount(source);
  if (frameCount <= 1) {
    CFRelease(source);
    return NO;
  }

  NSDictionary *sourceProperties =
      CFBridgingRelease(CGImageSourceCopyProperties(source, nil));
  if (ImageAttachmentPropertiesHaveAnimationMetadata(sourceProperties)) {
    CFRelease(source);
    return YES;
  }

  for (size_t frameIndex = 0; frameIndex < frameCount; frameIndex++) {
    NSDictionary *frameProperties = CFBridgingRelease(
        CGImageSourceCopyPropertiesAtIndex(source, frameIndex, nil));
    if (ImageAttachmentPropertiesHaveAnimationMetadata(frameProperties)) {
      CFRelease(source);
      return YES;
    }
  }

  CFRelease(source);

  // Some static containers, notably ICO files, expose multiple image
  // representations through CGImageSource. Those should not be treated as
  // animations, otherwise UIImageView cycles between representations and
  // appears to flicker.
  return NO;
}

@implementation ImageAttachment

- (void)applyLoadedImage:(UIImage *)image animated:(BOOL)isAnimatedImage {
  UIImage *imageToApply = image ?: [UIImage systemImageNamed:@"photo"];

  self.storedAnimatedImage = imageToApply;
  self.requiresOverlayRendering = isAnimatedImage;

  // Static images should be rendered by NSTextAttachment itself. Rendering
  // them through both TextKit and an overlay UIImageView causes the image to
  // flicker as the overlay is recreated/repositioned during text layout.
  self.image = isAnimatedImage ? [UIImage new] : imageToApply;
}

- (instancetype)initWithImageData:(ImageData *)data {
  self = [super initWithURI:data.uri width:data.width height:data.height];
  if (!self)
    return nil;

  _imageData = data;
  UIImage *cachedImage = nil;
  if (self.uri.length > 0) {
    cachedImage = [ImageAttachmentCache() objectForKey:self.uri];
  }

  // Assign an empty image to reserve layout space while async loading.
  self.image = [UIImage new];
  self.requiresOverlayRendering = NO;

  if (cachedImage != nil) {
    [self applyLoadedImage:cachedImage animated:cachedImage.images.count > 0];
  } else {
    [self loadAsync];
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
  CGRect baseBounds = self.bounds;

  if (!textContainer.layoutManager.textStorage ||
      charIndex >= textContainer.layoutManager.textStorage.length) {
    return baseBounds;
  }

  UIFont *font =
      [textContainer.layoutManager.textStorage attribute:NSFontAttributeName
                                                 atIndex:charIndex
                                          effectiveRange:NULL];
  if (!font) {
    return baseBounds;
  }

  // Extend the layout bounds below the baseline by the font's descender.
  // Without this, a line containing only the attachment has no descender space
  // below the baseline, but adding a text character introduces it — causing
  // the line height to jump.  By reserving descender space upfront the line
  // height stays consistent regardless of whether text is present.
  CGFloat descender = font.descender;
  return CGRectMake(baseBounds.origin.x, descender, baseBounds.size.width,
                    baseBounds.size.height - descender);
}

- (void)loadAsync {
  NSString *uri = [self.uri copy];
  NSURL *url = uri.length > 0 ? [NSURL URLWithString:uri] : nil;
  if (!url) {
    [self applyLoadedImage:[UIImage systemImageNamed:@"photo"] animated:NO];
    [self notifyUpdate];
    return;
  }

  NSMutableDictionary<NSString *, NSHashTable<ImageAttachment *> *>
      *pendingLoads = ImageAttachmentPendingLoads();

  @synchronized(pendingLoads) {
    NSHashTable<ImageAttachment *> *pendingAttachments = pendingLoads[uri];
    if (pendingAttachments != nil) {
      [pendingAttachments addObject:self];
      return;
    }

    pendingAttachments = [NSHashTable weakObjectsHashTable];
    [pendingAttachments addObject:self];
    pendingLoads[uri] = pendingAttachments;
  }

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSData *bytes = [NSData dataWithContentsOfURL:url];

    BOOL isAnimatedImage = bytes ? ImageAttachmentDataIsAnimated(bytes) : NO;
    UIImage *img = nil;
    if (bytes != nil) {
      img = isAnimatedImage ? [UIImage animatedImageWithData:bytes]
                            : [UIImage imageWithData:bytes];
    }
    if (img == nil) {
      img = [UIImage systemImageNamed:@"photo"];
      isAnimatedImage = NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (bytes != nil && img != nil && self.uri.length > 0) {
        CGFloat scale = img.scale;
        // Calculate true byte cost based on pixels
        // Width (in pixels) * Height (in pixels) * 4 bytes (for RGBA channels)
        NSUInteger cost = (NSUInteger)(img.size.width * scale *
                                       img.size.height * scale * 4.0);
        [ImageAttachmentCache() setObject:img forKey:uri cost:cost];
      }

      NSArray<ImageAttachment *> *attachments = nil;
      @synchronized(pendingLoads) {
        attachments = [pendingLoads[uri] allObjects];
        [pendingLoads removeObjectForKey:uri];
      }

      for (ImageAttachment *attachment in attachments) {
        [attachment applyLoadedImage:img animated:isAnimatedImage];
        [attachment notifyUpdate];
      }
    });
  });
}

@end
