/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedButtonCell.h"
#import "ADBGeometry.h"
#import "NSImage+ADBImageEffects.h"

@implementation BXThemedButtonCell

#pragma mark - Default theme handling

+ (NSString *) defaultThemeKey
{
    return nil;
}

- (void) setThemeKey: (NSString *)key
{
    [super setThemeKey: key];
    [self.controlView setNeedsDisplay: YES];
}

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        if (![coder containsValueForKey: @"themeKey"])
            self.themeKey = [self.class defaultThemeKey];
    }
    return self;
}

- (NSRect) checkboxRectForBounds: (NSRect)frame
{
    NSRect checkboxFrame = frame;
    
	//Adjust by 0.5 so lines draw true
	checkboxFrame.origin.x += 0.5f;
	checkboxFrame.origin.y += 0.5f;
    
    switch (self.controlSize)
    {
        case NSControlSizeSmall:
            checkboxFrame.size.height = 10;
            checkboxFrame.size.width = 11;
            checkboxFrame.origin.y += 3;
            break;
            
        case NSControlSizeMini:
            checkboxFrame.size.height = 8;
            checkboxFrame.size.width = 9;
            checkboxFrame.origin.y += 5;
            break;
            
        case NSControlSizeRegular:
        default:
            checkboxFrame.size.height = 12;
            checkboxFrame.size.width = 13;
            checkboxFrame.origin.y += 2;
            break;   
    }
    
    //Adjust for image placement
    switch (self.imagePosition)
    {
        case NSImageLeft:
            switch (self.controlSize)
            {
                case NSControlSizeSmall:
                    checkboxFrame.origin.x += 3;
                    break;
                case NSControlSizeMini:
                    checkboxFrame.origin.x += 4;
                    break;
                case NSControlSizeRegular:
                default:
                    checkboxFrame.origin.x += 2;
                    break;
            }
			break;
			
		case NSImageRight:
            checkboxFrame.origin.x = NSWidth(frame) - NSWidth(checkboxFrame) - 1.5f;
            break;
            
		case NSImageOnly:
			if (self.controlSize == NSControlSizeRegular)
            {
				checkboxFrame.origin.x -= .5f;
			}
            else if (self.controlSize == NSControlSizeMini)
            {
				checkboxFrame.origin.x += .5f;
			}
			
			checkboxFrame.origin.x += (frame.size.width - checkboxFrame.size.width) / 2;
			break;
			
        default:
            break;
    }
    
    return checkboxFrame;
}

- (NSRect) radioButtonRectForBounds: (NSRect)frame
{
    NSRect radioFrame = [self checkboxRectForBounds: frame];
    radioFrame.size.height = radioFrame.size.width;
    return radioFrame;
}

- (NSRect) imageRectForImage: (NSImage *)image forBounds: (NSRect)frame
{   
    NSRect insetFrame = [self imageRectForBounds: frame];
    
    NSImageAlignment alignment;
    
    switch (self.imagePosition)
    {
        case NSImageOnly:
        case NSImageOverlaps:
            alignment = NSImageAlignCenter;
            break;
        case NSImageLeft:
            alignment = NSImageAlignLeft;
            break;
        case NSImageRight:
            alignment = NSImageAlignRight;
            break;
        case NSImageAbove:
            alignment = NSImageAlignTop;
            break;
        case NSNoImage:
        default:
            return NSZeroRect;
    }
    
    NSRect imageFrame = [image imageRectAlignedInRect: insetFrame
                                            alignment: alignment
                                              scaling: self.imageScaling];
    
    return imageFrame;
}


- (NSRect) titleRectForBounds: (NSRect)frame
             withCheckboxRect: (NSRect)checkboxFrame
{
    NSRect textFrame = frame;
    
    switch (self.imagePosition)
    {
		case NSImageLeft:
            switch (self.controlSize)
            {
                case NSControlSizeSmall:
                    textFrame.size.width -= (NSMaxX(checkboxFrame) + 6);
                    textFrame.origin.x = (NSMaxX(checkboxFrame) + 6);
                    textFrame.origin.y -= 1;
                    break;
                case NSControlSizeMini:
                    textFrame.size.width -= (NSMaxX(checkboxFrame) + 4);
                    textFrame.origin.x = (NSMaxX(checkboxFrame) + 4);
                    break;
                case NSControlSizeRegular:
                default:
                    textFrame.size.width -= (NSMaxX(checkboxFrame) + 5);
                    textFrame.origin.x = (NSMaxX(checkboxFrame) + 5);
                    textFrame.origin.y -= 2;
                    break;
            }
			break;
            
		case NSImageRight:
			switch (self.controlSize)
            {
                case NSControlSizeSmall:
                    textFrame.origin.x += 2;
                    textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                    textFrame.origin.y -= 1;
                    break;
                case NSControlSizeMini:
                    textFrame.origin.x += 2;
                    textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                    break;
                case NSControlSizeRegular:
                default:
                    textFrame.origin.x += 2;
                    textFrame.size.width = (NSMinX(checkboxFrame) - NSMinX(textFrame) - 5);
                    textFrame.origin.y -= 2;
                    break;
            }
			break;
            
        default:
            break;
	}
    
    return textFrame;
}

- (NSRect) titleRectForBounds: (NSRect)frame withImageRect: (NSRect)imageFrame
{
    return [self titleRectForBounds: frame withCheckboxRect: imageFrame];
}

- (NSBezierPath *) checkboxBezelForRect: (NSRect)rect
{
    return [NSBezierPath bezierPathWithRoundedRect: rect xRadius: 2 yRadius: 2];
}

- (NSBezierPath *) radioButtonBezelForRect: (NSRect)rect
{
    return [NSBezierPath bezierPathWithOvalInRect: rect];
}

- (NSBezierPath *) radioButtonGlyphForRect: (NSRect)frame
{
    NSBezierPath *path = nil;
    if (self.state == NSControlStateValueOn)
    {
        NSRect dotFrame;
        switch (self.controlSize)
        {
            case NSControlSizeSmall:
                dotFrame = NSInsetRect(frame, 3.5f, 3.5f);
                break;
                
            case NSControlSizeMini:
                dotFrame = NSInsetRect(frame, 3.0f, 3.0f);
                break;
                
            case NSControlSizeRegular:
            default:
                dotFrame = NSInsetRect(frame, 4.0f, 4.0f);
                break;
        }
        
        path = [[NSBezierPath alloc] init];
        [path appendBezierPathWithOvalInRect: dotFrame];
        
        //Indicates to the drawing context that this must be filled,
        //not stroked
        path.lineWidth = 0.0f;
    }
    return path;
}

- (NSBezierPath *) checkboxGlyphForRect: (NSRect)frame
{
    NSBezierPath *path;
    
    switch (self.state)
    {
		case NSControlStateValueMixed:
            {
                path = [[NSBezierPath alloc] init];
                NSPoint pointsMixed[2];
                
                pointsMixed[0] = NSMakePoint(NSMinX(frame) + 3, NSMidY(frame));
                pointsMixed[1] = NSMakePoint(NSMaxX(frame) - 3, NSMidY(frame));
                
                [path appendBezierPathWithPoints: pointsMixed count: 2];
                
                path.lineWidth = 2.0f;
            }
            break;
			
		case NSControlStateValueOn:
            {
                path = [[NSBezierPath alloc] init];
                NSPoint points[4];
                
                points[0] = NSMakePoint(NSMinX(frame) + 3, NSMidY(frame) - 2);
                points[1] = NSMakePoint(NSMidX(frame), NSMidY(frame) + 2);
                points[2] = NSMakePoint(NSMidX(frame), NSMidY(frame) + 2);
                points[3] = NSMakePoint(NSMinX(frame) + NSWidth(frame) - 1, NSMinY(frame) - 2);
                
                [path appendBezierPathWithPoints: points count: 4];
                
                path.lineWidth = (self.controlSize == NSControlSizeMini) ? 1.5f : 2.0f;
            }
            break;
            
        default:
            path = nil;
            break;
    }
    
    return path;
}

//Adapted from BGHUDButtonCell in its entirety, just so that we could change
//the damn tick color.
- (void) drawCheckInFrame: (NSRect)frame isRadio: (BOOL)radio
{
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
	NSRect bezelRect;
	NSBezierPath *bezelPath;
    NSBezierPath *glyphPath;
    
	if (radio) 
    {
        bezelRect = [self radioButtonRectForBounds: frame];
        bezelPath = [self radioButtonBezelForRect: bezelRect];
        glyphPath = [self radioButtonGlyphForRect: bezelRect];
    }
    else
    {
        bezelRect = [self checkboxRectForBounds: frame];
        bezelPath = [self checkboxBezelForRect: bezelRect];
        glyphPath = [self checkboxGlyphForRect: bezelRect];
    }
    bezelPath.lineWidth = 1.0f;
	
    //First draw the shadow
    [NSGraphicsContext saveGraphicsState];
        [theme.dropShadow set];
        [theme.darkStrokeColor set];
        [bezelPath stroke];
	[NSGraphicsContext restoreGraphicsState];
    
    //Then fill the bezel
    NSGradient *fillGradient;
    if (!self.isEnabled)            fillGradient = theme.disabledNormalGradient;
    else if (self.isHighlighted)    fillGradient = theme.highlightGradient;
    else                            fillGradient = theme.normalGradient;
    
    [fillGradient drawInBezierPath: bezelPath
                             angle: theme.gradientAngle];
    
    //Then stroke the outside of the bezel
	[NSGraphicsContext saveGraphicsState];
        [theme.strokeColor set];
        [bezelPath stroke];
	[NSGraphicsContext restoreGraphicsState];
	
    //Now finally draw the glyph
	[NSGraphicsContext saveGraphicsState];
        if (self.isEnabled)
            [theme.textColor set];
        else
            [theme.disabledTextColor set];
        
        if (glyphPath.lineWidth)
            [glyphPath stroke];
        else
            [glyphPath fill];
    [NSGraphicsContext restoreGraphicsState];
    
    
    //Finally, draw the text label (if we need to)
	if (self.imagePosition != NSImageOnly && self.attributedTitle)
    {
        NSRect titleRect = [self titleRectForBounds: frame
                                   withCheckboxRect: bezelRect];
        
        [self drawTitle: self.attributedTitle
              withFrame: titleRect
                 inView: self.controlView];
	}
}

- (void) drawImage: (NSImage *)image withFrame: (NSRect)frame inView: (NSView *)controlView
{
    //Radio buttons and switch buttons use a different code path which is handled upstream.
    if (buttonType == NSButtonTypeRadio || buttonType == NSButtonTypeSwitch)
    {
        [super drawImage: image withFrame: frame inView: controlView];
        return;
    }
    
    BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];
    
    NSRect imageRect = [self imageRectForImage: image
                                     forBounds: frame];
    
    CGFloat opacity = (self.isEnabled) ? theme.alphaValue : theme.disabledAlphaValue;

    if (image.isTemplate)
    {       
        NSColor *tint = (self.isEnabled) ? theme.textColor : theme.disabledTextColor;
        NSShadow *shadow = theme.textShadow;
        
        NSImage *tintedImage = [image imageFilledWithColor: tint atSize: imageRect.size];
        
        [NSGraphicsContext saveGraphicsState];
            [shadow set];
            [tintedImage drawInRect: imageRect
                           fromRect: NSZeroRect
                          operation: NSCompositingOperationSourceOver
                           fraction: opacity
                     respectFlipped: YES
                              hints: nil];
        [NSGraphicsContext restoreGraphicsState];
    }
    else
    {
        [image drawInRect: imageRect
                 fromRect: NSZeroRect
                operation: NSCompositingOperationSourceOver
                 fraction: opacity
           respectFlipped: YES
                    hints: nil];
    }
}

@end
