/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */



#import <Cocoa/Cocoa.h>


/// BXScroller is a custom scroller used in some of our interfaces: it displayes a simple grey
/// scroller knob in a track with no scroll buttons.
@interface BXScroller : NSScroller
/// Returns whether the scroller is horizontal or vertical.
@property (readonly, getter=isVertical) BOOL vertical;

/// How big a margin to leave between the edge of the scroller and the scroll knob
@property (readonly) NSSize knobMargin;
/// How big a margin to leave between the edge of the scroller and the visible track
@property (readonly) NSSize slotMargin;
/// The color with which to fill the scroller track
@property (readonly, copy) NSColor *slotFill;
/// The inner shadow to give the scroller track
@property (readonly, copy) NSShadow *slotShadow;
/// The color with which to stroke the scroller knob (quiet you)
@property (readonly, copy) NSColor *knobStroke;
/// The gradient with which to fill the scroller knob
@property (readonly, copy) NSGradient *knobGradient;
@end

/// A recoloured variant for use in HUD-style panels.
@interface BXHUDScroller : BXScroller
@end
