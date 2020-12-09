/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXWelcomeView and friends render the custom background and button appearance for the welcome window.
//These are based on the draw methods of the filter gallery since they share a lot of presentational
//code.

#import "BXFilterGallery.h"


@protocol BXWelcomeButtonDraggingDelegate;

/// BXWelcomeView and friends render the custom background and button appearance for the welcome window.
/// These are based on the draw methods of the filter gallery since they share a lot of presentational
/// code.
@interface BXWelcomeView : NSView
@end

@interface BXWelcomeButton : BXFilterPortrait

/// The delegate used for drag-drop operations.
@property (weak, nonatomic) IBOutlet id <BXWelcomeButtonDraggingDelegate> draggingDelegate;

- (BOOL) isHighlighted;

@end

@interface BXWelcomeButtonCell : BXFilterPortraitCell
@end
