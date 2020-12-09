/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCoverArt.h"
#import "NSBezierPath+MCAdditions.h"
#import "ADBGeometry.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "ADBAppKitVersionHelpers.h"

@implementation BXCoverArt

//We give gameboxes a fairly strong shadow to lift them out from light backgrounds
+ (NSShadow *) dropShadowForSize: (NSSize)iconSize
{
	if (iconSize.height < 32) return nil;
	
	CGFloat blurRadius	= MAX(1.0, iconSize.height / 32);
	CGFloat offset		= MAX(1.0, iconSize.height / 128);
	
    return [NSShadow shadowWithBlurRadius: blurRadius
                                   offset: NSMakeSize(0, -offset)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.85]];
}

//We give gameboxes a soft white glow around the inside edge so that they show up well against dark backgrounds
+ (NSShadow *) innerGlowForSize: (NSSize)iconSize
{
	if (iconSize.height < 64) return nil;
	CGFloat blurRadius = MAX(1.0, iconSize.height / 64);
	
    return [NSShadow shadowWithBlurRadius: blurRadius
                                   offset: NSZeroSize
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.33]];
}

+ (NSImage *) shineForSize: (NSSize)iconSize
{ 
	NSImage *shine = [[NSImage imageNamed: @"BoxArtShine"] copy];
	[shine setSize: iconSize];
	return shine;
}

- (id) initWithSourceImage: (NSImage *)image
{
	if ((self = [super init]))
	{
		[self setSourceImage: image];
	}
	return self;
}

- (void) drawInRect: (NSRect)frame
{
	//Switch to high-quality interpolation before we begin, and restore it once we're done
	//(this is not stored by saveGraphicsState/restoreGraphicsState unfortunately)
	NSImageInterpolation oldInterpolation = [[NSGraphicsContext currentContext] imageInterpolation];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	NSSize iconSize	= frame.size;
	NSImage *image	= [self sourceImage];
	
	//Effects we'll be applying to the cover art
	NSImage *shine			= [[self class] shineForSize: iconSize];
	NSShadow *dropShadow	= [[self class] dropShadowForSize: iconSize];
	NSShadow *innerGlow		= [[self class] innerGlowForSize: iconSize];
	
	//Allow enough room around the image for our drop shadow
	NSSize availableSize	= NSMakeSize(
		iconSize.width	- [dropShadow shadowBlurRadius] * 2,
		iconSize.height	- [dropShadow shadowBlurRadius] * 2
	);

	NSRect artFrame;
	//Scale the image proportionally to fit our target box size
	artFrame.size	= sizeToFitSize([image size], availableSize);
	artFrame.origin	= NSMakePoint(
		//Center the box horizontally...
		(iconSize.width - artFrame.size.width) / 2,
		//...but put its baseline along the bottom, with enough room for the drop shadow
		([dropShadow shadowBlurRadius] - [dropShadow shadowOffset].height)
	);
	//Round the rect up to integral values, to avoid blurry subpixel lines
	artFrame = NSIntegralRect(artFrame);
	
	//Draw the original image into the appropriate space in the canvas, with our drop shadow
	[NSGraphicsContext saveGraphicsState];
		[dropShadow set];
		[image drawInRect: artFrame
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0f];
	[NSGraphicsContext restoreGraphicsState];
	
	//Draw the inner glow inside the box region
	[[NSBezierPath bezierPathWithRect: artFrame] fillWithInnerShadow: innerGlow];
	
	//Draw our pretty box shine into the box's region
	[shine drawInRect: artFrame
			 fromRect: artFrame
			operation: NSCompositingOperationSourceOver
			 fraction: 0.25];
	
	//Finally, outline the box
	[[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.33] set];
	[NSBezierPath setDefaultLineWidth: 1.0];
	[NSBezierPath strokeRect: NSInsetRect(artFrame, -0.5, -0.5)];
	
	[[NSGraphicsContext currentContext] setImageInterpolation: oldInterpolation];
}

- (NSImageRep *) representationForSize: (NSSize)iconSize
{
	return [self representationForSize: iconSize scale: 1];
}

- (NSImageRep *) representationForSize: (NSSize)iconSize scale: (CGFloat)scale
{	
	NSRect frame = NSMakeRect(0, 0, iconSize.width, iconSize.height);

	//Create a new empty canvas to draw into
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:iconSize.width * scale pixelsHigh:iconSize.height * scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:32];
	
	rep.size = iconSize;
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
		[self drawInRect: frame];
	[NSGraphicsContext restoreGraphicsState];
	
	return rep;
}

- (NSImage *) coverArt
{
	NSImage *image = [self sourceImage];
	
	//If our source image could not be read, then bail out.
	if (![image isValid]) return nil;
	
	//If our source image already has transparency data,
	//then assume that it already has effects of its own applied and don't process it.
	if ([[self class] imageHasTransparency: image]) return image;
	
	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(512, 512) scale: 2]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(512, 512)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(256, 256) scale: 2]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(256, 256)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(128, 128) scale: 2]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(128, 128)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(32, 32) scale: 2]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(32, 32)]];
	
	return coverArt;
}

+ (NSImage *) coverArtWithImage: (NSImage *)image
{
	id generator = [[self alloc] initWithSourceImage: image];
	return [generator coverArt];
}

+ (BOOL) imageHasTransparency: (NSImage *)image
{
	BOOL hasTranslucentPixels = NO;

	//Only bother testing transparency if the image has an alpha channel
	if ([[[image representations] lastObject] hasAlpha])
	{
		NSSize imageSize = [image size];
		
		//Test 5 pixels in an X pattern: each corner and right in the center of the image.
		NSPoint testPoints[5] = {
			NSMakePoint(0,						0),
			NSMakePoint(imageSize.width - 1.0,	0),
			NSMakePoint(0,						imageSize.height - 1.0),
			NSMakePoint(imageSize.width - 1.0,	imageSize.height - 1.0),
			NSMakePoint(imageSize.width * 0.5,	imageSize.height * 0.5)
		};
		NSInteger i;
						
		[image lockFocus];
		for (i=0; i<5; i++)
		{
			//If any of the pixels appears to be translucent, then stop looking further.
			NSColor *pixel = NSReadPixel(testPoints[i]);
			if (pixel && [pixel alphaComponent] < 0.9)
			{
				hasTranslucentPixels = YES;
				break;
			}
		}
		[image unlockFocus];
	}

	return hasTranslucentPixels;
}

@end
