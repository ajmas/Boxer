/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImportDropzone.h"
#import "ADBGeometry.h"
#import <QuartzCore/QuartzCore.h>


/// The number of times the dropzone border animation will loop before stopping.
#define BXImportDropzoneBorderAnimationLoops 1000

#pragma mark -
#pragma mark Private method declarations

@interface BXImportDropzone ()

//(Re)draw our border and icon into the specified dirty region.
//Called from drawRect: when we don't have an image to display.
- (void) _drawDropZoneInRect: (NSRect)dirtyRect;

@end


@implementation BXImportDropzone

#pragma mark -
#pragma mark Helper class methods

+ (id) defaultAnimationForKey: (NSString *)key
{
	if ([key isEqualToString: @"borderOutset"])	return [CABasicAnimation animation];
	if ([key isEqualToString: @"borderPhase"])	return [CABasicAnimation animation];
	return [super defaultAnimationForKey: key];
}

+ (NSImage *) dropzoneIcon
{
	//Load up our dropzone icon, and render it in white
	static NSImage *icon;
	
	if (!icon)
	{
		icon = [[NSImage imageNamed: @"DropzoneTemplate"] copy];
		
		NSColor *tint = [NSColor whiteColor];
		
		NSRect bounds = NSZeroRect;
		bounds.size = [icon size];
		
		[icon lockFocus];
		[tint set];
		NSRectFillUsingOperation(bounds, NSCompositingOperationSourceAtop);
		[icon unlockFocus];
	}
	return icon;
}

+ (NSShadow *) dropzoneShadow
{
	static NSShadow *dropzoneShadow;
	if (!dropzoneShadow)
	{
		dropzoneShadow = [[NSShadow alloc] init];
		[dropzoneShadow setShadowOffset: NSMakeSize(0.0f, 0.0f)];
		[dropzoneShadow setShadowBlurRadius: 3.0f];
		[dropzoneShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.5f]];
	}
	return [dropzoneShadow copy];
}


+ (NSShadow *) dropzoneHighlight
{
	static NSShadow *dropzoneHighlight;
	if (!dropzoneHighlight)
	{
		dropzoneHighlight = [[NSShadow alloc] init];
		[dropzoneHighlight setShadowOffset: NSMakeSize(0.0f, 0.0f)];
		[dropzoneHighlight setShadowBlurRadius: 3.0f];
		[dropzoneHighlight setShadowColor: [[NSColor whiteColor] colorWithAlphaComponent: 0.5f]];
	}
	return [dropzoneHighlight copy];
}

+ (NSBezierPath *) borderForFrame: (NSRect)frame withPhase: (CGFloat)phase
{
	//Border attributes for the bezier path
	CGFloat pattern[2]	= {12.0, 6.0};
	CGFloat borderWidth	= 4.0;
	
	//Round the rect up to integral values, to avoid blurry subpixel lines
	frame = NSIntegralRect(frame);
	
	//Fit the border entirely inside the frame
	NSRect insetFrame = NSInsetRect(frame, borderWidth / 2, borderWidth / 2);
	
	NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect: insetFrame
														   xRadius: borderWidth
														   yRadius: borderWidth];
	
	[border setLineWidth: borderWidth];
	[border setLineDash: pattern count: 2 phase: phase];
	
	return border;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (void) viewDidMoveToSuperview
{
	//Shut down the animation when this view gets cleaned up
	if (![self superview]) [self setHighlighted: NO];
}

- (void) setImage: (NSImage *)newImage
{
	//Turn off the highlighting once we receive an image to display
	[self setHighlighted: NO];
	
	[super setImage: newImage];
}

//Start up the border animation when we get highlighted, and stop it when we stop being highlighted
- (void) setHighlighted: (BOOL)highlight
{
	if (self.highlighted != highlight)
	{
		super.highlighted = highlight;
		
		if (self.highlighted)
		{
			//Animate the phase to a sufficiently high number that will take forever for us to reach
			//We have to loop the animation this way instead of with CAMediaTiming repeat options,
			//because the NSAnimatablePropertyContainer proxy doesn't take repeating animations
			//into account and will stack them.
			CGFloat maxPhase		= 18.0	* BXImportDropzoneBorderAnimationLoops;
			CFTimeInterval duration	= 1.0	* BXImportDropzoneBorderAnimationLoops;
			
			[NSAnimationContext beginGrouping];
				[[NSAnimationContext currentContext] setDuration: duration];
				[[self animator] setBorderPhase: maxPhase]; 
			[NSAnimationContext endGrouping];
			
			[[self animator] setBorderOutset: 8.0];
		}
		else 
		{
			[[self animator] setBorderPhase: 0.0];
			[[self animator] setBorderOutset: 0.0];
		}
	}
}

- (void) setBorderPhase: (CGFloat)phase
{
	//Wrap the phase to the length of our dash pattern
	_borderPhase = (CGFloat)((NSUInteger)phase % 18);
	[self setNeedsDisplay: YES];
}

- (void) setBorderOutset: (CGFloat)outset
{
	_borderOutset = outset;
	[self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark Drawing methods

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	[self _drawDropZoneInRect: dirtyRect];
}

- (void) _drawDropZoneInRect: (NSRect)dirtyRect
{
	NSColor *borderColor		= [NSColor whiteColor];
	NSImage *icon				= [[self class] dropzoneIcon];
	NSShadow *dropzoneShadow	= ([self isHighlighted] || [[self cell] isHighlighted]) ? [[self class] dropzoneHighlight] : [[self class] dropzoneShadow];
	
	CGFloat borderInset = 8.0 - [self borderOutset];
	NSRect borderFrame	= NSInsetRect([self bounds], borderInset, borderInset);
	
	//Inset the border enough to render the dropzone shadow without clipping
	CGFloat shadowRadius	= [dropzoneShadow shadowBlurRadius];
	borderFrame			= NSInsetRect(borderFrame, shadowRadius, shadowRadius);
	
	NSRect imageFrame	= NSZeroRect;
	imageFrame.size		= [icon size];
	imageFrame			= NSIntegralRect(centerInRect(imageFrame, [self bounds]));
	
	[NSGraphicsContext saveGraphicsState];
		[dropzoneShadow set];
	
		if (NSIntersectsRect(dirtyRect, borderFrame))
		{
			[borderColor set];
			NSBezierPath *border = [[self class] borderForFrame: borderFrame withPhase: self.borderPhase];
			[border stroke];
		}
		
		if (NSIntersectsRect(dirtyRect, imageFrame))
		{
			[icon drawInRect: imageFrame
					fromRect: NSZeroRect 
				   operation: NSCompositingOperationSourceOver
					fraction: 1.0
			  respectFlipped: YES
					   hints: nil];
		}
	[NSGraphicsContext restoreGraphicsState];
}

@end
