#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"

@implementation H1Style
+ (StyleType)getType {
  return H1;
}
- (NSString *)getValue {
  return @"EnrichedH1";
}
- (BOOL)isParagraph {
  return YES;
}
- (CGFloat)getHeadingFontSize {
  return [self.host.config h1FontSize];
}
- (BOOL)isHeadingBold {
  return [self.host.config h1Bold];
}
- (void)applyStyling:(NSRange)range {
  [super applyStyling:range];
  UIColor *headingColor = [self.host.config linkColor];
  if ([headingColor isEqual:UIColor.blueColor]) {
    return;
  }
  [self.host.textView.textStorage addAttribute:NSForegroundColorAttributeName
                                         value:headingColor
                                         range:range];
  [self.host.textView.textStorage addAttribute:NSUnderlineColorAttributeName
                                         value:headingColor
                                         range:range];
  [self.host.textView.textStorage addAttribute:NSStrikethroughColorAttributeName
                                         value:headingColor
                                         range:range];
}
@end
