/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanel.h"
#import "NSView+ADBDrawingHelpers.h"
#import "BXBaseAppController.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "NSBezierPath+MCAdditions.h"

#import "ADBAppKitVersionHelpers.h"


@implementation BXProgramPanel

- (BOOL) isOpaque { return YES; }
- (BOOL) mouseDownCanMoveWindow { return YES; }

- (void) _drawGradientInRect: (NSRect)dirtyRect
{
	NSColor *backgroundColor = [NSColor colorWithCalibratedRed: 119 / 255.0 green: 120 / 255.0 blue: 125 / 255.0 alpha: 1.0f];
	NSGradient *background = [[NSGradient alloc] initWithColorsAndLocations:
							  backgroundColor,							0.0f,
							  backgroundColor,	0.9f,
							  backgroundColor,	1.0f,
							  nil];
	
    [NSBezierPath clipRect: dirtyRect];
	[background drawInRect: self.bounds angle: 90.0f];
}

- (void) _drawGrilleInRect: (NSRect)dirtyRect
{
	NSImage *grille		= [NSImage imageNamed: @"Grille"];
	NSSize patternSize	= grille.size;
	NSRect panelRegion	= self.bounds;
	
	//Next, calculate our top and bottom grille strips
	NSRect grilleStrip		= panelRegion;
	grilleStrip.size.height	= patternSize.height * 0.83f;	//Cut off the top of the grille slightly
	grilleStrip.origin.y	= panelRegion.size.height - grilleStrip.size.height;	//Align the grille along the top of the panel
	
	//Only bother drawing the grille if it intersects with the region being drawn
	if ([self needsToDrawRect: grilleStrip])
	{
		NSPoint patternOffset	= [NSView focusView].offsetFromWindowOrigin;
        
        NSPoint grillePhase		= NSMakePoint(patternOffset.x + ((panelRegion.size.width - patternSize.width) / 2),																patternOffset.y + grilleStrip.origin.y);
		
		NSBezierPath *grillePath	= [NSBezierPath bezierPathWithRect: grilleStrip];
		NSColor *grillePattern      = [NSColor colorWithPatternImage: grille];
		
		//Finally, draw the grille strip.
		[NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext currentContext].patternPhase = grillePhase;
            [grillePattern set];
            [grillePath fill];
		[NSGraphicsContext restoreGraphicsState];
	}	
}

- (void) _drawBevelInRect: (NSRect)dirtyRect
{
    NSRect bevelRect = self.bounds;
    bevelRect.size.height = 1.0f;
    
    if ([self needsToDrawRect: bevelRect])
    {
        NSColor * bevelColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.2f];
        [bevelColor set];
        [NSBezierPath fillRect: bevelRect];
    }
}

- (void) drawRect: (NSRect)dirtyRect
{
	[self _drawGradientInRect: dirtyRect];
	//[self _drawGrilleInRect: dirtyRect];
    [self _drawBevelInRect: dirtyRect];
    
    //If we contain a title then redraw the gradient behind the title
    //and over the grille, to create a knockout effect
    NSView *title = [self viewWithTag: BXProgramPanelTitle];
    if (title && !title.isHiddenOrHasHiddenAncestor)
    {
        NSRect titleMask = title.frame;
        
        if ([self needsToDrawRect: titleMask])
            [self _drawGradientInRect: titleMask];
    }
}
@end


@implementation BXProgramItem
@synthesize programButton;

- (void) viewDidLoad
{
    self.programButton = [self.view viewWithTag: BXProgramPanelButtons];
    
    [self.programButton.cell bind: @"programIsDefault"
                         toObject: self
                      withKeyPath: @"representedObject.isDefault"
                          options: nil];
}

- (void) dealloc
{
    [self.programButton.cell unbind: @"programIsDefault"];
}
@end

@implementation BXProgramItemButton

- (void) updateTrackingAreas
{
    [super updateTrackingAreas];
    
    //IMPLEMENTATION NOTE: NSTrackingAreas don't send mouseEntered: and
    //mouseExited: signals when a view is scrolled away from under the mouse.
    //However, updateTrackingAreas *does* get called when scrolling: so we check
    //mouse location by hand and synthesize mouseEntered/exited events to our
    //button cell here instead.
    NSPoint location = self.window.mouseLocationOutsideOfEventStream;
    NSPoint locationInView = [self convertPoint: location fromView: nil];
    BXProgramItemButtonCell *cell = self.cell;
    if ([self hitTest: locationInView] != nil)
    {
        cell.mouseIsInside = YES;
    }
    else
    {
        cell.mouseIsInside = NO;
    }
}

@end

@implementation BXProgramItemButtonCell
@synthesize programIsDefault, mouseIsInside;

+ (NSString *) defaultThemeKey { return @"BXIndentedTheme"; }

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        //Expand the control view to compensate for regular recessed
        //buttons being so damn teeny. TODO: find some other more AppKitty
        //way to do this.
        NSRect expandedRect = NSInsetRect(self.controlView.frame, 0, -1.0f);
        [self.controlView setFrame: expandedRect];
    }
    return self;
}

- (void) setMouseIsInside: (BOOL)flag
{
    if (flag != mouseIsInside)
    {
        mouseIsInside = flag;
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) setProgramIsDefault: (BOOL)flag
{
    if (flag != programIsDefault)
    {
        programIsDefault = flag;
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) mouseEntered: (NSEvent *)event
{
    self.mouseIsInside = YES;
}

- (void) mouseExited: (NSEvent *)event
{
    self.mouseIsInside = NO;
}

-(NSRect) drawTitle: (NSAttributedString *)title
          withFrame: (NSRect)frame
             inView: (NSView *)controlView
{
	BGTheme *theme = [[BGThemeManager keyedManager] themeForKey: self.themeKey];

	NSRect textRect = NSInsetRect(frame, 5.0f, 2.0f);
	
	if (title.length)
    {
        NSMutableAttributedString *newTitle = [title mutableCopy];
        
        NSColor *textColor;
        NSShadow *textShadow;
        
        if (!self.isEnabled)
        {
            textColor = theme.disabledTextColor;
            textShadow = theme.textShadow;
        }
        //Use white text to stand out against blue background
        else if (self.programIsDefault)
        {
            textColor = [NSColor whiteColor];
            textShadow = [NSShadow shadowWithBlurRadius: 2.0f
                                                 offset: NSMakeSize(0, -1.0f)
                                                  color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.75f]];
        }
        //Darken text when pressed in
        else if (self.isHighlighted)
        {
            textColor = [NSColor colorWithCalibratedWhite: 0.15f alpha: 1];
            textShadow = theme.textShadow;
        }
        else
        {
            textColor = theme.textColor;
            textShadow = theme.textShadow;
        }
		
        NSRange range = NSMakeRange(0, newTitle.length);
        
        [newTitle beginEditing];
            [newTitle addAttribute: NSForegroundColorAttributeName
                             value: textColor
                             range: range];
        
            if (textShadow)
            {
                [newTitle addAttribute: NSShadowAttributeName
                                 value: textShadow
                                 range: range];
            }
		[newTitle endEditing];
        
        [newTitle drawInRect: textRect];
	}
	
	return textRect;
}

- (void) drawWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    //Only draw the button bezel while we're hovered or being pressed or while we're the default program.
    if (self.isEnabled && (self.isHighlighted || self.programIsDefault || self.mouseIsInside))
    {
        [self drawBezelWithFrame: frame inView: controlView];
    }
    
    [self drawTitle: self.attributedTitle withFrame: frame inView: self.controlView];
}

- (void) drawBezelWithFrame: (NSRect)frame inView: (NSView *)controlView
{
    NSShadow *innerShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                                    offset: NSMakeSize(0, -1.0f)
                                                     color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f]];
    NSShadow *outerBevel = [NSShadow shadowWithBlurRadius: 1.0f
                                                   offset: NSMakeSize(0, -1.0f)
                                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.75f]];
    
    NSRect insetFrame = [outerBevel insetRectForShadow: frame
                                               flipped: controlView.isFlipped];
    
    NSBezierPath *bezel = [NSBezierPath bezierPathWithRoundedRect: insetFrame
                                                          xRadius: insetFrame.size.height / 2.0f
                                                          yRadius: insetFrame.size.height / 2.0f];
    
    NSGradient *bezelGradient;
    NSColor *bezelColor;
    NSColor *strokeColor;
    
    if (self.programIsDefault)
    {
        strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.3f];
        bezelColor  = [NSColor alternateSelectedControlColor];
        
        if (self.isHighlighted)
        {
            bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.33f], 0.0f,
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.0f], 0.8f,
                             [NSColor colorWithCalibratedWhite: 1 alpha: 0.3f], 1.0f,
                             nil];
        }
        else if (self.mouseIsInside)
        {
            bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite: 1 alpha: 0.15f], 0.0f,
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f], 1.0f,
                             nil];
        }
        else
        {
            bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite: 1 alpha: 0.1f], 0.0f,
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.05f], 1.0f,
                             nil];
        }
    }
    else
    {
        if (self.isHighlighted)
        {
            strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.2f];
            bezelColor  = [NSColor colorWithCalibratedWhite: 0.6f alpha: 1];
            bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.33f], 0.0f,
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.0f], 0.8f,
                             [NSColor colorWithCalibratedWhite: 1 alpha: 0.3f], 1.0f,
                             nil];
        }
        else
        {
            strokeColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.05f];
            bezelColor  = [NSColor colorWithCalibratedWhite: 0.8f alpha: 1];
            bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.05f], 0.0f,
                             [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f], 1.0f,
                             nil];
        }
    }
    
    [NSGraphicsContext saveGraphicsState];
        if (self.isHighlighted || self.programIsDefault)
        {
            [outerBevel set];
            [bezelColor set];
            [bezel fill];
        }
        [bezelGradient drawInBezierPath: bezel angle: 90];
    [NSGraphicsContext restoreGraphicsState];
    
    [NSGraphicsContext saveGraphicsState];
        [strokeColor set];
        [bezel strokeInside];
        if (self.isHighlighted)
            [bezel fillWithInnerShadow: innerShadow];
    [NSGraphicsContext restoreGraphicsState];
}

@end

