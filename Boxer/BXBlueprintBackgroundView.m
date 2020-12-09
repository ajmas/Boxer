/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBlueprintBackgroundView.h"
#import "ADBGeometry.h"
#import "NSView+ADBDrawingHelpers.h"


@implementation BXBlueprintBackgroundView

- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{	
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint"]];
	NSSize patternSize		= blueprintColor.patternImage.size;
	NSSize viewSize			= self.bounds.size;
	NSPoint patternOffset	= [NSView focusView].offsetFromWindowOrigin;
	NSPoint patternPhase	= NSMakePoint(patternOffset.x + ((viewSize.width - patternSize.width) / 2),
										  patternOffset.y + ((viewSize.height - patternSize.height) / 2));
	
	[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[blueprintColor set];
		[NSBezierPath fillRect: self.bounds];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) _drawBlueprintBrandInRect: (NSRect)dirtyRect
{
	NSImage *brand = [NSImage imageNamed: @"BrandWatermark"];
	NSRect brandRegion = NSZeroRect;
	brandRegion.size = brand.size;
	brandRegion = NSIntegralRect(centerInRect(brandRegion, self.bounds));
	
	if ([self needsToDrawRect: brandRegion])
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0f];	
	}
}

- (void) _drawLightingInRect: (NSRect)dirtyRect
{
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f]];
	
	NSRect backgroundRect = self.bounds;
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMinY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = NSWidth(backgroundRect) * 0.1f;
	CGFloat endRadius	= NSWidth(backgroundRect) * 0.75f;
	
	[lighting drawFromCenter: startPoint radius: startRadius
					toCenter: endPoint radius: endRadius
					 options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
}

- (void) _drawShadowInRect: (NSRect)dirtyRect
{
	NSRect shadowRect = self.bounds;
	shadowRect.size.height = 6.0f;
	
	if ([self needsToDrawRect: shadowRect])
	{
		NSGradient *topShadow = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f]
															  endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.0f]];
		
		[topShadow drawInRect: shadowRect angle: 270.0f];
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	[self _drawBlueprintInRect: dirtyRect];
	//[self _drawBlueprintBrandInRect: dirtyRect];
	[self _drawLightingInRect: dirtyRect];
	[self _drawShadowInRect: dirtyRect];
}

@end
