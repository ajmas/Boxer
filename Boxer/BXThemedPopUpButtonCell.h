/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXThemes.h"

/// \c BXThemedPopUpButtonCell is a rewrite of \c BGHUDSegmentedCell
/// to make it sane, maintainable, and pretty.
@interface BXThemedPopUpButtonCell : BGHUDPopUpButtonCell <BXThemable>

/// Returns a path with the arrows to render for popup buttons.
- (NSBezierPath *) popUpArrowsForFrame: (NSRect)frame;

/// Returns a path with the arrow to render for pulldown buttons.
- (NSBezierPath *) pullDownArrowForFrame: (NSRect)frame;

/// Given a cell frame, renders popup/pulldown arrows at the
/// right-hand side of the field.
- (void) drawArrowsWithFrame: (NSRect)frame inView: (NSView *)controlView;

@end
