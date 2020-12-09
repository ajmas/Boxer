/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFilterGallery.h"
#import "NSView+ADBDrawingHelpers.h"
#import "NSShadow+ADBShadowExtensions.h"
#import <QuartzCore/QuartzCore.h>

@implementation BXFilterGallery

- (void) drawRect: (NSRect)dirtyRect
{
	NSImage *wallpaper	= [NSImage imageNamed: @"GalleryBkg"];
	NSColor *pattern	= [NSColor colorWithPatternImage: wallpaper];
	
	NSSize patternSize	= wallpaper.size;
	NSSize viewSize		= self.bounds.size;
	NSPoint patternOffset	= [NSView focusView].offsetFromWindowOrigin;
	
	NSPoint patternPhase = NSMakePoint(
		//Center the pattern horizontally
		patternOffset.x + ((viewSize.width - patternSize.width) / 2),
		//Lock the pattern to the bottom of the view
		patternOffset.y + 1.0f
	);

	//Also add a bevel line at the bottom of the view
	NSColor *bevelColor = [NSColor whiteColor];
	NSRect bevelRect = self.bounds;
	bevelRect.size.height = 1.0f;
	
	//Fill the view with the background pattern and draw the bevel
	[NSGraphicsContext saveGraphicsState];
		[pattern set];
		[NSGraphicsContext currentContext].patternPhase = patternPhase;
		[NSBezierPath fillRect: dirtyRect];
	
		//Don't bother drawing the bevel if it's not dirty
		if (NSIntersectsRect(dirtyRect, bevelRect))
		{
			[bevelColor set];
			[NSBezierPath fillRect: bevelRect];
		}
	[NSGraphicsContext restoreGraphicsState];	
}
@end

@implementation BXFilterPortrait

+ (id)defaultAnimationForKey: (NSString *)key
{
    if ([key isEqualToString: @"illumination"])
		return [CABasicAnimation animation];

    return [super defaultAnimationForKey:key];
}

- (void) setState: (NSInteger)value
{
	[super setState: value];
	if (value)	[self.animator setIllumination: 1.0f];
	else		[self.animator setIllumination: 0.0f];
}

- (void) setIllumination: (CGFloat)newValue
{
	_illumination = newValue;
    self.needsDisplay = YES;
}
@end


@implementation BXFilterPortraitCell

#pragma mark -
#pragma mark Initialization and deallocation

- (void) awakeFromNib
{
	//Prevent the portrait from darkening when pressed in.
    self.highlightsBy = NSNoCellMask;
}


#pragma mark -
#pragma mark Button style

- (CGFloat) imageShadeLevelForIllumination: (CGFloat)illumination
{
	return (1.0f - illumination) * 0.33f;
}

- (CGFloat) imageHighlightLevel
{
	return 0.0f;
}

- (NSFont *) titleFont
{
	//Render the text in bold if this button is selected or the user is pressing the button
	if (self.state || self.isHighlighted)
		return [NSFont boldSystemFontOfSize: 0];
	else
		return [NSFont systemFontOfSize: 0];
}

- (NSColor *) titleColor
{
	//Render the text in white if this button is selected
	return (self.state) ? [NSColor whiteColor] : [NSColor lightGrayColor];
}

- (NSShadow *) titleShadow
{
    return [NSShadow shadowWithBlurRadius: 2.0f
                                   offset: NSMakeSize(0.0f, -1.0f)
                                    color: [NSColor blackColor]];
}

- (NSDictionary *) titleAttributes
{	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			self.titleFont, NSFontAttributeName,
			self.titleColor, NSForegroundColorAttributeName,
			self.titleShadow, NSShadowAttributeName,
			nil];
}

//Style the button title with our text shadow, colour and font
- (NSAttributedString *) attributedTitle
{
	NSMutableAttributedString *title = [super.attributedTitle mutableCopy];
	NSRange textRange = NSMakeRange(0, title.length);
	
	[title addAttributes: self.titleAttributes range: textRange];
	
	return title;
}

- (NSRect) titleRectForBounds: (NSRect)theRect
{
	//Position the title to occupy the bottom quarter of the button.
	theRect.origin.y = 72.0f;
	return theRect;
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
	//Fill the whole button with the image
	return theRect;
}


#pragma mark -
#pragma mark Button drawing

- (void) drawWithFrame: (NSRect)frame inView: (BXFilterPortrait *)controlView
{
	//Render our spotlight behind the rest of the button content
	if (controlView.illumination > 0.0f)
	{
		[self drawSpotlightWithFrame: frame
                              inView: controlView
                           withAlpha: controlView.illumination];
	}
	[super drawWithFrame: frame
                  inView: controlView];
}

- (void) drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha
{
	NSImage *spotlight = [NSImage imageNamed: @"GallerySpotlight"];
	
	[spotlight drawInRect: frame
				 fromRect: NSZeroRect
				operation: NSCompositingOperationPlusLighter
				 fraction: alpha
           respectFlipped: YES
                    hints: nil];
}

- (void) drawImage: (NSImage *)image	
		 withFrame: (NSRect)frame 
			inView: (BXFilterPortrait *)controlView
{
	NSColor *shade = nil;
	
	//If the button is being pressed, brighten the image
	if (self.isHighlighted && self.imageHighlightLevel)
	{
		CGFloat shadeLevel = self.imageHighlightLevel;
		shade = [NSColor colorWithCalibratedWhite: 1.0f alpha: shadeLevel];		
	}
	
	//Otherwise, darken the image according to the current illumination level
	else if (controlView.illumination < 0.9)
	{
		CGFloat shadeLevel = [self imageShadeLevelForIllumination: controlView.illumination];
		shade = [NSColor colorWithCalibratedWhite: 0.0f alpha: shadeLevel];
	}
	
	//Render the shade into a copy of the image before passing it on to NSButton's own draw methods
	if (shade)
	{
		NSImage *shadedImage = [image copy];
		NSRect bounds;
		bounds.origin = NSZeroPoint;
		bounds.size = shadedImage.size;
		
		[shadedImage lockFocus];
			[shade set];
			NSRectFillUsingOperation(bounds, NSCompositingOperationSourceAtop);
		[shadedImage unlockFocus];
		
		image = shadedImage;
	}
	
	//While we're here, let's override the image positioning with our own
	NSRect imageRect = [self imageRectForBounds: controlView.bounds];
	[super drawImage: image withFrame: imageRect inView: controlView];
}

@end
